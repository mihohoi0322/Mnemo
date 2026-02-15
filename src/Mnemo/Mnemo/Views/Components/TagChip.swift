import SwiftUI

/// タグチップコンポーネント
///
/// スタイルガイド準拠:
/// - 高さ 28、角丸 16、余白 左右 12 / 上下 6
/// - 自動タグ: 背景 #E7EFEA、文字 #2F5D50 (12/16 Regular)
/// - 手動タグ: 背景 #DDE8F2、文字 #2F5D50 (12/16 SemiBold)
struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.label)
            .font(.system(size: 12, weight: tag.source == .manual ? .semibold : .regular))
            .lineLimit(1)
            .foregroundStyle(Color(hex: "2F5D50"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tag.source == .auto
                        ? Color(hex: "E7EFEA")
                        : Color(hex: "DDE8F2"))
            )
    }
}

// MARK: - Color Hex Extension

private extension Color {
    /// 16 進数文字列から Color を生成する
    /// - Parameter hex: "RRGGBB" 形式の文字列（# は省略可）
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
