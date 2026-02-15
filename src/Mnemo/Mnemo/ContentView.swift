import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }

            LibraryView()
                .tabItem {
                    Label("ライブラリ", systemImage: "photo.on.rectangle")
                }

            CollectionsView()
                .tabItem {
                    Label("コレクション", systemImage: "folder")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
