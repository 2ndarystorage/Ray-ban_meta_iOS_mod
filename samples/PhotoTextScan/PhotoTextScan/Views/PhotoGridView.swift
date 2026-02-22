/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// PhotoGridView.swift
//
// Displays the device photo library as a selectable grid.
// Users tap photos to select them for OCR processing.
//

import Photos
import SwiftUI

struct PhotoGridView: View {
  @ObservedObject var viewModel: OCRViewModel
  @State private var processingComplete = false

  private let columns = [
    GridItem(.adaptive(minimum: 100), spacing: 2)
  ]

  var body: some View {
    NavigationStack {
      Group {
        switch viewModel.authorizationStatus {
        case .notDetermined:
          permissionRequestView
        case .denied, .restricted:
          permissionDeniedView
        case .authorized, .limited:
          photoGridContent
        @unknown default:
          permissionRequestView
        }
      }
      .navigationTitle("フォトライブラリ")
      .toolbar {
        if !viewModel.selectedAssets.isEmpty && !viewModel.isProcessing {
          ToolbarItem(placement: .topBarTrailing) {
            Button("OCR実行 (\(viewModel.selectedAssets.count))") {
              Task {
                await viewModel.processSelectedPhotos()
                processingComplete = true
              }
            }
            .bold()
          }
        }
      }
      .alert("OCR完了", isPresented: $processingComplete) {
        Button("OK") {}
      } message: {
        Text("テキストの抽出が完了しました。「保存済みテキスト」タブで確認できます。")
      }
    }
  }

  private var permissionRequestView: some View {
    VStack(spacing: 20) {
      Image(systemName: "photo.on.rectangle")
        .font(.system(size: 60))
        .foregroundStyle(.secondary)
      Text("フォトライブラリへのアクセスが必要です")
        .font(.headline)
      Text("画像内のテキストを認識するために、写真へのアクセスを許可してください。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Button("アクセスを許可する") {
        viewModel.requestPhotoAccess()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }

  private var permissionDeniedView: some View {
    VStack(spacing: 20) {
      Image(systemName: "photo.slash")
        .font(.system(size: 60))
        .foregroundStyle(.secondary)
      Text("フォトライブラリへのアクセスが拒否されています")
        .font(.headline)
        .multilineTextAlignment(.center)
      Text("設定アプリからフォトライブラリへのアクセスを許可してください。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Button("設定を開く") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }

  private var photoGridContent: some View {
    ZStack(alignment: .bottom) {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 2) {
          ForEach(viewModel.photoAssets, id: \.localIdentifier) { asset in
            PhotoThumbnailCell(
              asset: asset,
              isSelected: viewModel.selectedAssets.contains(asset.localIdentifier),
              viewModel: viewModel
            )
            .onTapGesture {
              viewModel.toggleSelection(asset.localIdentifier)
            }
          }
        }
        .padding(.bottom, viewModel.selectedAssets.isEmpty ? 0 : 80)
      }

      if viewModel.isProcessing {
        processingOverlay
      }
    }
  }

  private var processingOverlay: some View {
    VStack(spacing: 12) {
      ProgressView(value: viewModel.processingProgress)
        .progressViewStyle(.linear)
      Text(viewModel.processingMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding()
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial)
  }
}

struct PhotoThumbnailCell: View {
  let asset: PHAsset
  let isSelected: Bool
  @ObservedObject var viewModel: OCRViewModel
  @State private var thumbnail: UIImage?

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Group {
        if let image = thumbnail {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
        } else {
          Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
              ProgressView()
            }
        }
      }
      .frame(width: cellSize, height: cellSize)
      .clipped()
      .overlay {
        if isSelected {
          Color.blue.opacity(0.3)
        }
      }

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.white, .blue)
          .padding(4)
      }
    }
    .task {
      thumbnail = await viewModel.thumbnail(
        for: asset,
        size: CGSize(width: cellSize * 2, height: cellSize * 2))
    }
  }

  private var cellSize: CGFloat {
    (UIScreen.main.bounds.width - 4) / 3
  }
}
