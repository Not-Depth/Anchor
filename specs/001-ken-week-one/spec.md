# Earlier Nearby warnings and a wheelchair route draft

Ken owns the native warning. Ken and Johnny share the map draft. Target for the team's weekly review is Sunday, November 8, 2026. This slice starts from main at `bd8fff53`. Ken confirmed the 3 m new-install default and the fictional Demo Hall draft on November 7. The iPhone trial will follow the team meeting.

## User stories and acceptance

**US1. Hear about a surface in time to stop.** A person moving toward a stationary obstacle needs the first useful cue while there is still room to respond. Ken reports a late warning in a previous walking trial. That observation does not identify the source of the delay.

- N1. At a user's configured threshold, the first fresh, reliable reading at or inside it should be evaluated as soon as the app receives it. Preserve the rule for rearming and the interval between reminders during the same approach.
- N2. After sustained loss of reliable depth, a recovered near reading must produce the proximity event first. A recovered far reading should still signal recovery. Stale or insufficient readings must never supply an obstacle distance.
- N3. Preserve independent sound and vibration choices and VoiceOver delivery. Produce no new proximity event from a reading delivered outside a running session. Confirm audible performance on a physical iPhone. For each trial record the first audible cue and the remaining clearance at full stop, using the leading edge of the person or chair.
- N4. The build provides a 3.0 m selection alongside the existing distances. It speaks “Warning, objects ahead at [measured distance] meters.” using one decimal place and the existing speech service. Audio and haptic preferences remain independent. Existing saved distances load as before and a new installation starts at 3.0 m. Acceptance on the intended device follows the team meeting.

**US2. Review a step-free route together.** Ken and Johnny need an understandable rough draft they can check against the data, and a way to identify what they still need to survey.

- M1. Provide a preliminary two-floor example with labeled start, finish, ramp, elevator and usable text directions. Trace every segment to the fictional Demo Hall dataset.
- M2. Identify simulated lengths, an unrecorded elevator length, and the outcome if the elevator is unavailable. Clearly label the draft fictional and schematic, with no scale or claim about physical dimensions in Davis Hall.
- M3. The weekly deliverable is a one-page fictional Demo Hall draft from North Plaza to Room 201 via the ramp and Elevator A, provided as an offline HTML source and a printable PDF for Johnny's review. A real site would be a separate survey-backed scope.

## Clarifications as of November 5

Ken previously confirmed the late cue and that the threshold and route were still undecided. The current team document names both tasks, with no new numeric threshold or selected map route. Asked Ken for (1) trial threshold, dynamic wording and any action word, and (2) Johnny's site, endpoints and handoff format. A 3 m candidate can be compared against the existing 2 m option in a supervised trial. It carries no claim about safe stopping distance.

## Decisions on November 7

Ken selected “Default 3 m for new installations, preserve saved choices” in response to the proposed warning “Warning, objects ahead at [measurement] meters”. Ken also selected “Finish the Demo Hall draft” and deferred Xcode/iPhone testing until after the team meeting. Use the supplied warning template, with “m” spoken as “meters” and actual readings to one decimal place. The weekly implementation and draft are ready for review when the checks below pass. Physical safety acceptance requires measured cue timing and stopping clearance on the intended phone. A stop or reverse instruction would require a separate team decision.
