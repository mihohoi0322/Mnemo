import Foundation
import SwiftData

enum AnalysisStatus: String, Codable {
    case pending
    case processing
    case success
    case failed
}

@Model
final class Screenshot {
    @Attribute(.unique) var id: UUID
    var localPath: String
    var createdAt: Date
    var updatedAt: Date
    var status: AnalysisStatus
    var title: String?
    var errorMessage: String?
    var retryCount: Int

    @Relationship(deleteRule: .cascade, inverse: \Tag.screenshot)
    var tags: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \OCRText.screenshot)
    var ocrText: OCRText?

    @Relationship(deleteRule: .cascade, inverse: \Embedding.screenshot)
    var embedding: Embedding?

    @Relationship(deleteRule: .cascade, inverse: \CollectionItem.screenshot)
    var collectionItems: [CollectionItem] = []

    init(
        id: UUID = UUID(),
        localPath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: AnalysisStatus = .pending,
        title: String? = nil,
        errorMessage: String? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.localPath = localPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.title = title
        self.errorMessage = errorMessage
        self.retryCount = retryCount
    }
}
