/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
      }

      // Bottom controls layer

      VStack {
        Spacer()
        ControlsView(viewModel: viewModel)
      }
      .padding(.all, 24)
    }
    .onDisappear {
      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
      }
    }
    // Show captured photos from DAT SDK in a preview sheet
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          }
        )
      }
    }
  }
}

// Extracted controls for clarity
struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  var body: some View {
    // Controls row
    HStack(spacing: 8) {
      // Record toggle
      Button(action: {
        Task {
          if viewModel.isRecording {
            await viewModel.stopRecording()
          } else {
            await viewModel.startRecording()
          }
        }
      }) {
        HStack(spacing: 6) {
          Circle()
            .fill(viewModel.isRecording ? Color.red : Color.white)
            .frame(width: 12, height: 12)
          Text(viewModel.isRecording ? "録画中" : "録画")
            .foregroundColor(.white)
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35))
        .cornerRadius(10)
      }

      CustomButton(
        title: "停止",
        style: .destructive,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }

      // Photo button
      CircleButton(icon: "camera.fill", text: nil) {
        viewModel.capturePhoto()
      }
    }
  }
}
