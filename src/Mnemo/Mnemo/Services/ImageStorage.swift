import Foundation
import UIKit

enum ImageStorageError: LocalizedError {
    case documentsDirectoryNotFound
    case jpegConversionFailed
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Documents ディレクトリが見つかりません"
        case .jpegConversionFailed:
            return "JPEG 変換に失敗しました"
        case .saveFailed(let error):
            return "画像の保存に失敗しました: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "画像の削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

struct ImageStorage {

    // MARK: - Properties

    private static var documentsDirectory: URL {
        get throws {
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw ImageStorageError.documentsDirectoryNotFound
            }
            return url
        }
    }

    // MARK: - Public Methods

    /// 画像データを JPEG に変換して Documents/{uuid}.jpg に保存する
    /// - Parameters:
    ///   - imageData: 元画像データ（PNG / HEIC など任意形式）
    ///   - id: Screenshot の UUID（ファイル名に使用）
    /// - Returns: 相対パス "{uuid}.jpg"
    static func save(imageData: Data, id: UUID) throws -> String {
        guard let uiImage = UIImage(data: imageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
            throw ImageStorageError.jpegConversionFailed
        }

        let relativePath = "\(id.uuidString).jpg"
        let fileURL = try documentsDirectory.appendingPathComponent(relativePath)

        do {
            try jpegData.write(to: fileURL, options: .atomic)
        } catch {
            throw ImageStorageError.saveFailed(underlying: error)
        }

        return relativePath
    }

    /// 相対パスのファイルを削除する
    /// - Parameter relativePath: Documents ディレクトリ基準の相対パス
    static func delete(relativePath: String) throws {
        let fileURL = try documentsDirectory.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return // ファイルが存在しない場合は何もしない
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw ImageStorageError.deleteFailed(underlying: error)
        }
    }

    /// 相対パスから絶対 URL を解決する
    /// - Parameter relativePath: Documents ディレクトリ基準の相対パス
    /// - Returns: 絶対 URL
    static func resolveURL(relativePath: String) throws -> URL {
        return try documentsDirectory.appendingPathComponent(relativePath)
    }

    /// ファイルが存在するか確認する
    /// - Parameter relativePath: Documents ディレクトリ基準の相対パス
    /// - Returns: ファイルが存在すれば true
    static func exists(relativePath: String) -> Bool {
        guard let url = try? documentsDirectory.appendingPathComponent(relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path())
    }
}
