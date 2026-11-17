import SwiftUI

/// Shows either a readable route summary or a clear "No route found" state.
struct RouteResultView: View {
    @Environment(AppModel.self) private var model
    let request: RouteRequest

    @State private var guidance: RouteGuidance?

    var body: some View {
        Group {
            switch model.planRoute(request) {
            case .success(let route)?:
                summary(route)
            case .failure(let failure)?:
                failureView(failure)
            case nil:
                ContentUnavailableView("Map not available", systemImage: "map")
            }
        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $guidance) { guidance in
            GuidanceView(guidance: guidance)
                .environment(model)
        }
    }

    // MARK: Success

    private func summary(_ route: Route) -> some View {
        List {
            if let map = model.map {
                Section {
                    DemoDataBanner(map: map, compact: true)
                }
            }

            Section("Summary") {
                LabeledContent("From", value: route.start.name)
                LabeledContent("To", value: route.destination.name)
                LabeledContent("Steps to confirm", value: "\(route.legs.count + 1)")
                LabeledContent("Recorded length", value: lengthSummary(route))
                LabeledContent("Uses", value: usesSummary(route))
            }

            if !route.warnings.isEmpty {
                Section("Before you go") {
                    ForEach(route.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.circle")
                    }
                }
            }

            Section {
                Button {
                    guidance = RouteGuidance(route: route)
                } label: {
                    Text("Start guidance")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Step-by-step directions. You confirm each landmark as you reach it.")
            }

            Section("Steps") {
                ForEach(route.legs) { leg in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(leg.index + 1). \(leg.instruction)")
                        Text("Arrive at: \(leg.to.name)")
                            .font(.subheadline.weight(.semibold))
                        Text("\(leg.connection.type.displayName): \(leg.connection.name)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }

            if let map = model.map {
                Section {
                    RouteSchematicView(map: map, route: route)
                } header: {
                    Text("Schematic (not to scale)")
                } footer: {
                    Text("A simplified drawing. The steps above contain all the route information.")
                }
            }
        }
    }

    private func lengthSummary(_ route: Route) -> String {
        var text = DistanceText.meters(route.recordedLengthMeters)
        if route.usesSimulatedData { text += " (simulated)" }
        if route.legsWithUnknownLength > 0 {
            text += ", plus \(route.legsWithUnknownLength) without a recorded length"
        }
        return text
    }

    private func usesSummary(_ route: Route) -> String {
        let counts = route.connectionTypeCounts
        return ConnectionType.allCases
            .compactMap { type in counts[type].map { "\($0) \(type.displayName.lowercased())" } }
            .joined(separator: ", ")
    }

    // MARK: Failure

    @ViewBuilder
    private func failureView(_ failure: RouteFailure) -> some View {
        switch failure {
        case .noSuitableRoute(let diagnosis):
            List {
                if let map = model.map {
                    Section {
                        DemoDataBanner(map: map, compact: true)
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No route found", systemImage: "xmark.octagon")
                            .font(.title3.weight(.semibold))
                        Text(diagnosis.explanation)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
                Section("What you can do") {
                    Text("Choose a different destination, or ask building staff for another way in.")
                }
            }
        case .sameStartAndDestination:
            ContentUnavailableView("You're already there", systemImage: "mappin",
                                   description: Text("The starting point and destination are the same."))
        case .unknownLandmark(let id):
            ContentUnavailableView("Unknown place", systemImage: "questionmark",
                                   description: Text("'\(id)' is not in this map."))
        }
    }
}

extension RouteGuidance: Identifiable {
    var id: String { "\(route.start.id)->\(route.destination.id)" }
}
