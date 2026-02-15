import SwiftUI

@Observable
final class DetailViewModel {

    // MARK: - State

    var showDeleteConfirmation = false
    var errorMessage: String?

    // MARK: - Dependencies

    let screenshot: Screenshot
    private let repository: ScreenshotRepository

    // MARK: - Init

    init(screenshot: Screenshot, repository: ScreenshotRepository) {
        self.screenshot = screenshot
        self.repository = repository
    }

    // MARK: - Actions

    /// Screenshot を削除する（画像ファイル + SwiftData レコード + 関連データ cascade）
    /// 成功時は true を返す（呼び出し元で dismiss する）
    func delete() -> Bool {
        do {
            try repository.delete(screenshot)
            return true
        } catch {
            errorMessage = "画像の削除に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Computed

    /// 画像の UIImage を取得する
    var image: UIImage? {
        guard let url = try? ImageStorage.resolveURL(relativePath: screenshot.localPath) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path())
    }

    /// 作成日時の表示用テキスト
    var formattedCreatedAt: String {
        screenshot.createdAt.formatted(
            .dateTime.year().month().day().hour().minute()
        )
    }

    /// 解析ステータスの表示用テキスト
    var statusText: String {
        switch screenshot.status {
        case .pending:
            "解析待ち"
        case .processing:
            "解析中"
        case .success:
            "解析完了"
        case .failed:
            "解析失敗"
        }
    }

    /// 解析ステータスのアイコン
    var statusIcon: String {
        switch screenshot.status {
        case .pending:
            "clock"
        case .processing:
            "arrow.trianglehead.2.clockwise"
        case .success:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    /// 解析ステータスの色
    var statusColor: Color {
        switch screenshot.status {
        case .pending:
            .orange
        case .processing:
            .blue
        case .success:
            .green
        case .failed:
            .red
        }
    }
}
