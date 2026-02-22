/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// ContentView.swift
//
// Root view containing the main tab navigation.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var viewModel: OCRViewModel

  var body: some View {
    TabView {
      PhotoGridView(viewModel: viewModel)
        .tabItem {
          Label("フォトライブラリ", systemImage: "photo.on.rectangle")
        }

      TextResultView(viewModel: viewModel)
        .tabItem {
          Label("保存済みテキスト", systemImage: "doc.text")
        }
        .badge(viewModel.ocrResults.count > 0 ? viewModel.ocrResults.count : 0)
    }
  }
}
