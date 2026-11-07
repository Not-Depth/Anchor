# Ken's November 8 handoff

The Nearby change evaluates depth readings on arrival and announces a close surface first when reliable depth returns after an outage. New installations use a 3 m default. Upgrading retains saved choices. With audio alerts enabled, the cue includes the actual distance, for example “Warning, objects ahead at 1.4 meters.”

Ken selected the 3 m new-install default and the fictional Demo Hall draft on November 7. Mac/iPhone testing is scheduled for after the team meeting.

## Review the route with Johnny

Open [the one-page PDF](wheelchair-blueprint.pdf) or [the offline HTML](wheelchair-blueprint.html). The route is North Plaza to Room 201 through the west entrance ramp and Elevator A. Check the A–H sequence, the transfer between floors and whether the text directions are understandable. All places and distances belong to the fictional dataset. Elevator outage produces “No suitable route found” in step-free mode.

## Run the iPhone build with Ken and Bach

Use a separate checkout on the Mac so teammates can keep their ongoing work in their existing folders.

```sh
git clone --branch 001-ken-week-one https://github.com/Not-Depth/Anchor.git Anchor-ken-review
cd Anchor-ken-review
swift test
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
open UBAccessNavigator.xcodeproj
```

Choose the signing team and LiDAR-equipped iPhone in Xcode, then run the app. Start with Settings → Nearby alerts → Audio alerts on. Confirm the selected distance in Nearby and follow the [device trial](iphone-trial.md), including VoiceOver off and on, signal loss and recovery, and a comparison of 2 m and 3 m. Record existing settings before updating a previously installed build and verify they persist afterward.

## Evidence and remaining review

- Swift 6.4.2 on Linux passed all 43 Core tests on November 7. The recovery regression failed against the original policy and passed after the change.
- An isolated harness compiled the actual AppSettings source and verified a fresh 3 m default, all six distance options, persisted distances and both states of the Boolean settings.
- Changed Swift files passed syntax parsing for iOS device and simulator targets. Xcode builds and the physical trial still need the Mac/iPhone.
- The blueprint follows the existing route planner's eight landmarks, seven legs, 87 m of recorded simulated lengths and unrecorded elevator length. The existing web Core suite passed 31 tests. The final sheet is inspected for mobile display and one-page printing.

Before team acceptance, attach the Xcode build results, the device model/iOS and trial observations. Johnny should review the draft's route and readability. Use the [spec](spec.md), [requirements checklist](checklists/requirements.md) and [tasks](tasks.md) to record review outcomes.
