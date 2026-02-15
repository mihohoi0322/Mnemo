import SwiftUI

struct CollectionsView: View {
    var body: some View {
        NavigationStack {
            Text("コレクション")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("コレクション")
        }
    }
}

#Preview {
    CollectionsView()
}
