/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// PhotoTextScanApp.swift
//
// Main entry point for the PhotoTextScan app.
// This app extracts text from images in the device photo library using OCR
// (Apple's Vision framework) and saves the results as text files.
//

import SwiftUI

@main
struct PhotoTextScanApp: App {
  @StateObject private var viewModel = OCRViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView(viewModel: viewModel)
    }
  }
}
