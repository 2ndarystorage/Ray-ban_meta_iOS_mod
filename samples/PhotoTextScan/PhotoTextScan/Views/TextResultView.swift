/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// TextResultView.swift
//
// Lists all saved OCR results, allowing users to view, share, or delete them.
//

import SwiftUI

struct TextResultView: View {
  @ObservedObject var viewModel: OCRViewModel

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.ocrResults.isEmpty {
          emptyStateView
        } else {
          resultsList
        }
      }
      .navigationTitle("保存済みテキスト")
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 20) {
      Image(systemName: "text.below.photo")
        .font(.system(size: 60))
        .foregroundStyle(.secondary)
      Text("テキストがまだありません")
        .font(.headline)
      Text("「フォトライブラリ」タブで写真を選択し、「OCR実行」ボタンを押してテキストを抽出してください。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding()
  }

  private var resultsList: some View {
    List {
      ForEach(viewModel.ocrResults) { result in
        NavigationLink {
          ResultDetailView(result: result, viewModel: viewModel)
        } label: {
          resultRow(result)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button(role: .destructive) {
            viewModel.deleteResult(result)
          } label: {
            Label("削除", systemImage: "trash")
          }

          ShareLink(item: result.text) {
            Label("共有", systemImage: "square.and.arrow.up")
          }
          .tint(.blue)
        }
      }
    }
    .listStyle(.plain)
  }

  private func resultRow(_ result: OCRResult) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(result.previewText.isEmpty ? "（テキストなし）" : result.previewText)
        .font(.body)
        .lineLimit(2)
        .foregroundStyle(.primary)

      HStack(spacing: 8) {
        Image(systemName: "calendar")
          .font(.caption2)
        Text(result.date, style: .date)
          .font(.caption)
        Text(result.date, style: .time)
          .font(.caption)
        Spacer()
        Text("\(result.text.count)文字")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}
