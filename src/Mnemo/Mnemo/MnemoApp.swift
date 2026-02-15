import SwiftUI
import SwiftData

@main
struct MnemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Screenshot.self,
            Tag.self,
            Collection.self,
            CollectionItem.self,
            OCRText.self,
            Embedding.self,
        ])
    }
}
