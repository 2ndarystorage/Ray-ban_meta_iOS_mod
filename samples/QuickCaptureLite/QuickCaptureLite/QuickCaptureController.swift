import CoreImage
import Foundation
import MWDATCamera
import MWDATCore
import SwiftUI
import Vision

enum FilterMode: String, CaseIterable, Identifiable {
    case none = "None"
    case mono = "Mono"
    case comic = "Comic"

    var id: String { rawValue }
}

@MainActor
final class QuickCaptureController: ObservableObject {
    // Public state exposed to SwiftUI
    @Published var registrationState: RegistrationState
    @Published var activeDeviceName: String = "No device"
    @Published var statusText: String = "Idle"
    @Published var previewImage: UIImage?
    @Published var lastPhoto: UIImage?
    @Published var errorMessage: String?
    @Published var filterMode: FilterMode = .none
    @Published var aiOverlayEnabled: Bool = true
    @Published var detectedFaces: [CGRect] = []

    // Core DAT objects
    private let wearables: WearablesInterface
    private let deviceSelector: AutoDeviceSelector
    private let streamSession: StreamSession

    // Listener/Task handles for cleanup
    private var stateListener: AnyListenerToken?
    private var frameListener: AnyListenerToken?
    private var errorListener: AnyListenerToken?
    private var photoListener: AnyListenerToken?
    private var deviceMonitorTask: Task<Void, Never>?
    private let ciContext = CIContext()

    init() {
        // Configure the global Wearables singleton exactly once
        do {
            try Wearables.configure()
        } catch {
            NSLog("[QuickCaptureLite] Failed to configure Wearables SDK: \(error.localizedDescription)")
        }
        self.wearables = Wearables.shared
        self.registrationState = wearables.registrationState
        self.deviceSelector = AutoDeviceSelector(wearables: wearables)
        // Simple streaming profile optimized for demo purposes
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .medium,
            frameRate: 24
        )
        self.streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

        observeRegistration()
        observeDevices()
        observeStreamSession()
    }

    deinit {
        deviceMonitorTask?.cancel()
        streamSession.stop()
    }

    // Continuously mirror the SDK registration state so the UI stays in sync
    private func observeRegistration() {
        Task { [weak self] in
            guard let self else { return }
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }
    }

    // Track whichever headset the AutoDeviceSelector chooses so we can show its name
    private func observeDevices() {
        deviceMonitorTask = Task { [weak self] in
            guard let self else { return }
            for await device in deviceSelector.activeDeviceStream() {
                await MainActor.run {
                    self.activeDeviceName = device?.nameOrId() ?? "No device"
                }
            }
        }
    }

    private func observeStreamSession() {
        stateListener = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                switch state {
                case .stopped:
                    self?.statusText = "Stopped"
                case .waitingForDevice:
                    self?.statusText = "Waiting for device"
                case .starting:
                    self?.statusText = "Starting"
                case .stopping:
                    self?.statusText = "Stopping"
                case .paused:
                    self?.statusText = "Paused"
                case .streaming:
                    self?.statusText = "Streaming"
                @unknown default:
                    self?.statusText = "Unknown state"
                }
            }
        }

        // Convert every incoming frame into a filtered preview & optional AI overlay
        frameListener = streamSession.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            self?.processIncomingFrame(image)
        }

        // Save the last on-demand capture so the UI can display it (filters applied)
        photoListener = streamSession.photoDataPublisher.listen { [weak self] photoData in
            guard let self, let image = UIImage(data: photoData.data) else { return }
            self.processCapturedPhoto(image)
        }

        errorListener = streamSession.errorPublisher.listen { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = Self.describe(error)
            }
        }
    }

    private func processIncomingFrame(_ image: UIImage) {
        let filterMode = self.filterMode
        let aiEnabled = self.aiOverlayEnabled
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let filtered = self.apply(filterMode: filterMode, to: image)
            let faces = aiEnabled ? self.detectFaces(in: image) : []
            await MainActor.run {
                self.previewImage = filtered
                self.detectedFaces = aiEnabled ? faces : []
            }
        }
    }

    private func processCapturedPhoto(_ image: UIImage) {
        let filterMode = self.filterMode
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let filtered = self.apply(filterMode: filterMode, to: image)
            await MainActor.run {
                self.lastPhoto = filtered
            }
        }
    }

    private func apply(filterMode: FilterMode, to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let outputImage: CIImage
        switch filterMode {
        case .none:
            return image
        case .mono:
            outputImage = ciImage.applyingFilter("CIPhotoEffectMono")
        case .comic:
            outputImage = ciImage.applyingFilter("CIComicEffect")
        }
        guard let cgOutput = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgOutput, scale: image.scale, orientation: image.imageOrientation)
    }

    private func detectFaces(in image: UIImage) -> [CGRect] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.compactMap { $0.boundingBox } ?? []
        } catch {
            NSLog("[QuickCaptureLite] Face detection failed: \(error.localizedDescription)")
            return []
        }
    }

    func connect() {
        guard registrationState != .registering else { return }
        Task {
            do {
                try await wearables.startRegistration()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func disconnect() {
        Task {
            do {
                try await wearables.startUnregistration()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func startStreaming() {
        Task {
            do {
                // DAT requires camera permission from Meta AI, so enforce it proactively
                let permission = Permission.camera
                let status = try await wearables.checkPermissionStatus(permission)
                if status != .granted {
                    let requestStatus = try await wearables.requestPermission(permission)
                    guard requestStatus == .granted else {
                        await MainActor.run { self.errorMessage = "Camera permission denied" }
                        return
                    }
                }
                await streamSession.start()
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func stopStreaming() {
        Task {
            await streamSession.stop()
        }
    }

    func capturePhoto() {
        streamSession.capturePhoto(format: .jpeg)
    }

    static func describe(_ error: StreamSessionError) -> String {
        switch error {
        case .permissionDenied:
            return "Permission denied"
        case .deviceNotConnected:
            return "Device not connected"
        case .deviceNotFound:
            return "Device not found"
        case .hingesClosed:
            return "Glasses closed"
        case .timeout:
            return "Timed out"
        case .videoStreamingError:
            return "Video pipeline error"
        case .audioStreamingError:
            return "Audio pipeline error"
        case .internalError:
            fallthrough
        @unknown default:
            return "Unknown error"
        }
    }
}
