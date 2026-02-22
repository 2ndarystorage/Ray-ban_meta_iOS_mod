/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// OCRViewModel.swift
//
// Main view model that handles photo library access, Vision OCR processing,
// and text file storage for the PhotoTextScan app.
//

import Foundation
import Photos
import SwiftUI
import Vision

@MainActor
class OCRViewModel: ObservableObject {
  @Published var photoAssets: [PHAsset] = []
  @Published var selectedAssets: Set<String> = []
  @Published var ocrResults: [OCRResult] = []
  @Published var isProcessing = false
  @Published var processingProgress: Double = 0.0
  @Published var processingMessage = ""
  @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
  @Published var errorMessage: String?
  @Published var showError = false

  private let imageManager = PHImageManager.default()
  private let documentsURL = FileManager.default.urls(
    for: .documentDirectory, in: .userDomainMask)[0]

  init() {
    authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    loadSavedResults()
    if authorizationStatus == .authorized || authorizationStatus == .limited {
      fetchPhotos()
    }
  }

  func requestPhotoAccess() {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
      Task { @MainActor [weak self] in
        self?.authorizationStatus = status
        if status == .authorized || status == .limited {
          self?.fetchPhotos()
        }
      }
    }
  }

  func fetchPhotos() {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false)
    ]
    fetchOptions.predicate = NSPredicate(
      format: "mediaType == %d", PHAssetMediaType.image.rawValue)

    let result = PHAsset.fetchAssets(with: fetchOptions)
    var assets: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in
      assets.append(asset)
    }
    photoAssets = assets
  }

  func thumbnail(for asset: PHAsset, size: CGSize = CGSize(width: 200, height: 200)) async -> UIImage? {
    await withCheckedContinuation { continuation in
      let options = PHImageRequestOptions()
      options.deliveryMode = .opportunistic
      options.isSynchronous = false
      options.resizeMode = .fast

      imageManager.requestImage(
        for: asset,
        targetSize: size,
        contentMode: .aspectFill,
        options: options
      ) { image, _ in
        continuation.resume(returning: image)
      }
    }
  }

  func toggleSelection(_ assetId: String) {
    if selectedAssets.contains(assetId) {
      selectedAssets.remove(assetId)
    } else {
      selectedAssets.insert(assetId)
    }
  }

  func processSelectedPhotos() async {
    guard !selectedAssets.isEmpty else { return }

    isProcessing = true
    processingProgress = 0.0
    let total = Double(selectedAssets.count)
    var completed = 0.0
    var newResults: [OCRResult] = []

    for assetId in selectedAssets {
      guard let asset = photoAssets.first(where: { $0.localIdentifier == assetId }) else {
        completed += 1
        processingProgress = completed / total
        continue
      }

      processingMessage = "処理中... (\(Int(completed + 1))/\(Int(total)))"

      if let text = await performOCR(on: asset), !text.isEmpty {
        let result = OCRResult(
          assetIdentifier: asset.localIdentifier,
          text: text,
          date: asset.creationDate ?? Date()
        )
        saveTextFile(result: result)
        newResults.append(result)
      }

      completed += 1
      processingProgress = completed / total
    }

    ocrResults.insert(contentsOf: newResults, at: 0)
    saveResultsMetadata()
    isProcessing = false
    processingMessage = ""
    selectedAssets = []
  }

  func deleteResult(_ result: OCRResult) {
    let fileURL = documentsURL.appendingPathComponent(result.textFilename)
    try? FileManager.default.removeItem(at: fileURL)
    ocrResults.removeAll { $0.id == result.id }
    saveResultsMetadata()
  }

  func textFileURL(for result: OCRResult) -> URL {
    documentsURL.appendingPathComponent(result.textFilename)
  }

  private func performOCR(on asset: PHAsset) async -> String? {
    guard let image = await fullResolutionImage(for: asset),
      let cgImage = image.cgImage
    else { return nil }

    return await withCheckedContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          print("[PhotoTextScan] OCR error: \(error)")
          continuation.resume(returning: nil)
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
        continuation.resume(returning: text.isEmpty ? nil : text)
      }
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["ja-JP", "en-US"]
      request.usesLanguageCorrection = true

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      try? handler.perform([request])
    }
  }

  private func fullResolutionImage(for asset: PHAsset) async -> UIImage? {
    await withCheckedContinuation { continuation in
      let options = PHImageRequestOptions()
      options.deliveryMode = .highQualityFormat
      options.isSynchronous = false
      options.isNetworkAccessAllowed = true

      imageManager.requestImage(
        for: asset,
        targetSize: PHImageManagerMaximumSize,
        contentMode: .default,
        options: options
      ) { image, _ in
        continuation.resume(returning: image)
      }
    }
  }

  private func saveTextFile(result: OCRResult) {
    let fileURL = documentsURL.appendingPathComponent(result.textFilename)
    do {
      try result.text.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      print("[PhotoTextScan] Failed to save text file: \(error)")
    }
  }

  private func saveResultsMetadata() {
    let metaURL = documentsURL.appendingPathComponent("ocr_results.json")
    if let data = try? JSONEncoder().encode(ocrResults) {
      try? data.write(to: metaURL)
    }
  }

  private func loadSavedResults() {
    let metaURL = documentsURL.appendingPathComponent("ocr_results.json")
    guard let data = try? Data(contentsOf: metaURL),
      let results = try? JSONDecoder().decode([OCRResult].self, from: data)
    else { return }
    ocrResults = results
  }
}
