# Anchor Web

A browser version of UB Access Navigator for teammates on Windows, macOS, and Linux. It runs locally without Xcode, Docker, an account, API keys, or a backend. The application itself has **no third-party runtime dependencies**.

The map is **fictional demo data**, not Davis Hall or any real building. Do not use it for real navigation. Nearby is a **manual simulation**, not a camera or obstacle detector.

## What is shared and what needs two updates

**Changing Swift does not automatically change this web app.** This is a separate JavaScript implementation, not an iPhone emulator, SwiftUI renderer, or automatic test of the native app.

| Change                                                                                                   | Appears in both versions automatically? | Required work                                                                                      |
| -------------------------------------------------------------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Landmarks, connections, authored directions, or distances in `UBAccessNavigator/Resources/demo_map.json` | Both versions read the same source file | Refresh the local web page; rebuild static web exports and the native app to include updated data. |
| SwiftUI screens, layout, labels, or navigation                                                           | No                                      | Update the corresponding HTML/CSS/JavaScript if the web counterpart should match.                  |
| Swift routing, guidance, or alert logic                                                                  | No                                      | Port the behavior and update tests in both implementations.                                        |
| ARKit, camera, native speech, haptics, or VoiceOver integration                                          | No                                      | Test the actual native app on supported Apple hardware. Browser simulation cannot validate these.  |

The browser companion is useful for reviewing shared map content, demonstrating navigation flows without a Mac, and collecting interface feedback. It does **not** prove that a Swift change works. Keeping two implementations adds maintenance work, and is worthwhile only if the team wants the browser demo as a separate deliverable.

If the team's goal is for everyone to work on **the same Swift app**, Windows teammates can edit and push Swift files while a teammate or a remotely accessible Mac builds and runs them in Xcode. That avoids maintaining a second UI. A single application codebase that runs locally across native iOS and the web would require a different cross-platform architecture, not this companion or a Docker wrapper.

## How the interface follows the iPhone app

The web interface follows the source screens in `UBAccessNavigator/Features/`: a narrow single-column layout, system fonts, grouped forms, large navigation titles, blue buttons, switches, bottom tabs, and light/dark colors.

| Native screen           | Browser counterpart                                                                                                                                |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RoutesView.swift`      | Empty initial selections, floor-grouped place picker screens, step-free toggle, disabled Find route until different places are chosen.             |
| `RouteResultView.swift` | Separate Route screen with Summary, Before you go, Start guidance, Steps, and numbered schematic sections.                                         |
| `GuidanceView.swift`    | Full-screen guidance with hidden tab bar, arrival cue, Next/Previous previews, Repeat and Pause/Resume speech, Finish, and End route confirmation. |
| `SettingsView.swift`    | Matching section order, setting labels, Test voice, and Map data.                                                                                  |
| `NearbyView.swift`      | Unsupported-device message by default. Optional synthetic readings are behind Try simulated readings.                                              |

This is a source-based visual adaptation. It has not been compared to a running iPhone build on this Windows environment, and exact system fonts and controls vary by operating system. Browser speech stays off by default because browser APIs cannot detect screen-reader use; the native app can handle VoiceOver directly.

## Run on your laptop

Install **Node.js 22 or later** (an LTS release is recommended), then reopen your terminal. From the folder where you keep projects:

```powershell
git clone https://github.com/Not-Depth/Anchor.git
cd Anchor/web
npm start
```

Open **http://127.0.0.1:5173** in Edge, Chrome, Firefox, or Safari. Stop the server with **Ctrl+C**. These commands work in Windows PowerShell, Command Prompt, and macOS/Linux terminals. `npm install` is not needed just to run the app.

If you already cloned Anchor, save your own changes before switching branches:

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
cd web
npm start
```

If you downloaded a ZIP, choose the `main` branch on GitHub before downloading. Extract it, open a terminal in its `web` folder, and run `npm start`. Keep the surrounding repository folders: the server reads the native project's map.

If PowerShell blocks `npm.ps1`, use **`npm.cmd start`**. If port 5173 is occupied, use another port in PowerShell:

```powershell
$env:PORT = "5174"
npm.cmd start
```

Then open http://127.0.0.1:5174. The server binds only to your own laptop. Double-clicking `index.html` is not supported because browsers restrict JavaScript modules and JSON loading through `file://`.

## What you can test

