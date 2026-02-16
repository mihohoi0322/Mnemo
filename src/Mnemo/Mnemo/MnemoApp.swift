import SwiftUI
import SwiftData

@main
struct MnemoApp: App {
    private let container: ModelContainer
    @State private var analysisQueue: AnalysisQueue

    init() {
        // ModelContainer を明示的に作成
        let container = try! ModelContainer(for:
            Screenshot.self,
            Tag.self,
            Collection.self,
            CollectionItem.self,
            OCRText.self,
            Embedding.self
        )
        self.container = container

        // APIClient の設定
        // TODO: Phase 4（設定画面）で UserDefaults から動的に読み込む
        let apiClient = APIClient(
            baseURL: URL(string: "http://localhost:8000")!,
            apiKey: ""
        )

        let modelContext = container.mainContext
        let analysisRepository = AnalysisRepository(
            modelContext: modelContext,
            apiClient: apiClient
        )
        let queue = AnalysisQueue(
            modelContext: modelContext,
            analysisRepository: analysisRepository
        )
        self._analysisQueue = State(initialValue: queue)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(analysisQueue)
                .task {
                    analysisQueue.start()
                }
        }
        .modelContainer(container)
    }
}
