import SwiftUI
import PhotosUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LibraryViewModel?
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.isLoading {
                        ProgressView("取り込み中…")
                    } else if viewModel.screenshots.isEmpty {
                        emptyStateView
                    } else {
                        screenshotGrid(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("ライブラリ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                guard !newItems.isEmpty, let viewModel else { return }
                Task {
                    await viewModel.importSelectedPhotos(from: newItems)
                    selectedItems = []
                }
            }
            .task {
                if viewModel == nil {
                    let vm = LibraryViewModel(
                        repository: ScreenshotRepository(modelContext: modelContext)
                    )
                    viewModel = vm
                }
                viewModel?.loadScreenshots()
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { viewModel?.errorMessage != nil },
                    set: { if !$0 { viewModel?.errorMessage = nil } }
                )
            ) {
                Button("OK") {
                    viewModel?.errorMessage = nil
                }
            } message: {
                if let msg = viewModel?.errorMessage {
                    Text(msg)
                }
            }
        }
    }

    // MARK: - Subviews

    private func screenshotGrid(viewModel: LibraryViewModel) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(viewModel.screenshots, id: \.id) { screenshot in
                    ScreenshotThumbnail(screenshot: screenshot)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("まだ画像がありません", systemImage: "photo.on.rectangle")
        } description: {
            Text("スクショを保存してみよう")
        } actions: {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 20,
                matching: .images
            ) {
                Text("画像を追加")
            }
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [
            Screenshot.self,
            Tag.self,
            Collection.self,
            CollectionItem.self,
            OCRText.self,
            Embedding.self,
        ])
}
