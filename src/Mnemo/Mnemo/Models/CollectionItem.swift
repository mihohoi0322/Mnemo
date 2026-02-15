import Foundation
import SwiftData

@Model
final class CollectionItem {
    var createdAt: Date

    var collection: Collection
    var screenshot: Screenshot

    init(
        collection: Collection,
        screenshot: Screenshot,
        createdAt: Date = Date()
    ) {
        self.collection = collection
        self.screenshot = screenshot
        self.createdAt = createdAt
    }
}
