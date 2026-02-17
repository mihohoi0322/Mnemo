import Foundation
import SwiftData
import Network

/// 画像解析の自動キュー管理サービス
///
/// 責務:
/// - 画像インポート後の自動解析キューイング
/// - 指数バックオフによる自動リトライ（30秒 / 2分 / 5分で最大 3 回試行 = 初回 + リトライ 2 回）
/// - NWPathMonitor によるオフライン検知・復帰時自動再開
/// - 手動リトライ（上限なし、10 秒クールダウン）
/// - 削除済み Screenshot の解析結果破棄
@MainActor
@Observable
final class AnalysisQueue {

    // MARK: - UI 公開プロパティ

    private(set) var isProcessing = false
    private(set) var pendingCount = 0
    private(set) var currentScreenshot: Screenshot?
    private(set) var isOnline = true

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let analysisRepository: AnalysisRepository

    // MARK: - Network Monitor

    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.mnemo.networkMonitor")

    // MARK: - Internal State

    private var processingTask: Task<Void, Never>?
    private var isStarted = false

    // MARK: - Constants

    private static let maxAutoRetries = 3
    private static let manualRetryCooldown: TimeInterval = 10

    // MARK: - Init

    init(modelContext: ModelContext, analysisRepository: AnalysisRepository) {
        self.modelContext = modelContext
        self.analysisRepository = analysisRepository
        self.pathMonitor = NWPathMonitor()
    }

    // MARK: - Lifecycle

    /// アプリ起動時に呼び出す。ネットワーク監視開始 + 中断した処理の回復
    func start() {
        guard !isStarted else { return }
        isStarted = true

        startMonitoring()
        recoverStaleProcessing()
        updatePendingCount()

        if pendingCount > 0 {
            triggerProcessing()
        }
    }

    /// アプリ終了時のクリーンアップ
    func stop() {
        pathMonitor.cancel()
        processingTask?.cancel()
        processingTask = nil
        isStarted = false
    }

    // MARK: - Public API

    /// 新しい Screenshot を解析キューに追加する
    ///
    /// Screenshot はすでに status: .pending で作成されている前提。
    /// キューへの追加 = 処理ループの起動トリガー。
    func enqueue(_ screenshots: [Screenshot]) {
        // すべての Screenshot が .pending 状態であることを検証
        var didChangeStatus = false
        for screenshot in screenshots {
            if screenshot.status != .pending {
                assertionFailure("AnalysisQueue.enqueue(_:) expects screenshots with status `.pending`.")
                screenshot.status = .pending
                screenshot.updatedAt = Date()
                didChangeStatus = true
            }
        }

        if didChangeStatus {
            try? modelContext.save()
        }

        updatePendingCount()
        triggerProcessing()
    }

    /// 手動リトライ（DetailView から呼ばれる）
    ///
    /// 上限なし。ただし直近失敗から 10 秒のクールダウンを設ける。
    func retryManually(_ screenshot: Screenshot) {
        guard screenshot.status == .failed else { return }
        guard canRetry(screenshot) else { return }

        screenshot.status = .pending
        screenshot.updatedAt = Date()
        try? modelContext.save()

        updatePendingCount()
        triggerProcessing()
    }

