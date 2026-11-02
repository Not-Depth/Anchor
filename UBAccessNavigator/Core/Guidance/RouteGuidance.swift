import Foundation

/// One screen's worth of guidance.
struct GuidanceStep: Equatable {
    enum Kind: Equatable {
        /// The person confirms they are at the starting landmark.
        case confirmStart
        /// The person travels one leg, then confirms arrival at the next landmark.
        case travel(legIndex: Int)
        /// The destination has been confirmed.
        case arrived
    }

    var kind: Kind
    /// e.g. "Step 2 of 7"
    var progressLabel: String
    /// What to do now. Comes straight from the map's authored text.
    var instruction: String
    /// Non-visual cue for confirming arrival, if the map provides one.
    var arrivalCue: String?
    /// Label for the button that confirms this step, e.g. "I've reached Elevator lobby".
    /// `nil` on the final step.
    var confirmLabel: String?
    /// Facts about the connection: type, recorded length, step-free status, availability.
    var details: [String]

    /// Text for speech output. Built only from the fields above, so nothing is spoken
    /// that isn't also on screen.
    var spokenText: String {
        var parts = [instruction]
        if let cue = arrivalCue {
            parts.append("Arrival cue: \(cue)")
        }
        return parts.joined(separator: " ")
    }
}

/// Step-by-step guidance along a route.
///
/// The app does not know where the person is indoors. It only moves forward when the
/// person confirms they have reached the next landmark, and they can always go back.
struct RouteGuidance: Equatable {
    let route: Route
    let steps: [GuidanceStep]
    private(set) var currentIndex: Int = 0

    init(route: Route) {
        self.route = route
        self.steps = Self.makeSteps(for: route)
    }

    var current: GuidanceStep { steps[currentIndex] }
    var previous: GuidanceStep? { currentIndex > 0 ? steps[currentIndex - 1] : nil }
    var next: GuidanceStep? { currentIndex + 1 < steps.count ? steps[currentIndex + 1] : nil }

    var canGoBack: Bool { currentIndex > 0 }
    var isFinished: Bool { current.kind == .arrived }

    /// The person confirms the current step (they are at the start, or reached the next landmark).
    mutating func confirmCurrentStep() {
        guard currentIndex + 1 < steps.count else { return }
        currentIndex += 1
    }

    /// Go back one step, e.g. if the person confirmed too early.
    mutating func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
    }

    // MARK: - Building steps

    private static func makeSteps(for route: Route) -> [GuidanceStep] {
        // 1 start confirmation + 1 per leg + 1 arrival.
        let total = route.legs.count + 2
        var steps: [GuidanceStep] = []

        steps.append(GuidanceStep(
            kind: .confirmStart,
            progressLabel: "Step 1 of \(total)",
            instruction: "Start at \(route.start.name).",
            arrivalCue: route.start.arrivalCue,
            confirmLabel: "I'm at \(route.start.name)",
            details: []
        ))

        for leg in route.legs {
            steps.append(GuidanceStep(
                kind: .travel(legIndex: leg.index),
                progressLabel: "Step \(leg.index + 2) of \(total)",
                instruction: leg.instruction,
                arrivalCue: leg.to.arrivalCue,
                confirmLabel: "I've reached \(leg.to.name)",
                details: details(for: leg, simulated: route.usesSimulatedData)
            ))
        }

        steps.append(GuidanceStep(
            kind: .arrived,
            progressLabel: "Step \(total) of \(total)",
            instruction: "You have arrived at \(route.destination.name).",
            arrivalCue: nil,
            confirmLabel: nil,
            details: []
        ))
        return steps
    }

    private static func details(for leg: RouteLeg, simulated: Bool) -> [String] {
        let c = leg.connection
        var lines = ["\(c.type.displayName): \(c.name)"]
        if let length = c.lengthMeters {
            lines.append("Recorded length: \(DistanceText.meters(length))" + (simulated ? " (simulated)" : ""))
        } else {
            lines.append("Length not recorded")
        }
        lines.append(c.stepFree.displayName)
        lines.append(c.availability.displayName)
        return lines
    }
}
