import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("設定")
                .font(.title2)
                .foregroundStyle(.secondary)
                .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsView()
}
