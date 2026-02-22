# PhotoTextScan

iPhoneのフォトライブラリにある画像からテキストを抽出し、テキストファイルとして保存するサンプルアプリです。

## 機能

- フォトライブラリから複数の画像を選択
- Apple Vision フレームワークによる OCR (光学文字認識)
- 日本語・英語のテキスト認識対応
- 抽出したテキストを `.txt` ファイルとして Documents フォルダに保存
- 保存済みテキストの一覧表示・閲覧・共有・削除

## 使用技術

| フレームワーク | 用途 |
|---|---|
| `Photos` | フォトライブラリへのアクセス |
| `Vision` | OCR (VNRecognizeTextRequest) |
| `SwiftUI` | UI |
| `Foundation` | ファイル保存 (FileManager) |

## プロジェクト構成

```
PhotoTextScan/
├── PhotoTextScan.xcodeproj/
└── PhotoTextScan/
    ├── PhotoTextScanApp.swift      # アプリのエントリーポイント
    ├── ContentView.swift           # タブナビゲーション
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/
    │   └── OCRResult.swift         # OCR結果データモデル
    ├── ViewModels/
    │   └── OCRViewModel.swift      # ビジネスロジック・OCR処理
    └── Views/
        ├── PhotoGridView.swift     # フォトライブラリグリッド表示
        ├── TextResultView.swift    # 保存済みテキスト一覧
        └── ResultDetailView.swift  # テキスト詳細表示
```

## セットアップ

1. `PhotoTextScan.xcodeproj` を Xcode で開く
2. **Signing & Capabilities** で開発チームを設定
3. Bundle Identifier を変更（例: `com.yourname.PhotoTextScan`）
4. iPhone 実機またはシミュレータでビルド・実行

> **注意**: フォトライブラリへのアクセスは実機でテストすることを推奨します。シミュレータでも動作しますが、写真の追加が必要です。

## 必要環境

- iOS 17.0 以上
- Xcode 15.0 以上