| Feature              | Web behavior                                                                                        |
| -------------------- | --------------------------------------------------------------------------------------------------- |
| Routes               | Dijkstra routing, one-way connections, authored forward/reverse directions                          |
| Step-free preference | Excludes stairs and all connections not explicitly confirmed step-free                              |
| Elevator outage      | Blocks elevator connections; explains why a route fails instead of falling back to stairs           |
| Unknown availability | Allowed with an explicit warning; unknown step-free suitability is excluded in step-free mode       |
| Guidance             | Confirm the starting point and each landmark; go back, repeat speech, or end guidance               |
| Map                  | Decorative floor schematic; every connection and floor change is described in route text            |
| Settings             | Independent preferences stored in this browser, with a session-only fallback if storage is denied   |
| Spoken directions    | Optional browser speech; off by default to avoid speaking over screen readers                       |
| Nearby               | Slider-controlled readings, lost-reading simulation, threshold/hysteresis, optional audio/vibration |

The app never requests a camera or location permission. Browser vibration is usually unavailable on laptops; the UI reports support. Browser speech depends on the operating system and installed voices; some voices may use an online service. All essential instructions remain visible as text.

The simulation stops when you leave Nearby, collapse its controls, or hide the browser tab. It requires an explicit restart. Changing routing preferences recalculates an existing summary, and choosing different locations clears the old route. The bottom tabs are hidden during guidance; End route asks for confirmation before returning to the summary.

## Demo scenarios

1. North Plaza -> Room 201, step-free **off**: front steps and Stairwell A; 6 connections.
2. Same route, step-free **on**: west ramp and Elevator A; 7 connections, 87 m of recorded simulated length, plus 1 connection whose length is unrecorded.
3. Enable **Settings -> Simulate elevator outage**, with step-free on: no suitable route; Elevator A is identified as unavailable.
4. North Plaza -> Annex reading room, step-free on: no route; skybridge suitability is unknown. With step-free off, the route includes warnings.
5. Room 105 -> North Plaza uses the exit-only door; the reverse trip does not.
6. Nearby -> Try simulated readings -> Start simulation: move below 1 m, enable lost readings, then restore them. Enable optional audio in Settings. These are synthetic readings, not measurements.

## Project structure

```text
web/
  index.html                 Semantic page structure and labeled controls
  styles.css                 Responsive layout, focus states, reduced-motion support
  favicon.svg                Local vector icon
  src/
    app.js                   UI state, browser capabilities, and event handlers
    views.js                 Summary and guidance templates matching native sections
    ui.js                    Escaped view helpers and floor schematic
    core/
      map.js                 Validation and immutable availability overrides
      routing.js             Routing and failure diagnosis
      guidance.js            Authored steps and bounded progress
      settings.js            Validated preferences and storage fallback
      proximity.js           Synthetic-reading alert policy
  scripts/
    server.mjs               Loopback-only local server
    build.mjs                Static export and shared-map validation
  tests/
    core.test.mjs            Routing, map, guidance, settings, and alert scenarios
    server.test.mjs          Source/static serving and path restrictions
    browser/app.spec.js      Browser workflows, reflow, focus, and accessibility
  playwright.config.js
  package.json
  package-lock.json
```

## Shared data and native parity

`../UBAccessNavigator/Resources/demo_map.json` is the single editable map. The development server serves it at `/data/demo_map.json`; the build copies it into `dist/data/`. Do not edit generated copies in `dist`.

The shared map matches the original archive in repository history. It is reused unchanged; no building data or directions were invented for the web version.

JavaScript core logic is a port, not a direct execution of Swift. Tests reproduce the native project's route examples. Failure diagnosis minimizes the number of blocked rules first, then route cost, avoiding a fixed penalty that could be exceeded by an unusually long route. Diagnostic paths are never offered for travel. Routing costs are not displayed as distances.

Swift source and Xcode configuration are outside the web build. The web test results do not certify the native iOS build or hardware behavior.

## Test and build

Install development dependencies only when running browser tests:

```powershell
npm ci
npm test
npm run test:browser
```

On Windows, browser tests use the installed Microsoft Edge. On macOS/Linux, first run `npx playwright install chromium` (Linux may also need `npx playwright install --with-deps chromium`). Unit/server tests require only Node and can run without `npm ci`.

Browser tests cover desktop and narrow layouts in Chromium, including navigation, speech controls, confirmation dialogs, and automated WCAG A/AA checks in light and dark modes. Tests use port 5175 so they can run alongside a development preview on 5173; set `ANCHOR_TEST_PORT` if another test port is needed. These checks complement, and do not replace, manual testing with screen readers and real hardware. Firefox and Safari are not covered by this automated suite.

Create a self-contained static export:

```powershell
npm run build
```

The resulting `web/dist/` can be served by any static HTTP host, including from a subdirectory. For a local check, run `node scripts/server.mjs --built`. Build output, dependencies, screenshots, and test reports are ignored by Git. `.github/workflows/web.yml` runs the web checks on relevant pushes and pull requests.

## Team workflow

Create feature branches from an up-to-date `main`, push to the shared repository, and review through a pull request before merging back into `main`. Everyone runs their own local copy; there is no shared local server or database. A hosted deployment is optional and separate from merging the code.
