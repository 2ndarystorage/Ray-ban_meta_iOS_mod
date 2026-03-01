import SwiftUI
import Photos

/// 撮影した写真を一覧・保存・共有するギャラリービュー
struct PhotoGalleryView: View {
    @ObservedObject var controller: QuickCaptureController
    @State private var selectedPhoto: UIImage?

    var body: some View {
        NavigationStack {
            if controller.capturedPhotos.isEmpty {
                ContentUnavailableView(
                    "写真なし",
                    systemImage: "photo.on.rectangle",
                    description: Text("「Capture photo」でフレームを保存しよう")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(Array(controller.capturedPhotos.enumerated()), id: \.offset) { idx, photo in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture { selectedPhoto = photo }
                        }
                    }
                    .padding()
                }
                .navigationTitle("ギャラリー (\(controller.capturedPhotos.count)枚)")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("全削除", role: .destructive) {
                            controller.capturedPhotos.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPhoto != nil },
            set: { if !$0 { selectedPhoto = nil } }
        )) {
            if let photo = selectedPhoto {
                PhotoDetailView(photo: photo)
            }
        }
    }
}

struct PhotoDetailView: View {
    let photo: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var saveStatus: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding()

                if let status = saveStatus {
                    Text(status).font(.callout).foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    Button {
                        saveToPhotos()
                    } label: {
                        Label("フォトライブラリに保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(
                        item: Image(uiImage: photo),
                        preview: SharePreview("キャプチャ画像")
                    ) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func saveToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { saveStatus = "フォトライブラリへのアクセスが必要です" }
                return
            }
            UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
            DispatchQueue.main.async { saveStatus = "✅ フォトライブラリに保存しました" }
        }
    }
}
