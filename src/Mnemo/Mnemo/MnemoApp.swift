import SwiftUI
import SwiftData

@main
struct MnemoApp: App {
    private let container: ModelContainer
    @State private var analysisQueue: AnalysisQueue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ModelContainer を明示的に作成
        do {
            let container = try ModelContainer(for:
                Screenshot.self,
                Tag.self,
                Collection.self,
                CollectionItem.self,
                OCRText.self,
                Embedding.self
            )
            self.container = container
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }

        // APIClient の設定
        // TODO: Phase 4（設定画面）で UserDefaults から動的に読み込む
        let baseURLString = "http://localhost:8000"
        guard let baseURL = URL(string: baseURLString) else {
            fatalError("Invalid base URL: \(baseURLString)")
        }
        let apiClient = APIClient(
            baseURL: baseURL,
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
        
        // AnalysisQueue を起動
        queue.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(analysisQueue)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // バックグラウンド移行時にキューをクリーンアップ
                analysisQueue.stop()
            } else if newPhase == .active {
                // フォアグラウンド復帰時にキューを再開
                analysisQueue.start()
            }
        }
    }
}
