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
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingFloorIntro = false

    var body: some View {
        TabView {
            RoutesView()
                .tabItem { Label("Routes", systemImage: "map") }

            NearbyView()
                .tabItem { Label("Nearby", systemImage: "dot.radiowaves.forward") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear {
            // First launch only, and only on iPhones with a barometer whose
            // Motion & Fitness permission hasn't been answered yet.
            model.floorTracker.refreshAccess()
            showingFloorIntro = !model.settings.hasSeenFloorIntro && model.floorTracker.access == .notAsked
        }
        .onChange(of: scenePhase) { _, phase in
            // The person may have changed the permission in iPhone Settings.
            if phase == .active { model.floorTracker.refreshAccess() }
        }
        .sheet(isPresented: $showingFloorIntro) {
            FloorIntroView()
                .environment(model)
        }
    }
}
