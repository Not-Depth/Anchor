import SwiftUI

/// Shown once at first launch, before iOS asks for Motion & Fitness access, so the
/// system prompt isn't a surprise and the person knows exactly what it's for.
///
/// "Continue" leads straight to the iOS prompt, where the real choice is made. Apple's
/// guidelines ask that a screen like this never imitates the system's Allow button.
struct FloorIntroView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "figure.stairs")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Know when you change floors")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("Anchor can use your iPhone’s barometer to notice when you go up or down a floor on stairs or in an elevator, and tell you if it doesn’t match your route.")
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 16) {
                    point("barometer", "It measures air pressure only. It doesn’t know where you are.")
                    point("lock.iphone", "Nothing leaves your iPhone.")
                    point("hand.tap", "You still confirm every landmark yourself.")
                    point("gearshape", "You can turn it off anytime in Settings.")
                }

                Text("Next, iOS will ask whether Anchor can use Motion & Fitness.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: continueToPrompt) {
                    Text("Continue")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Shows the iOS permission prompt.")

                Button(action: notNow) {
                    Text("Not now")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityHint("Skips floor checks. You can turn them on later in Settings.")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)
        }
        // A swipe down would leave the question unanswered; the buttons make it explicit.
        .interactiveDismissDisabled()
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
    }

    private func continueToPrompt() {
        model.settings.hasSeenFloorIntro = true
        model.settings.floorDetection = true
        dismiss()
        model.floorTracker.requestAccess()
    }

    private func notNow() {
        model.settings.hasSeenFloorIntro = true
        model.settings.floorDetection = false
        dismiss()
    }
}
