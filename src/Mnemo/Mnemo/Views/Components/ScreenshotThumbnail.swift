import SwiftUI

struct ScreenshotThumbnail: View {
    let screenshot: Screenshot

    var body: some View {
        Group {
            if let url = try? ImageStorage.resolveURL(relativePath: screenshot.localPath),
               let uiImage = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // ファイルが見つからない場合のフォールバック
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
