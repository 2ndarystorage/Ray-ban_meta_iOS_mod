/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// OCRResult.swift
//
// Data model representing the result of an OCR text recognition operation.
//

import Foundation

struct OCRResult: Identifiable, Codable {
  let id: UUID
  let assetIdentifier: String
  let text: String
  let date: Date
  let textFilename: String

  init(assetIdentifier: String, text: String, date: Date) {
    self.id = UUID()
    self.assetIdentifier = assetIdentifier
    self.text = text
    self.date = date

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let dateStr = formatter.string(from: date)
    self.textFilename = "ocr_\(dateStr)_\(self.id.uuidString.prefix(8)).txt"
  }

  var previewText: String {
    let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    return lines.prefix(2).joined(separator: " ")
  }
}
