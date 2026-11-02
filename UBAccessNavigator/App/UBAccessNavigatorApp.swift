import SwiftUI

@main
struct UBAccessNavigatorApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            RoutesView()
                .tabItem { Label("Routes", systemImage: "map") }

            NearbyView()
                .tabItem { Label("Nearby", systemImage: "dot.radiowaves.forward") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
