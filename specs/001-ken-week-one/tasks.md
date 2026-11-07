# Tasks and evidence

- [x] T1 · N1–N3. Evaluate incoming native depth promptly and prioritize a recovered close surface. Swift Core passed 42/42 on November 5. The recovery test reproduced the old policy's delay. Native device verification remains in T2b.
- [x] T2a · N3–N4. Prepare the [iPhone trial sheet](iphone-trial.md) with selectable 2 m and 3 m settings, observable setup checks and independent clearance measurements.
- [ ] T2b · N3–N4. Ken and Bach collect audible timing, misses, nuisance cues and full-stop clearance with a physical LiDAR iPhone and both speech paths.
- [x] T3 · M1–M2. Draw a [fictional two-floor reference](wheelchair-blueprint.html), trace it to the planner, verify the lift-outage scenario and review the rendered sheet.
- [x] T4 · N4. Implement Ken's November 7 selection of a 3 m new-install default, preserve saved values, and speak the requested warning with the measured distance. Final code passed 43 Core tests and the isolated settings-persistence checks.
- [x] T5a · M3. Deliver the offline Demo Hall HTML and one-page PDF in Ken's selected scope, with handoff instructions.
- [ ] T5b · M3. Johnny reviews the route order, elevator transition and clarity of the draft. Record any revisions before team acceptance.

## Analysis before implementation

On November 5, N1–N3 and M1–M2 had independent deliverables. All seven requirements had a task. T4 and T5 depended on team decisions. A Swift policy test could establish when an event is emitted, while confirmation that a person heard it early enough required T2. Ken subsequently resolved the threshold and map scope on November 7.

## Convergence review · November 5

- M1–M2: the HTML matches all eight landmarks, seven connections and their recorded lengths in the planner result. The outage case rejects the route when Elevator A is unavailable. The existing web Core suite passed 31/31. The sheet was inspected at mobile widths and as a single printed US Letter page.
- N4 and M3: the latest team sources still leave the numeric default, final spoken prompt, target site and map handoff format open. The checklist remains available for partner review. Once these decisions arrive, update the spec, carry out T4/T5 and repeat the relevant checks.

## Convergence review · November 7

Ken confirmed the 3 m default for new installations, preservation of saved choices, completion of the Demo Hall draft, and device testing after the meeting. The spec, plan, trial sheet, code and handoff reflect these decisions.

- N1–N4: all 43 Core tests passed on the final Swift source snapshot. The actual AppSettings source compiled in an isolated harness and preserved saved 0.75/1/2/3 m choices and every Boolean setting across recreation. New settings start at 3 m. Five changed Swift files passed syntax parsing for iOS 17 device and simulator targets.
- M1–M3: the approved fictional scope is delivered in HTML and PDF. Johnny's review remains T5b.
- Remaining high-priority acceptance evidence is T2b. Apple SDK compilation and audible/stopping-clearance results are outstanding. The full request reaches team acceptance after those results and Johnny's review. The local Core checks do not establish physical timing.
