import Foundation
import SwiftData

@Model
final class CollectionItem {
    var createdAt: Date

    var collection: Collection?
    var screenshot: Screenshot?

    init(
        createdAt: Date = Date()
    ) {
        self.createdAt = createdAt
    }
}
