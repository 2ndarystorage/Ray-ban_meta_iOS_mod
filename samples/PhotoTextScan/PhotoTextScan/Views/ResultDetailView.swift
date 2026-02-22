/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// ResultDetailView.swift
//
// Displays the full extracted text for a single OCR result,
// with options to copy or share the text.
//

import SwiftUI

struct ResultDetailView: View {
  let result: OCRResult
  @ObservedObject var viewModel: OCRViewModel
  @State private var copied = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: "calendar")
            .foregroundStyle(.secondary)
          Text(result.date, style: .date)
            .foregroundStyle(.secondary)
          Text(result.date, style: .time)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .font(.caption)

        Divider()

        Text(result.text)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding()
    }
    .navigationTitle("抽出テキスト")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          UIPasteboard.general.string = result.text
          copied = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
          }
        } label: {
          Label(copied ? "コピー済み" : "コピー",
            systemImage: copied ? "checkmark" : "doc.on.doc")
        }

        ShareLink(item: result.text) {
          Label("共有", systemImage: "square.and.arrow.up")
        }
      }
    }
  }
}
