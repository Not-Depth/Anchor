# Ken's handoff for the blind-navigation build

The branch builds on the team's `floor-detection` work, which already includes the blind-navigation rebrand and the offline voice implementation. It adds earlier Nearby warnings and a text-first guide for the existing fictional route.

## Johnny's route review

Open the [offline route guide](blind-navigation-guide.html) or [tagged PDF](blind-navigation-guide.pdf). Compare the North Plaza to Room 201 instructions, tactile and audible cues, and confirmation order with the app. After enabling VoiceOver, start the fictional route and check that focus reads the demo status, destination, first instruction and arrival cue. Confirm the steps manually and check Previous, Repeat, and End route. On the stairs, optional floor feedback reports the detected floor change. The next instruction still waits for confirmation.

## Ken and Bach's iPhone trial

From the repository root on a Mac, run both builds.

```sh
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Select a signing team in Xcode and run the app on a LiDAR iPhone. Record the build, iPhone model, iOS version, selected voice, audio output and VoiceOver state. Check a fresh installation starts at 3 m and an upgrade keeps a saved value such as 1 m. Turn on audio alerts in Settings. The browser's simulation can exercise controls and state transitions.

Use a stationary, broad, matte, soft target and a clear indoor lane with an observer and a stopping line before the target. Keep the usual mobility aid. Compare 2 m and 3 m with the phone in the same position and the same volume. Start stationary and verify the warning speaks the measured distance. Try VoiceOver off and on. Cover and uncover the sensor, once onto a close target and once onto a far target. Record which message is heard first.

For moving trials, start before the threshold and end at the marked stopping line even if no cue is heard. Record delay to first audible cue, clearance at the cue, clearance at full stop, and any missed or nuisance warnings. Measure clearance from the leading edge of the person using the floor marks. Compare the same build and voice at each distance.

| Build and voice | VoiceOver | Distance setting | Time to audible cue | Clearance at cue | Clearance at full stop | Heard phrase / missed cue |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

## Recorded voice

The new warning lines are produced by the existing phrase catalog. The team branch does not contain the recorded clips. VoiceOver uses the system VoiceOver voice. With VoiceOver off, missing clips fall back to the iPhone voice. Johnny can regenerate missing lines through the existing tool when the team is ready to record them. Run `swift run anchor-voice-clips --list` from the repository root to inspect the catalog without recording.

## Verification on November 21

- Swift 6.4.2 on Linux passed 64 tests. The clip coverage test was skipped because the recordings are absent. The voice tool's list includes the new warnings. All app Swift files passed syntax parsing for iOS device and simulator.
- A harness using the actual AppSettings source checked the fresh 3 m default and the full set of saved distance choices across relaunches. It also checked saved voice, directions, audio, haptics, floor checks and onboarding.
- The web companion passed 31 core/server tests and 22 browser tests, including accessible step names and focus, keyboard and narrow viewports, Nearby recovery and automated accessibility checks in both color modes.
- The guide was compared with the planner, including closure handling. The physical trial above and Johnny's review are the remaining acceptance checks.
