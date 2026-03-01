import SwiftUI

struct QuickCaptureView: View {
    // The controller supplies all observable state and actions
    @ObservedObject var controller: QuickCaptureController

    var body: some View {
        TabView {
            // メインのカメラ・ストリーミング画面
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        statusCard
                        previewCard
                        filterControls
                        controls
                    if let error = controller.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("QuickCapture Lite")
            }
            .tabItem { Label("カメラ", systemImage: "camera.fill") }

            // ギャラリー画面
            PhotoGalleryView(controller: controller)
                .tabItem { Label("ギャラリー", systemImage: "photo.on.rectangle") }
                .badge(controller.capturedPhotos.count)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
                Text("登録")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(controller.registrationStateDescription)
                .font(.title3.weight(.semibold))
            Divider()
                Text("アクティブなデバイス")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(controller.activeDeviceName)
                .font(.body.monospaced())
            Divider()
                Text("ストリーミング状態")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(controller.statusText)
                .font(.headline)
        }
        // Material card shows the key pieces of session state at a glance
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
                Text("ライブプレビュー")
                .font(.headline)
            if let image = controller.previewImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3)))

                    if controller.aiOverlayEnabled {
                        GeometryReader { geo in
                            ForEach(Array(controller.detectedFaces.enumerated()), id: \.offset) { index, box in
                                let converted = convertToViewRect(box, in: geo.size)
                                Rectangle()
                                    .stroke(.green, lineWidth: 2)
                                    .frame(width: converted.width, height: converted.height)
                                    .position(x: converted.midX, y: converted.midY)
                                    .animation(.easeInOut(duration: 0.15), value: controller.detectedFaces.count)
                                    .accessibilityLabel("Detected face \(index + 1)")
                            }
                        }
                        .allowsHitTesting(false)

                    if controller.ocrEnabled && !controller.recognizedTexts.isEmpty {
                        GeometryReader { geo in
                            TextRecognitionOverlay(
                                observations: controller.recognizedTexts,
                                imageSize: geo.size
                            )
                        }
                        .allowsHitTesting(false)
                    }
                    }
                }
                .aspectRatio(image.size, contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.2))
                    .frame(height: 220)
                    .overlay(
                        VStack {
                            ProgressView()
                            Text("フレームがまだありません")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    )
            }

            // Optional photo preview shows the last captured still frame
            if let photo = controller.lastPhoto {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最後に撮影した写真")
                        .font(.subheadline)
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ビジュアルエフェクト")
                .font(.headline)
            Picker("フィルター", selection: $controller.filterMode) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("顔検出オーバーレイを表示", isOn: $controller.aiOverlayEnabled)
                    .toggleStyle(.switch)
                    .tint(.green)

            Toggle("テキスト認識 (OCR)", isOn: $controller.ocrEnabled)
                .toggleStyle(.switch)
                .tint(.green)
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Button("接続", action: controller.connect)
                Button("切断", action: controller.disconnect)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack {
                Button("ストリーミング開始", action: controller.startStreaming)
                Button("停止", action: controller.stopStreaming)
            }
            .buttonStyle(.bordered)

            Button("写真撮影", action: controller.capturePhoto)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        // Controls mirror the high-level actions exposed by the controller
        .frame(maxWidth: .infinity)
    }

    private func convertToViewRect(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        let x = boundingBox.minX * size.width
        // Vision's coordinate system has the origin at the bottom-left, so flip the Y axis
        let y = (1 - boundingBox.maxY) * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private extension QuickCaptureController {
    var registrationStateDescription: String {
        switch registrationState {
        case .unknown: return "不明"
        case .unregistered: return "未登録"
        case .registering: return "登録中"
        case .registered: return "登録済み"
        @unknown default: return "サポート対象外"
        }
    }
}

#Preview {
    QuickCaptureView(controller: QuickCaptureController())
}
