import SwiftUI

/// Step-by-step guidance. Moves forward only when the person confirms a landmark.
struct GuidanceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    @State private var guidance: RouteGuidance
    @State private var speechPaused = false
    @State private var confirmingEnd = false
    @AccessibilityFocusState private var instructionFocused: Bool

    init(guidance: RouteGuidance) {
        _guidance = State(initialValue: guidance)
    }

    private var step: GuidanceStep { guidance.current }

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
        .onAppear {
            let label = guidance.route.usesSimulatedData ? "Fictional demo route" : "Route"
            announceCurrentStep(prefix: "\(label) to \(guidance.route.destination.name). ")
        }
        .onChange(of: guidance.currentIndex) {
            announceCurrentStep()
        }
        .onDisappear { model.speech.stop() }
    }

    /// With VoiceOver on, moving focus to the instruction makes VoiceOver read it, so we
    /// don't also speak it (that would be two voices at once). Without VoiceOver, the
    /// speech synthesizer reads it if spoken directions are on and not paused.
    private func announceCurrentStep(prefix: String = "") {
        if voiceOverOn {
            instructionFocused = true
        } else if !speechPaused {
            model.speakDirection(prefix + step.spokenText)
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
                .accessibilityLabel("\(step.progressLabel). \(step.spokenText)")

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
