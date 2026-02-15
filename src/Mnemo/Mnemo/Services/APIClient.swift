import Foundation
import UIKit

// MARK: - Error

enum APIClientError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case networkError(underlying: Error)
    case rateLimited(retryAfter: Int?)
    case serverUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効な URL です"
        case .httpError(let statusCode, let message):
            if let message {
                return "HTTP エラー \(statusCode): \(message)"
            }
            return "HTTP エラー \(statusCode)"
        case .decodingError(let error):
            return "レスポンスの解析に失敗しました: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "リクエスト制限中です。\(seconds)秒後に再試行してください"
            }
            return "リクエスト制限中です。しばらく待ってから再試行してください"
        case .serverUnavailable:
            return "サーバーが一時的に利用できません"
        }
    }
}

// MARK: - Request / Response Types

/// /analyze リクエスト
struct AnalyzeRequest: Encodable {
    let image: String
    let image_id: String
    let language_hint: String?
}

/// /analyze レスポンスのタグ要素
struct AnalyzeTagItem: Decodable {
    let label: String
    let confidence: Double
}

/// /analyze レスポンス
struct AnalyzeResponse: Decodable {
    let image_id: String
    let ocr_text: String
    let description: String
    let tags: [AnalyzeTagItem]
    let embedding: [Float]
}

/// /embed リクエスト
struct EmbedRequest: Encodable {
    let text: String
}

/// /embed レスポンス
struct EmbedResponse: Decodable {
    let embedding: [Float]
}

/// /search/embed リクエスト
struct SearchEmbedRequest: Encodable {
    let query: String
}

/// /search/embed レスポンス
struct SearchEmbedResponse: Decodable {
    let embedding: [Float]
}

// MARK: - APIClient

final class APIClient {

    // MARK: - Properties

    let baseURL: URL
    let apiKey: String
    let deviceId: String
    private let session: URLSession

    // MARK: - Init

    init(baseURL: URL, apiKey: String, deviceId: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.deviceId = deviceId
        self.session = session
    }

    /// デバイス ID を自動取得する便利イニシャライザ
    convenience init(baseURL: URL, apiKey: String) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.init(baseURL: baseURL, apiKey: apiKey, deviceId: deviceId)
    }

    // MARK: - Public Methods

    /// 画像解析リクエスト — POST /analyze
    /// - Parameters:
    ///   - imageData: 画像のバイナリデータ（JPEG）
    ///   - imageId: 画像の UUID
    ///   - languageHint: 言語ヒント（例: "ja", "en"）
    /// - Returns: 解析結果（OCR テキスト、タグ、説明文、埋め込みベクトル）
    func analyze(imageData: Data, imageId: UUID, languageHint: String? = nil) async throws -> AnalyzeResponse {
        let base64Image = imageData.base64EncodedString()
        let request = AnalyzeRequest(
            image: base64Image,
            image_id: imageId.uuidString,
            language_hint: languageHint
        )
        return try await performRequest(path: "/analyze", body: request)
    }

    /// テキスト埋め込みリクエスト — POST /embed
    /// - Parameter text: 埋め込みベクトルを生成するテキスト
    /// - Returns: 512 次元の埋め込みベクトル
    func embed(text: String) async throws -> EmbedResponse {
        let request = EmbedRequest(text: text)
        return try await performRequest(path: "/embed", body: request)
    }

    /// 検索クエリ埋め込みリクエスト — POST /search/embed
    /// - Parameter query: 検索クエリ文字列
    /// - Returns: 512 次元の埋め込みベクトル
    func searchEmbed(query: String) async throws -> SearchEmbedResponse {
        let request = SearchEmbedRequest(query: query)
        return try await performRequest(path: "/search/embed", body: request)
    }

    // MARK: - Private Methods

    /// 共通の HTTP リクエスト送信ロジック
    private func performRequest<T: Decodable>(path: String, body: some Encodable) async throws -> T {
        // URL 構築（baseURL のパス・クエリを維持したまま path を結合）
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw APIClientError.invalidURL
        }

        let basePath = components.path
        // path の先頭の "/" は一度取り除いて結合する
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        if basePath.isEmpty || basePath == "/" {
            components.path = "/" + relativePath
        } else if basePath.hasSuffix("/") {
            components.path = basePath + relativePath
        } else {
            components.path = basePath + "/" + relativePath
        }

        guard let url = components.url else {
            throw APIClientError.invalidURL
        }

        // リクエスト作成
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-functions-key")
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        // ボディをエンコード
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(body)

        // リクエスト送信
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIClientError.networkError(underlying: error)
        }

        // HTTP レスポンスの検証
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break // 成功
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw APIClientError.rateLimited(retryAfter: retryAfter)
        case 503:
            throw APIClientError.serverUnavailable
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        // レスポンスのデコード
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(underlying: error)
        }
    }
}
