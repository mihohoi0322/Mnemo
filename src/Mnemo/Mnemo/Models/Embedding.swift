import Foundation
import SwiftData

@Model
final class Embedding {
    var vector: Data
    var createdAt: Date

    var screenshot: Screenshot

    init(
        vector: Data,
        screenshot: Screenshot,
        createdAt: Date = Date()
    ) {
        self.vector = vector
        self.screenshot = screenshot
        self.createdAt = createdAt
    }

    /// [Float] 配列からベクトルデータを生成
    convenience init(
        floats: [Float],
        screenshot: Screenshot,
        createdAt: Date = Date()
    ) {
        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        self.init(vector: data, screenshot: screenshot, createdAt: createdAt)
    }

    /// Data を [Float] に変換
    var floats: [Float] {
        let byteCount = vector.count
        let floatStride = MemoryLayout<Float>.stride

        // データサイズが Float の stride の倍数でない場合は不正とみなし、安全側として空配列を返す
        guard byteCount % floatStride == 0 else {
            return []
        }

        let floatCount = byteCount / floatStride

        return vector.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            return Array(floatBuffer.prefix(floatCount))
        }
    }
}
