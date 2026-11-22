import SwiftUI

/// Step-by-step guidance. Moves forward only when the person confirms a landmark.
struct GuidanceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    @State private var guidance: RouteGuidance
    @State private var speechPaused = false
    @State private var confirmingEnd = false
    /// The last floor check result spoken for the current step, so each result is said once.
    @State private var announcedFloorCheck: FloorCheck?
    @AccessibilityFocusState private var instructionFocused: Bool

    init(guidance: RouteGuidance) {
        _guidance = State(initialValue: guidance)
    }

    private var step: GuidanceStep { guidance.current }

    private var instructionAccessibilityLabel: String {
        let instruction = "\(step.progressLabel). \(step.spokenText)"
        return step.kind == .confirmStart ? "\(guidance.introText) \(instruction)" : instruction
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if guidance.route.usesSimulatedData {
                        // Orange is used only for the icon; orange text would fail contrast.
                        Label {
                            Text("Fictional demo route")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    currentStepSection
                    primaryButton
                    secondaryControls
                    previewSection
                }
                .padding()
            }
            .navigationTitle(step.progressLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End route") { confirmingEnd = true }
                }
            }
            .confirmationDialog("End this route?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                Button("End route", role: .destructive) { endRoute() }
                Button("Keep going", role: .cancel) {}
            }
        }
        .sensoryFeedback(.selection, trigger: guidance.currentIndex)
        .sensoryFeedback(.success, trigger: guidance.isFinished) { _, finished in finished }
        .sensoryFeedback(trigger: floorCheck) { _, check in
            switch check {
            case .matches?: .success
            case .wrongDirection?, .wrongCount?: .warning
            default: nil
            }
        }
        .onAppear {
            announceCurrentStep(intro: guidance.introText)
            updateFloorTracking()
        }
        .onChange(of: guidance.currentIndex) {
            announceCurrentStep()
            updateFloorTracking()
        }
        .onChange(of: floorCheck) { _, check in
            announceFloorCheck(check)
        }
        .onDisappear {
            model.speech.stop()
            model.floorTracker.stop()
        }
    }

    // MARK: Floor check

    /// The barometer runs only while a step that changes floor is on screen, measuring
    /// from the moment that step begins.
    private func updateFloorTracking() {
        announcedFloorCheck = nil
        if step.floorChange != nil && model.settings.floorDetection {
            model.floorTracker.startMeasuring()
        } else {
            model.floorTracker.stop()
        }
    }

    /// `nil` when this step stays on one floor or floor checks are off or not allowed.
    private var floorCheck: FloorCheck? {
        guard let expected = step.floorChange,
              model.settings.floorDetection,
              model.floorTracker.access == .allowed else { return nil }
        return FloorCheck(expected: expected, estimate: model.floorTracker.detector.estimate)
    }

    /// Says a floor check result once. It never moves guidance forward: the person still
    /// confirms the landmark.
    private func announceFloorCheck(_ check: FloorCheck?) {
        guard let check, let expected = step.floorChange, check != announcedFloorCheck,
              let text = check.spokenText(expected: expected) else { return }
        announcedFloorCheck = check
        if voiceOverOn {
            AccessibilityNotification.Announcement(text).post()
        } else if !speechPaused {
            model.speakDirection(text)
        }
    }

    @ViewBuilder
    private func floorCheckRow(expected: ExpectedFloorChange) -> some View {
        if let check = floorCheck {
            Label {
                Text(check.displayText(expected: expected))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                // Color is only on the icon; the words carry the meaning.
                switch check {
                case .waiting:
                    Image(systemName: "hourglass")
                case .notYet:
                    Image(systemName: "figure.stairs")
                case .matches:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .wrongDirection, .wrongCount:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .font(.body)
        } else if model.settings.floorDetection, model.floorTracker.isSupported {
            Text("Floor check is off: allow Motion & Fitness for Anchor in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// With VoiceOver on, moving focus to the instruction makes VoiceOver read it, so we
    /// don't also speak it (that would be two voices at once). Without VoiceOver, the
    /// app's voice reads it if spoken directions are on and not paused. The intro and the
    /// step are spoken as separate phrases, matching the recorded clips.
    private func announceCurrentStep(intro: String? = nil) {
        if voiceOverOn {
            instructionFocused = true
        } else if !speechPaused {
            model.speakDirection([intro, step.spokenText].compactMap { $0 })
        }
    }

    // MARK: Sections

    private var currentStepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.instruction)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($instructionFocused)
                .accessibilityAddTraits(.isHeader)
                // One element holds the progress, instruction and cue, so VoiceOver reads
                // the whole step when focus moves here.
                .accessibilityLabel(instructionAccessibilityLabel)

            if let cue = step.arrivalCue {
                Label {
                    Text("Arrival cue: \(cue)")
                } icon: {
                    Image(systemName: "ear")
                }
                .font(.body)
                .accessibilityHidden(true)  // already part of the instruction's label
            }

            if !step.details.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(step.details, id: \.self) { Text($0) }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }

            if let expected = step.floorChange {
                floorCheckRow(expected: expected)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if guidance.isFinished {
                endRoute()
            } else {
                guidance.confirmCurrentStep()
            }
        } label: {
            Text(step.confirmLabel ?? "Finish")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint(guidance.isFinished ? "Closes guidance." : "Moves to the next step.")
    }

    private var secondaryControls: some View {
        // Stacks vertically at large text sizes so labels never truncate.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondaryButtons }
            VStack(spacing: 12) { secondaryButtons }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        Button {
            guidance.goBack()
        } label: {
            Label("Previous step", systemImage: "chevron.backward")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(!guidance.canGoBack)

        if model.settings.spokenDirections {
            Button {
                model.speech.speak(step.spokenText)
            } label: {
                Label("Repeat", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityHint("Speaks the current instruction again.")

            Button {
                speechPaused.toggle()
                if speechPaused {
                    model.speech.stop()
                } else {
                    model.speakDirection(step.spokenText)
                }
            } label: {
                Label(speechPaused ? "Resume speech" : "Pause speech",
                      systemImage: speechPaused ? "speaker.wave.2" : "speaker.slash")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityValue(speechPaused ? "Spoken guidance paused" : "Spoken guidance on")
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = guidance.next {
                preview(title: "Next", step: next)
            }
            if let previous = guidance.previous {
                preview(title: "Previous", step: previous)
            }
            if !model.settings.spokenDirections {
                Text("Spoken directions are off. Turn them on in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func preview(title: String, step: GuidanceStep) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(step.instruction).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) step: \(step.instruction)")
    }

    private func endRoute() {
        model.speech.stop()
        dismiss()
    }
}
