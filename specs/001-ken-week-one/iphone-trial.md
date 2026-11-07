# Earlier Nearby cue · iPhone trial sheet

Ken and Bach · Blank worksheet for a supervised indoor comparison. A physical run is needed to decide whether the cue arrives early enough. This trial branch uses “Warning, objects ahead at … meters.”

For a 1.4 m reading, the trial phrase is “Warning, objects ahead at 1.4 meters.” Record the words actually heard and ask the team to approve the final wording and default distance after comparison.

## Set up

1. Record the iPhone model, iOS version, build or commit, audio output and VoiceOver state. Use the same phone position, audio volume and output for the runs being compared.
2. Start stationary. Aim the back camera at a broad, matte, soft target. Use a clear, level lane, the person's usual mobility aid, floor marks and a sighted spotter. Agree on a stop line in front of the target before any approach. The spotter ends the run at that line even if no alert was heard. An interrupted or missed trial is a result to record.
3. Clear any previous Xcode launch override for `settings.nearbyAlertDistance`. On this build turn on Settings → Nearby alerts → Audio alerts and choose 2 m. Verify the Nearby summary displays 2 m with audio on. Tap **Start depth sensing**. If it reports no reliable reading, record that condition before attempting a moving trial.
4. On the same build, choose **3 m** in Settings → Nearby alerts → Alert distance and verify the Nearby summary displays 3 m. Repeat the same setup. Relaunch once and check that the selection persists. If the summary shows another value, record “setup failed” and stop that comparison. New installs start with alerts off and a 3 m setting. Upgrading preserves existing saved choices, so select the test settings explicitly.

## Compare

First check that a stationary near target produces the expected speech and that a covered sensor does not announce a made-up distance. Uncover onto a close target after a sustained loss and record which phrase is heard first. On the changed build the near cue takes priority; uncovering onto a far target should announce recovery instead.

Then repeat the same marked approach at a comfortable, measured speed for each selected setting, including VoiceOver off and on. A second observer or external audio/video with floor marks can identify the first audible syllable. Record a missed cue explicitly. Include a pass beside a doorway or wall to check whether a farther threshold produces unwanted cues. Test powered chairs separately at the intended indoor speed if they enter the agreed scope.

| Build / trial | Threshold and VoiceOver | Approach / speed | Threshold crossing to first audible cue (s) | Actual clearance at first cue (m) | Clearance at full stop (m) | Heard words, missed or nuisance cue |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |
| | | | | | | |

Use the phone's position to mark when it crossed the known threshold. For both clearance columns use the foremost part of the person or chair, including footrests. Distances in this sheet come from floor marks, independently of what the app announces.

Record the remaining clearance and any late, missed or nuisance cues for each setting before choosing the release behavior. Comparing 2 m versus 3 m on this branch holds the wording and build constant. Comparing main against this branch changes both timing logic and phrase, so treat that result as an overall comparison rather than a measurement of the code's timing improvement alone.
