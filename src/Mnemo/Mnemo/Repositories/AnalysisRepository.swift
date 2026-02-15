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
    /// エラー時は status を .failed に更新し、errorMessage を記録する
    func analyzeScreenshot(_ screenshot: Screenshot) async {
        // 1. status を processing に更新
        screenshot.status = .processing
        screenshot.updatedAt = Date()
        try? modelContext.save()

        do {
            // 2. 画像ファイルを読み込み
            let imageURL = try ImageStorage.resolveURL(relativePath: screenshot.localPath)
            let imageData = try Data(contentsOf: imageURL)

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

        } catch {
            // エラー時: status を failed に更新
            screenshot.status = .failed
            screenshot.errorMessage = error.localizedDescription
            screenshot.retryCount += 1
            screenshot.updatedAt = Date()
            try? modelContext.save()

            print("[AnalysisRepository] 解析に失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// API レスポンスの解析結果を SwiftData に保存する
    private func saveAnalysisResult(_ response: AnalyzeResponse, for screenshot: Screenshot) {
        // OCRText の作成
        let ocrText = OCRText(
            text: response.ocr_text,
            descriptionText: response.description,
            screenshot: screenshot
        )
        modelContext.insert(ocrText)

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

        // Embedding の作成
        let embedding = Embedding(
            floats: response.embedding,
            screenshot: screenshot
        )
        modelContext.insert(embedding)
    }
}
