/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionViewModel.swift
//
// Core view model demonstrating video streaming from Meta wearable devices using the DAT SDK.
// This class showcases the key streaming patterns: device selection, session management,
// video frame handling, photo capture, and error handling.
//

import MWDATCamera
import MWDATCore
import SwiftUI
import AVFoundation
import Photos
import os

enum StreamingStatus {
  case streaming
  case waiting
  case stopped
}

@MainActor
class StreamSessionViewModel: ObservableObject {
  @Published var currentVideoFrame: UIImage?
  @Published var hasReceivedFirstFrame: Bool = false
  @Published var streamingStatus: StreamingStatus = .stopped
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var showSuccess: Bool = false
  @Published var successMessage: String = ""
  @Published var hasActiveDevice: Bool = false

  var isStreaming: Bool {
    streamingStatus != .stopped
  }

  // Photo capture properties
  @Published var capturedPhoto: UIImage?
  @Published var showPhotoPreview: Bool = false
  @Published var isRecording: Bool = false
  // The core DAT SDK StreamSession - handles all streaming operations
  private var streamSession: StreamSession
  // Recording writer to save streamed video when stopping
  private var assetWriter: AVAssetWriter?
  private var writerInput: AVAssetWriterInput?
  private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var recordingURL: URL?
  private var recordingFrameCount: Int64 = 0
  private var uiUpdateCounter: Int = 0
  private let recordingFrameRate: Int32 = 12
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta.wearables", category: "StreamSessionViewModel")
  // Listener tokens are used to manage DAT SDK event subscriptions
  private var stateListenerToken: AnyListenerToken?
  private var videoFrameListenerToken: AnyListenerToken?
  private var errorListenerToken: AnyListenerToken?
  private var photoDataListenerToken: AnyListenerToken?
  private let wearables: WearablesInterface
  private let deviceSelector: AutoDeviceSelector
  private var deviceMonitorTask: Task<Void, Never>?

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    // Let the SDK auto-select from available devices
    self.deviceSelector = AutoDeviceSelector(wearables: wearables)
    let config = StreamSessionConfig(
      videoCodec: VideoCodec.raw,
      resolution: StreamingResolution.low,
      frameRate: 12)
    streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

    // Monitor device availability
    deviceMonitorTask = Task { @MainActor in
      for await device in deviceSelector.activeDeviceStream() {
        self.hasActiveDevice = device != nil
      }
    }

