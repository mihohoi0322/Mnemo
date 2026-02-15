import SwiftUI
import PhotosUI

@Observable
final class LibraryViewModel {

    // MARK: - State

    var screenshots: [Screenshot] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private(set) var repository: ScreenshotRepository

    // MARK: - Init

    init(repository: ScreenshotRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    /// 画面表示時に全画像を読み込む
    func loadScreenshots() {
        do {
            screenshots = try repository.fetchAll()
        } catch {
            errorMessage = "画像の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// PhotosPicker で選択された画像を処理する
    /// PhotosPickerItem から Data をロードし、Repository で保存する
    func importSelectedPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        var imageDatas: [Data] = []
        var loadFailedCount = 0

        // PhotosPickerItem → Data の変換（非同期）
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    imageDatas.append(data)
                } else {
                    loadFailedCount += 1
                }
            } catch {
                loadFailedCount += 1
                print("[LibraryViewModel] 画像データのロードに失敗: \(error.localizedDescription)")
            }
        }

        // Repository で一括保存
        let result = repository.createBatch(imageDatas: imageDatas)
        let totalFailed = loadFailedCount + result.failedCount

        if totalFailed > 0 {
            errorMessage = "\(totalFailed)枚の画像が取り込めませんでした"
        }

        // 一覧を更新
        loadScreenshots()
    }

    /// Screenshot を削除する
    func deleteScreenshot(_ screenshot: Screenshot) {
        do {
            try repository.delete(screenshot)
            loadScreenshots()
        } catch {
            errorMessage = "画像の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
