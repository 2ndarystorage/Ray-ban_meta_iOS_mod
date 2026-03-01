import SwiftUI
import Vision

/// リアルタイムテキスト認識（OCR）の結果をオーバーレイ表示するビュー
struct TextRecognitionOverlay: View {
    let observations: [VNRecognizedTextObservation]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(observations.enumerated()), id: \.offset) { _, obs in
                if let candidate = obs.topCandidates(1).first {
                    let rect = convertBounds(obs.boundingBox, to: geo.size)
                    Text(candidate.string)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.yellow)
                        .padding(2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Vision の正規化座標 (左下原点) を SwiftUI 座標 (左上原点) に変換
    private func convertBounds(_ box: CGRect, to size: CGSize) -> CGRect {
        CGRect(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}