    // Subscribe to session state changes using the DAT SDK listener pattern
    // State changes tell us when streaming starts, stops, or encounters issues
    stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in
        self?.updateStatusFromState(state)
      }
    }

    // Subscribe to video frames from the device camera
    // Each VideoFrame contains the raw camera data that we convert to UIImage
    videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
      Task { @MainActor [weak self] in
        guard let self else { return }

        if let image = videoFrame.makeUIImage() {
          self.uiUpdateCounter += 1
          // Update UI every 2 frames to reduce processing load
          if self.uiUpdateCounter % 2 == 0 {
            self.currentVideoFrame = image
          }
          if !self.hasReceivedFirstFrame {
            self.hasReceivedFirstFrame = true
            // Ensure first frame is always shown
            self.currentVideoFrame = image
          }
          // If recording is active, ensure writer exists and append this frame
          if self.isRecording {
            if self.assetWriter == nil {
              self.startRecordingWriterIfNeeded()
            }
            if let _ = self.assetWriter {
              self.appendFrameToRecording(image: image)
            }
          }
        }
      }
    }

    // Subscribe to streaming errors
    // Errors include device disconnection, streaming failures, etc.
    errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let newErrorMessage = formatStreamingError(error)
        if newErrorMessage != self.errorMessage {
          showError(newErrorMessage)
        }
      }
    }

    updateStatusFromState(streamSession.state)

    // Subscribe to photo capture events
    // PhotoData contains the captured image in the requested format (JPEG/HEIC)
    photoDataListenerToken = streamSession.photoDataPublisher.listen { [weak self] photoData in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if let uiImage = UIImage(data: photoData.data) {
          // Auto-save photo to Photos library without blocking subsequent captures
          Task {
            await self.savePhotoToLibrary(uiImage)
          }
        }
      }
    }
  }

  func handleStartStreaming() async {
    let permission = Permission.camera
    do {
      let status = try await wearables.checkPermissionStatus(permission)
      if status == .granted {
        await startSession()
        return
      }
      let requestStatus = try await wearables.requestPermission(permission)
      if requestStatus == .granted {
        await startSession()
        return
      }
      showError("権限が拒否されました")
    } catch {
      showError("権限の取得に失敗しました: \(error.description)")
    }
  }

  func startSession() async {
    await streamSession.start()
    // Automatically start recording when streaming begins
    await startRecording()
  }

  func startRecording() async {
    guard !isRecording else { return }
    isRecording = true
    // Try to create writer now; if no frame yet, retry briefly until first frame arrives
    await MainActor.run {
      self.startRecordingWriterIfNeeded()
    }
    if assetWriter == nil {
      let deadline = Date().addingTimeInterval(5)
      while assetWriter == nil && Date() < deadline {
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
          self.startRecordingWriterIfNeeded()
        }
      }
    }
    if assetWriter == nil {
      logger.warning("Failed to start recording: no video frame available to determine size")
      isRecording = false
    }
  }

  func stopRecording() async {
    guard isRecording else { return }
    isRecording = false
    await finishRecordingAndSave()
  }

  private func showError(_ message: String) {
    errorMessage = message
    showError = true
  }

  private func showSuccess(_ message: String) {
    successMessage = message
    showSuccess = true
  }

  func stopSession() async {
    // Stop recording and save video automatically when streaming stops
    await stopRecording()
    await streamSession.stop()
  }

  private func startRecordingWriterIfNeeded() {
    // Avoid recreating if already exists
    guard assetWriter == nil else { return }
    // Wait until we have a current frame to determine size
    guard let image = currentVideoFrame else { return }
    let size = image.size
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("streaming_\(UUID().uuidString).mov")
    recordingURL = tempURL

    do {
      assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .mov)
    } catch {
      logger.error("Failed to create AVAssetWriter: \(error.localizedDescription)")
      assetWriter = nil
      return
    }

    let outputSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(size.width),
      AVVideoHeightKey: Int(size.height),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(size.width * size.height * 0.5)
      ]
    ]

    writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
    writerInput?.expectsMediaDataInRealTime = true
    // Set frame rate for proper video encoding
    writerInput?.mediaTimeScale = recordingFrameRate

    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferWidthKey as String: Int(size.width),
      kCVPixelBufferHeightKey as String: Int(size.height)
    ]

    if let writerInput = writerInput, let assetWriter = assetWriter, assetWriter.canAdd(writerInput) {
      assetWriter.add(writerInput)
      pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: attributes)
      recordingFrameCount = 0
      assetWriter.startWriting()
      assetWriter.startSession(atSourceTime: .zero)
    } else {
      logger.error("Failed to add writer input")
      assetWriter = nil
      writerInput = nil
      pixelBufferAdaptor = nil
    }
  }

  private func appendFrameToRecording(image: UIImage) {
    guard let pixelBufferAdaptor = pixelBufferAdaptor,
          let writerInput = writerInput,
          writerInput.isReadyForMoreMediaData else { return }

    let frameTime = CMTime(value: recordingFrameCount, timescale: recordingFrameRate)
    recordingFrameCount += 1

    guard let pixelBuffer = pixelBufferFromImage(image: image) else {
      logger.error("Failed to create pixel buffer for frame \(self.recordingFrameCount)")
      return
    }
    if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime) {
        logger.error("Failed to append pixel buffer at frame \(self.recordingFrameCount)")
    }
  }

  private func pixelBufferFromImage(image: UIImage) -> CVPixelBuffer? {
    let cgImage: CGImage
    if let direct = image.cgImage {
      cgImage = direct
    } else if let ciImage = image.ciImage {
      let context = CIContext()
      guard let rendered = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
      cgImage = rendered
    } else {
      return nil
    }
    let width = cgImage.width
    let height = cgImage.height
    var pixelBuffer: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess, let px = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(px, [])
    let pxData = CVPixelBufferGetBaseAddress(px)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    // BGRA format with premultiplied alpha
    let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    guard let context = CGContext(data: pxData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(px), space: rgbColorSpace, bitmapInfo: bitmapInfo) else {
      CVPixelBufferUnlockBaseAddress(px, [])
      logger.error("Failed to create CGContext for pixel buffer")
      return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(px, [])
    return px
  }

  private func finishRecordingAndSave() async {
    guard let writer = assetWriter else {
      logger.error("No asset writer to finish")
      return
    }
    
    logger.info("Finishing recording: \(self.recordingFrameCount) frames written")
    writerInput?.markAsFinished()

    // Await finishWriting asynchronously to avoid blocking the main thread
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      writer.finishWriting {
        continuation.resume()
      }
    }

    logger.info("AssetWriter finished with status: \(writer.status.rawValue)")
    
    if writer.status == .failed {
      let errDesc = writer.error?.localizedDescription ?? "Unknown"
      logger.error("AssetWriter failed finishing: \(errDesc)")
      assetWriter = nil
      writerInput = nil
      pixelBufferAdaptor = nil
      recordingURL = nil
      recordingFrameCount = 0
      return
    }
    
    if writer.status != .completed {
      logger.error("AssetWriter status is not completed: \(writer.status.rawValue)")
      assetWriter = nil
      writerInput = nil
      pixelBufferAdaptor = nil
      recordingURL = nil
      recordingFrameCount = 0
      return
    }

    // Check if file exists and has content
    if let url = recordingURL {
      let fileExists = FileManager.default.fileExists(atPath: url.path)
      let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
      logger.info("Recording file exists: \(fileExists), size: \(fileSize) bytes")
      
      if !fileExists || fileSize == 0 {
        logger.error("Recording file is empty or doesn't exist")
        assetWriter = nil
        writerInput = nil
        pixelBufferAdaptor = nil
        recordingURL = nil
        recordingFrameCount = 0
        return
      }
    }

    // Save to Photos
    if let url = recordingURL {
      logger.info("Starting save to Photos: \(url.absoluteString)")
      // Use async/await wrapper for PHPhotoLibrary authorization
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
          self?.logger.info("PHPhotoLibrary authorization status: \(status.rawValue)")
          guard let self = self else {
            continuation.resume()
            return
          }

          if status == .authorized || status == .limited {
            self.logger.info("Attempting to save video to Photos...")
            PHPhotoLibrary.shared().performChanges({
              PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { [weak self] saved, error in
              Task { @MainActor in
                guard let self = self else {
                  continuation.resume()
                  return
                }
                self.logger.info("PHPhotoLibrary.performChanges completed: saved=\(saved), error=\(error?.localizedDescription ?? "nil")")
                if let error = error {
                  self.logger.error("Failed to save video: \(error.localizedDescription)")
                self.showError("動画の保存に失敗しました: \(error.localizedDescription)")
              } else if saved {
                self.logger.info("Successfully saved recording to Photos: \(url.absoluteString)")
                self.showSuccess("動画をフォトライブラリに保存しました")
              }
                // Cleanup temporary file only after successful save
                if saved {
                  do {
                    try FileManager.default.removeItem(at: url)
                    self.logger.info("Cleaned up temporary file")
                  } catch {
                    self.logger.error("Failed to clean up temporary file: \(error.localizedDescription)")
                  }
                }
                continuation.resume()
              }
            }
          } else {
            self.logger.warning("Photo library permission not granted; temporary file at \(url.absoluteString)")
            self.showError("フォトライブラリへのアクセスが拒否されました。動画を保存できません。")
            continuation.resume()
          }
        }
      }
    }

    // Reset writer state
    assetWriter = nil
    writerInput = nil
    pixelBufferAdaptor = nil
    recordingURL = nil
    recordingFrameCount = 0
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }

  func dismissSuccess() {
    showSuccess = false
    successMessage = ""
  }

  private func savePhotoToLibrary(_ image: UIImage) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
        guard let self = self else {
          continuation.resume()
          return
        }
        self.logger.info("PHPhotoLibrary authorization status for photo: \(status.rawValue)")
        if status == .authorized || status == .limited {
          self.logger.info("Attempting to save photo to Photos...")
          PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
          }) { [weak self] saved, error in
            Task { @MainActor in
              guard let self = self else {
                continuation.resume()
                return
              }
              self.logger.info("PHPhotoLibrary.performChanges for photo completed: saved=\(saved), error=\(error?.localizedDescription ?? "nil")")
              if let error = error {
                self.logger.error("Failed to save photo: \(error.localizedDescription)")
                self.showError("写真の保存に失敗しました: \(error.localizedDescription)")
              } else if saved {
                self.logger.info("Successfully saved photo to Photos")
                self.showSuccess("写真をフォトライブラリに保存しました")
              }
              continuation.resume()
            }
          }
        } else {
          self.logger.warning("Photo library permission not granted for photo")
          self.showError("フォトライブラリへのアクセスが拒否されました。写真を保存できません。")
          continuation.resume()
        }
      }
    }
  }

  func capturePhoto() {
    streamSession.capturePhoto(format: .jpeg)
  }

  func dismissPhotoPreview() {
    showPhotoPreview = false
    capturedPhoto = nil
  }

  private func updateStatusFromState(_ state: StreamSessionState) {
    switch state {
    case .stopped:
      currentVideoFrame = nil
      streamingStatus = .stopped
    case .waitingForDevice, .starting, .stopping, .paused:
      streamingStatus = .waiting
    case .streaming:
      streamingStatus = .streaming
    }
  }

  private func formatStreamingError(_ error: StreamSessionError) -> String {
    switch error {
    case .internalError:
      return "内部エラーが発生しました。もう一度お試しください。"
    case .deviceNotFound:
      return "デバイスが見つかりません。接続を確認してください。"
    case .deviceNotConnected:
      return "デバイスが接続されていません。接続を確認してください。"
    case .timeout:
      return "操作がタイムアウトしました。もう一度お試しください。"
    case .videoStreamingError:
      return "映像のストリーミングに失敗しました。もう一度お試しください。"
    case .audioStreamingError:
      return "音声のストリーミングに失敗しました。もう一度お試しください。"
    case .permissionDenied:
      return "カメラ権限が拒否されました。設定で許可してください。"
    case .hingesClosed:
      return "メガネのヒンジが閉じています。開いてからお試しください。"
    @unknown default:
      return "不明なストリーミングエラーが発生しました。"
    }
  }
}
