import Foundation
import SwiftData

@Observable
final class AnalysisRepository {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let apiClient: APIClient

    // MARK: - Init

    init(modelContext: ModelContext, apiClient: APIClient) {
        self.modelContext = modelContext
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    /// Screenshot を AI 分析に送信し、結果を SwiftData に保存する
    ///
    /// 処理フロー:
    /// 1. status を .processing に更新
    /// 2. 画像ファイルを読み込み、Base64 エンコード
    /// 3. APIClient で /analyze に送信
    /// 4. レスポンスから OCRText, Tag(auto), Embedding を作成
    /// 5. status を .success に更新
    ///
    /// 失敗時はエラーを throw する。ステータス管理は呼び出し元（AnalysisQueue）の責務。
    func analyzeScreenshot(_ screenshot: Screenshot) async throws {
        // 1. status を processing に更新
        screenshot.status = .processing
        screenshot.updatedAt = Date()
        try? modelContext.save()

        // 2. 画像ファイルを読み込み（バックグラウンドで実行）
        let imageURL = try ImageStorage.resolveURL(relativePath: screenshot.localPath)
        let imageData = try await Task.detached(priority: .background) {
            try Data(contentsOf: imageURL)
        }.value

        // 3. APIClient で /analyze に送信
        let response = try await apiClient.analyze(
            imageData: imageData,
            imageId: screenshot.id
        )

        // 4. レスポンスから SwiftData に保存
        saveAnalysisResult(response, for: screenshot)

        // 5. status を success に更新
        screenshot.status = .success
        screenshot.errorMessage = nil
        screenshot.updatedAt = Date()
        try modelContext.save()
    }

    // MARK: - Private Methods

    /// API レスポンスの解析結果を SwiftData に保存する
    private func saveAnalysisResult(_ response: AnalyzeResponse, for screenshot: Screenshot) {
        // OCRText の作成 / 更新（Screenshot.ocrText は to-one のため）
        if let existingOCRText = screenshot.ocrText {
            existingOCRText.text = response.ocr_text
            existingOCRText.descriptionText = response.description
        } else {
            let ocrText = OCRText(
                text: response.ocr_text,
                descriptionText: response.description,
                screenshot: screenshot
            )
            modelContext.insert(ocrText)
        }

        // Tag（auto）の作成
        for tagItem in response.tags {
            let tag = Tag(
                label: tagItem.label,
                source: .auto,
                confidence: tagItem.confidence,
                screenshot: screenshot
            )
            modelContext.insert(tag)
        }

        // Embedding の作成 / 更新（Screenshot.embedding は to-one のため）
        if let existingEmbedding = screenshot.embedding {
            // floats は computed property なので、vector を直接更新
            let data = response.embedding.withUnsafeBufferPointer { Data(buffer: $0) }
            existingEmbedding.vector = data
        } else {
            let embedding = Embedding(
                floats: response.embedding,
                screenshot: screenshot
            )
            modelContext.insert(embedding)
        }
    }
}
