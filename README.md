# UB Access Navigator — Milestone 1

## Web version for Windows, macOS, and Linux

The `web/` folder contains a browser version of Routes, landmark guidance, Settings, and a clearly labeled Nearby simulation. Install **Node.js 22 or later**, then run these commands from the repository root:

```sh
cd web
npm start
```

Open **http://127.0.0.1:5173**. No Xcode, Docker, account, API key, or dependency installation is required to run the web app. Real LiDAR remains a native iPhone feature.

See **[web/README.md](web/README.md)** for Windows troubleshooting, team setup, feature differences, test commands, and static hosting instructions. The web app uses the same fictional demo map as the native project.

**This is a separately maintained browser companion, not a live SwiftUI preview.** Editing Swift screens or routing logic does not update the web app. Only the map JSON is shared. Its interface follows the native screen structure, but the browser executes JavaScript; native app testing still requires Xcode on a Mac. See [what is shared and what needs two updates](web/README.md#what-is-shared-and-what-needs-two-updates).

---

## Native iPhone version

A native iPhone app (Swift, SwiftUI) with three tabs:

- **Routes**: pick a starting point and destination. Review the route, then follow landmark-based steps that you confirm one at a time.
- **Nearby** (experimental): a real ARKit LiDAR depth reading of the surface in the center of the camera view, with optional audio and haptic alerts.
- **Settings**: independent switches for step-free routes, spoken directions, and nearby audio/haptic alerts. These are saved on the device.

> **The map is fictional demo data** ("Demo Hall (fictional)"). It does not describe Davis Hall or any real building. Every route screen says so.

---

## 1. What has and hasn't been verified

| Part | Status |
|---|---|
| `Core/` (map model, validation, Dijkstra, guidance, depth math, alert logic) | Compiled with Swift 6.0.3 on Linux. **40 unit tests pass** (`swift test`). |
| `demo_map.json` | Loads and passes all validation rules (checked by the tests). |
| `UBAccessNavigator.xcodeproj` | Written by hand in Xcode 16's project format. Parsed and every internal reference checked, but **not yet opened in Xcode**. |
| SwiftUI / ARKit / speech code | **Not compiled yet.** It needs Xcode on a Mac. The first build on your Mac is the real check. |

If the first build shows errors, paste them back and they can be fixed quickly.

---

## 2. Setup on your M1 MacBook Air

### Requirements
- **Xcode 16 or later.** Xcode 26 is recommended. The project uses Xcode 16's "synchronized folders," so new files in `UBAccessNavigator/` are picked up automatically.
- **iPhone with LiDAR** running **iOS 17 or later**: iPhone 12 Pro / Pro Max or any later Pro model.
- An Apple ID. A free account can install to your own iPhone; the app then expires after 7 days and you re-run it from Xcode.

### Step 1. Check your tools
```bash
xcodebuild -version                       # expect Xcode 16.x or 26.x
swift --version
xcrun --sdk iphoneos --show-sdk-version   # iOS SDK version
```

### Step 2. Run the Core tests (no simulator needed)
```bash
cd UBAccessNavigator
swift test
```
Expected result: `Executed 40 tests, with 0 failures`.

### Step 3. Compile-check both code paths from Terminal
The ARKit files are compiled **only for real devices**, so a simulator build alone doesn't check them. Run both commands:
```bash
# Simulator build (Routes, Settings, Nearby's "unsupported" path)
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS Simulator' build

# Device build without signing (also compiles the ARKit/LiDAR code)
xcodebuild -project UBAccessNavigator.xcodeproj -scheme UBAccessNavigator \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

### Step 4. Run in the Simulator
1. `open UBAccessNavigator.xcodeproj`
2. Choose any iPhone simulator, then press **⌘R**.
3. Routes and Settings work fully. Nearby says it isn't available in the Simulator, which is expected.

### Step 5. Run on your iPhone
1. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode**, then restart when asked.
2. Connect the iPhone and trust the Mac.
3. In Xcode, select the **UBAccessNavigator** target → **Signing & Capabilities** → **Team**: your Apple ID (Personal Team).
4. If Xcode says the bundle ID is unavailable, change it to something unique, such as `edu.buffalo.<yourUBITname>.UBAccessNavigator`.
5. Select your iPhone as the run destination, then press **⌘R**.
6. If iOS blocks the app on first launch, go to **Settings → General → VPN & Device Management** and trust your developer certificate.

### Fallback if Xcode won't open the project file
1. In Xcode, choose **File → New → Project → iOS App**. Name it `UBAccessNavigator`, with Interface **SwiftUI** and Language **Swift**.
2. Delete the generated `ContentView.swift` and `UBAccessNavigatorApp.swift`.
3. Drag this repo's `UBAccessNavigator/` folder contents (App, Core, Features, Services, Resources, Assets.xcassets) into the project.
4. Set **Minimum Deployments** to iOS 17.0.
5. In the target's **Info** tab, add **Privacy - Camera Usage Description** with the text: "The Nearby tab uses the camera and LiDAR scanner to estimate how far away surfaces are."

---

## 3. Deployment target: iOS 17.0

iOS 17 provides SwiftUI's `@Observable` and `@Bindable`, `sensoryFeedback`, `ContentUnavailableView`, and the two-parameter `onChange`. These keep the code shorter and easier to follow. Every LiDAR iPhone can run iOS 17 or later, so nothing is lost.

The camera preview uses RealityKit's `ARView` rather than `ARSCNView`. Apple marks SceneKit, and with it `ARSCNView`, deprecated as of iOS 26.

---

## 4. How the code is organized

```
UBAccessNavigator/
├─ Package.swift              ← lets `swift test` build Core/ on its own
├─ Tests/NavigatorCoreTests/  ← 40 unit tests for Core/
├─ UBAccessNavigator.xcodeproj
└─ UBAccessNavigator/         ← everything in here is compiled into the app
   ├─ Core/        Foundation only. No UI, no ARKit. Unit-tested.
   │  ├─ Map/        CampusMap model, MapValidator, JSON loading
   │  ├─ Routing/    RoutePlanner (Dijkstra) + Route + NoRouteDiagnosis
   │  ├─ Guidance/   RouteGuidance: step-by-step state machine
   │  └─ Depth/      DepthAnalyzer (pure math) + ProximityAlertPolicy
   ├─ Services/    AppSettings (UserDefaults), SpeechService, HapticsService
   ├─ Features/
   │  ├─ Routes/     RoutesView → RouteResultView → GuidanceView, schematic
   │  ├─ Nearby/     NearbyView, NearbyViewModel, ARKit session + camera view
   │  └─ Settings/   SettingsView
   ├─ App/         App entry point, AppModel (shared state)
   └─ Resources/   demo_map.json
```

Data flow for a route:

```
demo_map.json ─► CampusMap.load ─► MapValidator ─┐
                                                 ▼
 Settings (step-free?) ─────────────────► RoutePlanner (Dijkstra)
                                                 │
                       ┌─────────────────────────┴───────────────┐
                    Route                              NoRouteDiagnosis
                       │                                         │
              RouteResultView (summary)              "No suitable route found"
                       │                              + what blocks it
              RouteGuidance (you confirm each step)
                       │
         GuidanceView ─► SpeechService (or VoiceOver)
```

Data flow for Nearby:

```
ARView (camera) ─► ARSession ─► DepthFrameDelegate (background queue, ≤10 Hz)
                                  │  copies the center 30% of the depth + confidence maps
                                  ▼
                              DepthAnalyzer ─► DepthReading
                                  ▼
                 NearbyViewModel (main actor, ticks every 0.2 s)
                   ├─ hides readings older than 0.6 s
                   └─ ProximityAlertPolicy ─► haptics / speech (if enabled)
```

---

## 5. Routing rules

- **Dijkstra** runs on a directed graph. Each bidirectional connection becomes two edges; a `one_way` connection becomes one.
- **Unavailable connections are always excluded.**
- **Step-free mode excludes**, rather than penalizes, anything that isn't `stepFree: "confirmed"`. Stairs are excluded even if the data wrongly marks them confirmed, and the validator rejects that data as well.
- **Unknown availability** is allowed, but the route shows a "Before you go" warning.
- **No silent fallback.** If no route meets the preferences, the app shows "No suitable route found" and names the blocking connections. For example: "Elevator A (unavailable)" or "Skybridge to Annex (step-free suitability unknown)". It finds these by re-running Dijkstra with the blocked connections penalized. The relaxed route is used only to explain the failure and is never offered.
- **Nothing is invented.** Instructions are the authored text from the map. Lengths are shown only when recorded; for example, an elevator has none, so the screen says "Length not recorded." No compass directions or turns are generated.

### Demo scenarios (for the December 4 demo)

| Try | Expected |
|---|---|
| North Plaza → Room 201, step-free **off** | Front steps + Stairwell A stairs. Shortest route. |
| Same, step-free **on** | West ramp + Elevator A. No stairs. |
| Settings → **Simulate elevator outage**, step-free on | "No suitable route found … Elevator A (unavailable)." Stairs are not offered. |
| North Plaza → Annex reading room, step-free on | No route, because the skybridge's step-free status is unknown. |
| Same, step-free off | Route found, with warnings that the skybridge's availability and suitability are unknown. |
| Room 105 → North Plaza vs. North Plaza → Room 105 | The exit-only door is used leaving the building but never entering it (one-way). |

---

## 6. Map file format (`Resources/demo_map.json`)

Each **connection** records:

| Field | Meaning |
|---|---|
| `from`, `to`, `direction` | `bidirectional` or `one_way` |
| `type` | `corridor`, `door`, `stairs`, `ramp`, `elevator`, `bridge` |
| `lengthMeters` | Recorded length, or omitted if unknown. Displayed only. |
| `routingCost` | Optional Dijkstra weight. Defaults to `lengthMeters`; use it for things like elevator waiting time. Never shown as a distance. |
| `stepFree` | `confirmed` / `unsuitable` / `unknown`. Physical suitability. |
| `availability` | `available` / `unavailable` / `unknown`. Right-now status, kept separate from suitability. |
| `verification` | `status` (`simulated` / `unverified` / `verified`), `source`, `checkedOn`, `checkedBy`, `notes` |
| `instructions` | `forward` text, plus `reverse` text (required for bidirectional connections) |

The validator enforces the honesty rules:
- A `fictional_demo` map may only contain `simulated` connections.
- A `verified` connection needs `checkedOn` and `checkedBy`.
- Stairs can never be `confirmed` step-free.

When real survey data arrives, add a new map file with `dataStatus: "surveyed_unverified"` instead of editing the demo map.

---

## 7. Accessibility notes

- All text uses system text styles, so Dynamic Type works. Guidance buttons stack vertically when large text sizes don't fit side by side.
- Primary buttons are at least 44–56 pt tall.
- **With VoiceOver on:**
  - Each new guidance step moves VoiceOver focus to the instruction, so VoiceOver reads it. The app doesn't also speak it, to avoid two voices at once.
  - Other speech (Repeat, nearby alerts) goes through VoiceOver announcements.
  - The camera preview and schematic are hidden from VoiceOver or summarized in one line, since the text conveys everything.
- **Without VoiceOver:** `AVSpeechSynthesizer` speaks using the navigation prompt audio mode and ducks other audio.
- The colors are system colors with no custom palette, so contrast follows iOS in both light and dark mode.

**Please test on the device:** VoiceOver on, the largest accessibility text size, Bold Text, and Reduce Motion.

---

## 8. Nearby: what to test on the iPhone

- **First Start tap:** the camera permission prompt appears. If you deny it, you get a message with an **Open Settings app** button.
- **Permission changed while the app was in the background:** re-checked when you return.
- **Point at a wall about 1 m away:** the reading should be about 1 m. With alerts on and the distance set to 1 m, alerts fire once, then repeat at most every 3 s.
- **Cover the camera** or point at the sky: "No reliable reading." If alerts are on, you hear "Depth readings unavailable" once after about 1 s.
- **Switch tabs or background the app:** the camera stops. Returning from the background restarts it if it was running.
- **Interruption** (for example, a phone call or Siri): shows "Camera paused by the system."

Limits, also shown in the app: the reading covers only the center of the view. It does not identify objects, and it can miss glass, thin poles, overhangs and drop-offs.

---

## 9. Not in this milestone

There is no backend, accounts, analytics, cloud uploads, paid APIs or LLM calls. There is no object recognition; Vision/Core ML is a later milestone. There is no indoor positioning: you confirm each landmark yourself.