    /// 手動リトライが可能かどうか（10 秒クールダウン）
    func canRetry(_ screenshot: Screenshot) -> Bool {
        guard screenshot.status == .failed else { return false }
        let elapsed = Date().timeIntervalSince(screenshot.updatedAt)
        return elapsed >= Self.manualRetryCooldown
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let pathStatus = path.status
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                let isCurrentlyOnline = (pathStatus == .satisfied)
                self.isOnline = isCurrentlyOnline

                // オフライン → オンライン復帰時に処理再開
                if wasOffline && isCurrentlyOnline {
                    self.triggerProcessing()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Recovery

    /// 前回 .processing のまま終了した Screenshot を .pending に戻す
    private func recoverStaleProcessing() {
        let allScreenshots = fetchAllScreenshots()
        let stale = allScreenshots.filter { $0.status == .processing }

        for screenshot in stale {
            screenshot.status = .pending
            screenshot.updatedAt = Date()
        }

        if !stale.isEmpty {
            try? modelContext.save()
            print("[AnalysisQueue] \(stale.count) 件の中断された処理を回復しました")
        }
    }

    // MARK: - Processing

    /// 処理ループを起動する（既に実行中なら何もしない）
    private func triggerProcessing() {
        guard processingTask == nil else { return }

        processingTask = Task {
            await processQueue()
            processingTask = nil
        }
    }

    /// 逐次処理ループ（コアロジック）
    ///
    /// pending な Screenshot を一つずつ取得し、AnalysisRepository で解析する。
    /// 一時的エラーの場合はバックオフ後に再試行、永続的エラーの場合は .failed のまま。
    private func processQueue() async {
        isProcessing = true
        defer {
            isProcessing = false
            currentScreenshot = nil
            updatePendingCount()
        }

        while !Task.isCancelled {
            // オフラインなら一時停止
            guard isOnline else { break }

            // 次の pending を取得
            let pending = fetchPendingScreenshots()
            guard let screenshot = pending.first else { break }

            // 削除済みチェック
            guard screenshotStillExists(screenshot.id) else { continue }

            currentScreenshot = screenshot
            updatePendingCount()

            // 解析実行
            do {
                try await analysisRepository.analyzeScreenshot(screenshot)
                // 成功 → 次の pending へ
                // 解析後に削除されていないか再確認
                guard screenshotStillExists(screenshot.id) else { continue }
            } catch {
                // 解析後に削除済みチェック
                guard screenshotStillExists(screenshot.id) else { continue }

                // エラー記録
                screenshot.status = .failed
                screenshot.errorMessage = error.localizedDescription
                screenshot.retryCount += 1
                screenshot.updatedAt = Date()
                try? modelContext.save()

                print("[AnalysisQueue] 解析失敗 (\(screenshot.retryCount)回目): \(error.localizedDescription)")

                // 一時的エラーかつリトライ上限以内なら再キュー + バックオフ
                if isTransientError(error) && screenshot.retryCount < Self.maxAutoRetries {
                    screenshot.status = .pending
                    try? modelContext.save()

                    let delay = backoffInterval(for: screenshot.retryCount)
                    print("[AnalysisQueue] \(delay)秒後にリトライします")
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch is CancellationError {
                        break
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// 全 Screenshot を取得する
    private func fetchAllScreenshots() -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// pending な Screenshot を取得する（作成日順）
    private func fetchPendingScreenshots() -> [Screenshot] {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.status == .pending },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// pendingCount を更新する
    private func updatePendingCount() {
        pendingCount = fetchPendingScreenshots().count
    }

    /// Screenshot がまだ存在するか確認する（削除済み検出）
    private func screenshotStillExists(_ id: UUID) -> Bool {
        let descriptor = FetchDescriptor<Screenshot>(
            predicate: #Predicate { $0.id == id },
            fetchLimit: 1
        )
        guard let result = try? modelContext.fetch(descriptor) else {
            return false
        }
        return !result.isEmpty
    }

    /// エラーが一時的かどうかを判定する
    ///
    /// 一時的エラー → 自動リトライ対象
    /// 永続的エラー → .failed のまま（手動リトライのみ）
    private func isTransientError(_ error: Error) -> Bool {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .networkError, .rateLimited, .serverUnavailable:
                return true
            case .invalidURL, .decodingError, .httpError:
                return false
            }
        }
        // ImageStorage のエラー等はリトライしても無駄
        return false
    }

    /// 指数バックオフの待機時間（秒）
    ///
    /// retryCount 1 → 30秒, 2 → 2分, 3 → 5分
    private func backoffInterval(for retryCount: Int) -> TimeInterval {
        switch retryCount {
        case 1: return 30
        case 2: return 120
        case 3: return 300
        default:
            // maxAutoRetries により retryCount は 3 を超えない想定だが、
            // 万が一それ以上になった場合も 5 分間隔でリトライする
            return 300
        }
    }
}
