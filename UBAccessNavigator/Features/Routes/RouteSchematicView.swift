import SwiftUI

/// A simple per-floor drawing of the route, using the optional `schematic` positions in
/// the map file. It is a visual aid only: VoiceOver gets a one-line summary, because the
/// text steps already describe the full route.
struct RouteSchematicView: View {
    let map: CampusMap
    let route: Route

    private var routeLandmarkIDs: [String] { route.landmarksInOrder.map(\.id) }
    private var routeConnectionIDs: Set<String> { Set(route.legs.map(\.connection.id)) }

    /// Only the floors the route actually visits, in travel order.
    private var floorsOnRoute: [Floor] {
        var seen: Set<String> = []
        return route.landmarksInOrder
            .compactMap { map.floor(withID: $0.floorID) }
            .filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(floorsOnRoute) { floor in
                VStack(alignment: .leading, spacing: 4) {
                    Text(floor.name).font(.subheadline.weight(.semibold))
                    canvas(for: floor)
                        .frame(height: 220)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Schematic of \(floor.name)")
                .accessibilityValue(summary(for: floor))
            }
            legend
        }
        .padding(.vertical, 4)
    }

    private func summary(for floor: Floor) -> String {
        let names = route.landmarksInOrder.filter { $0.floorID == floor.id }.map(\.name)
        return "Route passes " + names.joined(separator: ", then ")
    }

    private func canvas(for floor: Floor) -> some View {
        Canvas { context, size in
            func point(_ landmark: Landmark) -> CGPoint? {
                guard let p = landmark.schematic else { return nil }
                let inset: CGFloat = 24
                return CGPoint(x: inset + p.x * (size.width - 2 * inset),
                               y: inset + p.y * (size.height - 2 * inset))
            }

            let onFloor = map.landmarks.filter { $0.floorID == floor.id }

            // Connections on this floor: thin gray for the map, thick dashed accent for the route.
            for connection in map.connections {
                guard let a = map.landmark(withID: connection.from), let b = map.landmark(withID: connection.to),
                      a.floorID == floor.id, b.floorID == floor.id,
                      let pa = point(a), let pb = point(b) else { continue }
                var line = Path()
                line.move(to: pa)
                line.addLine(to: pb)
                if routeConnectionIDs.contains(connection.id) {
                    context.stroke(line, with: .color(.accentColor), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [10, 6]))
                } else {
                    context.stroke(line, with: .color(.secondary.opacity(0.5)), lineWidth: 1.5)
                }
            }

            // Landmarks: route stops are larger and numbered by travel order.
            for landmark in onFloor {
                guard let p = point(landmark) else { continue }
                let order = routeLandmarkIDs.firstIndex(of: landmark.id)
                let radius: CGFloat = order == nil ? 4 : 11
                let dot = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(order == nil ? .secondary : .accentColor))
                if let order {
                    context.draw(Text("\(order + 1)").font(.caption2.bold()).foregroundStyle(.white), at: p)
                }
            }
        }
    }

    private var legend: some View {
        Text("Numbered circles are the route's landmarks in order. Dashed line: route. Thin line: other connections. Floor changes are not drawn.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
