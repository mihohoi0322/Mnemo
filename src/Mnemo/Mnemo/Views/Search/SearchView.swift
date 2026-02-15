import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            Text("検索")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("検索")
        }
    }
}

#Preview {
    SearchView()
}
