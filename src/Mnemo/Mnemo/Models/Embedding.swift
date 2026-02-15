import Foundation
import SwiftData

@Model
final class Embedding {
    var vector: Data
    var createdAt: Date

    var screenshot: Screenshot?

    init(
        vector: Data,
        createdAt: Date = Date()
    ) {
        self.vector = vector
        self.createdAt = createdAt
    }

    /// [Float] 配列からベクトルデータを生成
    convenience init(
        floats: [Float],
        createdAt: Date = Date()
    ) {
        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        self.init(vector: data, createdAt: createdAt)
    }

    /// Data を [Float] に変換
    var floats: [Float] {
        vector.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }
}
