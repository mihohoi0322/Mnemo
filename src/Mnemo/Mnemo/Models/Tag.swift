import Foundation
import SwiftData

enum TagSource: String, Codable {
    case auto
    case manual
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var label: String
    var source: TagSource
    var confidence: Double?
    var createdAt: Date

    var screenshot: Screenshot

    init(
        id: UUID = UUID(),
        label: String,
        source: TagSource,
        confidence: Double? = nil,
        createdAt: Date = Date(),
        screenshot: Screenshot
    ) {
        self.id = id
        self.label = label
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.screenshot = screenshot
    }
}
