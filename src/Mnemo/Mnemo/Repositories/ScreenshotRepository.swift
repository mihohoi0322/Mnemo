import Foundation
import SwiftData

@Observable
final class ScreenshotRepository {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    /// 画像データから Screenshot を作成する
    /// 1. ImageStorage で JPEG 保存
    /// 2. SwiftData に Screenshot レコード作成（status: .pending）
    /// 3. modelContext.save()
    func create(imageData: Data) throws -> Screenshot {
        let id = UUID()

        // ファイル保存
        let relativePath = try ImageStorage.save(imageData: imageData, id: id)

        // SwiftData レコード作成
        let screenshot = Screenshot(
            id: id,
            localPath: relativePath,
            status: .pending
        )
        modelContext.insert(screenshot)

        do {
            try modelContext.save()
        } catch {
            // DB 保存失敗時はファイルをクリーンアップ
            try? ImageStorage.delete(relativePath: relativePath)
            throw error
        }

        return screenshot
    }

    /// 複数の画像データから Screenshot を一括作成する
    /// 個別の失敗はスキップし、成功した分だけ返す
    func createBatch(imageDatas: [Data]) -> (screenshots: [Screenshot], failedCount: Int) {
        var screenshots: [Screenshot] = []
        var failedCount = 0

        for imageData in imageDatas {
            do {
                let screenshot = try create(imageData: imageData)
                screenshots.append(screenshot)
            } catch {
                failedCount += 1
                print("[ScreenshotRepository] 画像の保存に失敗: \(error.localizedDescription)")
            }
        }

        return (screenshots, failedCount)
    }

    /// 全 Screenshot を取得する（新しい順）
    func fetchAll() throws -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 指定 Screenshot を削除する
    /// 1. ImageStorage でファイル削除（失敗はログのみ）
    /// 2. SwiftData からレコード削除（cascade で関連レコードも削除）
    func delete(_ screenshot: Screenshot) throws {
        // ファイル削除（失敗してもレコード削除は続行）
        do {
            try ImageStorage.delete(relativePath: screenshot.localPath)
        } catch {
            print("[ScreenshotRepository] ファイル削除に失敗（レコード削除は続行）: \(error.localizedDescription)")
        }

        modelContext.delete(screenshot)
        try modelContext.save()
    }
}
