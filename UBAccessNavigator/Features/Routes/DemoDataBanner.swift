import SwiftUI

/// A clearly visible label that the map is fictional. Shown on every route screen.
struct DemoDataBanner: View {
    let map: CampusMap
    var compact = false
    var simulatedOutages: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(map.isFictional ? "Fictional demo data" : statusTitle)
                    .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            if !compact {
                Text(map.disclaimer)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(simulatedOutages, id: \.self) { name in
                Text("Simulated: \(name) is out of service (demo setting).")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
        // Read as one VoiceOver element, so the warning is never skipped piecemeal.
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch map.dataStatus {
        case .fictionalDemo: return "Fictional demo data"
        case .surveyedUnverified: return "Surveyed data, not yet verified"
        case .surveyedVerified: return "Surveyed and verified data"
        }
    }
}
