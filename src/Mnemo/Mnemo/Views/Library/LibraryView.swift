import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            Text("ライブラリ")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("ライブラリ")
        }
    }
}

#Preview {
    LibraryView()
}
