import SwiftUI

@MainActor
@Observable
final class DetailViewModel {

    // MARK: - State

    var showDeleteConfirmation = false
    var errorMessage: String?
    
    /// キャッシュされた画像（一度だけディスクから読み込む）
    private(set) var cachedImage: UIImage?

    // MARK: - Dependencies

    let screenshot: Screenshot
    private let repository: ScreenshotRepository
    private var analysisQueue: AnalysisQueue?

    // MARK: - Init

    init(screenshot: Screenshot, repository: ScreenshotRepository) {
        self.screenshot = screenshot
        self.repository = repository
        // 初期化時に画像を読み込んでキャッシュする
        self.cachedImage = Self.loadImage(from: screenshot.localPath)
    }

    /// @Environment からの遅延注入用（一度だけ設定される）
    func setAnalysisQueue(_ queue: AnalysisQueue) {
        // Ensure the analysisQueue is only initialized once, even if called multiple times
        guard analysisQueue == nil else { return }
        self.analysisQueue = queue
    }
    
    /// 画像をディスクから読み込む（プライベートヘルパー）
    private static func loadImage(from relativePath: String) -> UIImage? {
        guard let url = try? ImageStorage.resolveURL(relativePath: relativePath) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path())
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

    // MARK: - Analysis Results

    /// OCR テキスト（解析完了時のみ表示）
    var ocrText: String? {
        screenshot.ocrText?.text
    }

    /// AI 生成の説明文
    var descriptionText: String? {
        screenshot.ocrText?.descriptionText
    }

    /// 自動タグ一覧（信頼度降順）
    var autoTags: [Tag] {
        screenshot.tags
            .filter { $0.source == .auto }
            .sorted { ($0.confidence ?? 0) > ($1.confidence ?? 0) }
    }

    /// タグが存在するか
    var hasTags: Bool {
        !screenshot.tags.isEmpty
    }

    /// 自動タグが存在するか
    var hasAutoTags: Bool {
        !autoTags.isEmpty
    }

    /// OCR テキストが存在するか
    var hasOCRText: Bool {
        screenshot.ocrText != nil
    }

    // MARK: - Retry

    /// 手動リトライが可能か
    var canRetry: Bool {
        guard let analysisQueue else {
            assertionFailure("DetailViewModel.analysisQueue is nil; retry availability cannot be determined. Verify dependency injection.")
            return false
        }
        return analysisQueue.canRetry(screenshot)
    }

    /// 手動リトライ実行
    func retry() {
        guard let analysisQueue else {
            assertionFailure("DetailViewModel.analysisQueue is nil; cannot perform manual retry. Verify dependency injection.")
            return
        }
        analysisQueue.retryManually(screenshot)
    }
}
