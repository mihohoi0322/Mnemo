import Foundation
import SwiftData

@Model
final class OCRText {
    var text: String
    var descriptionText: String
    var language: String?
    var createdAt: Date

    var screenshot: Screenshot

    init(
        text: String,
        descriptionText: String,
        language: String? = nil,
        createdAt: Date = Date(),
        screenshot: Screenshot
    ) {
        self.text = text
        self.descriptionText = descriptionText
        self.language = language
        self.createdAt = createdAt
        self.screenshot = screenshot
    }
}
