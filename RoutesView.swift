import SwiftUI

/// Routes tab: choose where you are and where you're going.
struct RoutesView: View {
    @Environment(AppModel.self) private var model

    @State private var startID: String?
    @State private var destinationID: String?
    @State private var path: [RouteRequest] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let map = model.activeMap {
                    form(for: map)
                } else {
                    ContentUnavailableView(
                        "Map could not be loaded",
                        systemImage: "exclamationmark.triangle",
                        description: Text(model.mapLoadError ?? "Unknown error.")
                    )
                }
            }
            .navigationTitle("Routes")
            .navigationDestination(for: RouteRequest.self) { request in
                RouteResultView(request: request)
            }
        }
    }

    private func form(for map: CampusMap) -> some View {
        @Bindable var settings = model.settings

        return Form {
            Section {
                DemoDataBanner(map: map, simulatedOutages: model.simulatedOutages)
            }

            Section {
                LandmarkPicker(title: "Starting point", map: map,
                               landmarks: map.startLandmarks, selection: $startID)
                LandmarkPicker(title: "Destination", map: map,
                               landmarks: map.destinationLandmarks, selection: $destinationID)
            } header: {
                Text("Where are you?")
            } footer: {
                Text("Choose the landmark you are at now. You'll confirm it before guidance starts; the app does not track your position indoors.")
            }

            Section {
                Toggle("Step-free route", isOn: $settings.requireStepFree)
            } footer: {
                Text(settings.requireStepFree
                     ? "Only connections confirmed step-free are used. Stairs and anything unconfirmed are excluded."
                     : "The shortest route may include stairs.")
            }

            Section {
                Button {
                    if let startID, let destinationID {
                        path.append(RouteRequest(startID: startID, destinationID: destinationID))
                    }
                } label: {
                    Text("Find route")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSearch)
                .accessibilityHint(searchHint)
            }
        }
    }

    private var canSearch: Bool {
        guard let startID, let destinationID else { return false }
        return startID != destinationID
    }

    private var searchHint: String {
        if startID == nil || destinationID == nil {
            return "Choose a starting point and destination first."
        }
        if startID == destinationID {
            return "Starting point and destination are the same."
        }
        return "Shows a summary of the route before guidance starts."
    }
}

/// A picker that lists landmarks grouped by floor.
struct LandmarkPicker: View {
    let title: String
    let map: CampusMap
    let landmarks: [Landmark]
    @Binding var selection: String?

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Not selected").tag(String?.none)
            ForEach(map.sortedFloors) { floor in
                let onFloor = landmarks.filter { $0.floorID == floor.id }
                if !onFloor.isEmpty {
                    Section(floor.name) {
                        ForEach(onFloor) { landmark in
                            Text(landmark.name).tag(Optional(landmark.id))
                        }
                    }
                }
            }
        }
        .pickerStyle(.navigationLink)
    }
}
