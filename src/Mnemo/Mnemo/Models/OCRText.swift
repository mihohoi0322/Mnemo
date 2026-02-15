import Foundation
import SwiftData

@Model
final class OCRText {
    var text: String
    var description: String
    var language: String?
    var createdAt: Date

    var screenshot: Screenshot

    init(
        text: String,
        description: String,
        language: String? = nil,
        createdAt: Date = Date(),
        screenshot: Screenshot
    ) {
        self.text = text
        self.description = description
        self.language = language
        self.createdAt = createdAt
        self.screenshot = screenshot
    }
}
