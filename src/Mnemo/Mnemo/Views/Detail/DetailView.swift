import SwiftUI

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AnalysisQueue.self) private var analysisQueue
    @State private var viewModel: DetailViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    /// LibraryViewModel を受け取り、削除後に一覧を更新する
    private var onDelete: (() -> Void)?

    init(screenshot: Screenshot, repository: ScreenshotRepository, onDelete: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: DetailViewModel(
            screenshot: screenshot,
            repository: repository
        ))
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - 画像プレビュー
                imagePreview
                    .padding(.bottom, 16)

                // MARK: - メタデータ
                metadataSection
                    .padding(.horizontal, 16)

                // MARK: - タグ
                if viewModel.hasAutoTags {
                    tagsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                // MARK: - OCR テキスト
                if viewModel.hasOCRText {
                    ocrTextSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                Spacer(minLength: 80)
            }
        }
        .scrollDisabled(zoomScale > 1.0)
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .task {
            viewModel.setAnalysisQueue(analysisQueue)
        }
        .confirmationDialog(
            "この画像を削除しますか？",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                if viewModel.delete() {
                    onDelete?()
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません")
        }
        .alert(
            "エラー",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var imagePreview: some View {
        if let uiImage = viewModel.cachedImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoomScale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            zoomScale = lastZoomScale * value.magnification
                        }
                        .onEnded { _ in
                            // 最小 1.0、最大 5.0 に制限
                            zoomScale = min(max(zoomScale, 1.0), 5.0)
                            lastZoomScale = zoomScale
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if zoomScale > 1.0 {
                                    zoomScale = 1.0
                                    lastZoomScale = 1.0
                                } else {
                                    zoomScale = 2.5
                                    lastZoomScale = 2.5
                                }
                            }
                        }
                )
                .clipped()
        } else {
            ContentUnavailableView {
                Label("画像を読み込めません", systemImage: "photo.badge.exclamationmark")
            }
            .frame(height: 300)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タグ")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.autoTags, id: \.id) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    private var ocrTextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup("OCR テキスト") {
                VStack(alignment: .leading, spacing: 12) {
                    if let ocrText = viewModel.ocrText, !ocrText.isEmpty {
                        Text(ocrText)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }

                    if let description = viewModel.descriptionText, !description.isEmpty {
                        Divider()

                        Text("AI 説明")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 8)
            }
            .font(.system(size: 16, weight: .medium))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ステータス
            HStack(spacing: 6) {
                Image(systemName: viewModel.statusIcon)
                    .foregroundStyle(viewModel.statusColor)
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(viewModel.statusColor)

                Spacer()

                // 再試行ボタン
                if viewModel.canRetry {
                    Button {
                        viewModel.retry()
                    } label: {
                        Label("再試行", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
            }

            Divider()

            // 作成日時
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("作成日時")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedCreatedAt)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}
