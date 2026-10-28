# CarPlay: Maneuver Metadata (Instrument Cluster / HUD) + Second Map in Instrument Cluster

Source of truth: `CarPlay-Developer-Guide.pdf` (Apple, 2026-10-13). Page numbers below refer to it.

## 1. Context

OsmAnd supports the main CarPlay scene and the CarPlay Dashboard scene. There is a single map
(`OAMapViewController` -> `OAMapRendererView`), and its view is **moved** between windows.
There is no Instrument Cluster scene, and `CPManeuver` metadata (iOS 17.4+) is not filled in, so the
car gets no maneuver arrows for its instrument cluster or HUD.

Goals:
1. **Maneuver sharing** (iOS 17.4+): send maneuver metadata that the car shows in the cluster / HUD.
2. **Second map in the instrument cluster** (iOS 15.4+) on a separate `OAMapRendererView`.

## 2. Corrections to the original task description (verified against the guide)

- `CPMapTemplate.shouldProvideNavigationMetadata` does not exist. Implement the delegate method
  `mapTemplateShouldProvideNavigationMetadata:` and return `YES` (p.56).
- `suggestedContentStyle` does not exist. Use `scene.contentStyle` and `contentStyleDidChange:` (p.35, 55).
- Info.plist needs `CPSupportsInstrumentClusterNavigationScene = true` (p.54, 64), otherwise iOS never creates the scene.
- `CPInstrumentClusterControllerDelegate` is implemented by the cluster scene delegate, not by
  `OACarPlayDashboardInterfaceController`.
- Scene delegates in this repo are Swift (`DashboardCarPlaySceneDelegate.swift`), so the cluster delegate is Swift too.
- Required maneuver metadata: `maneuverType`, `junctionType`, `trafficSide`. Also required by the guide:
  `maneuverState` (continue -> initial -> prepare -> execute -> continue), current road name,
  `addManeuvers:` with as many maneuvers as possible, `CPLaneGuidance` / `CPLane` via `addLaneGuidances:` (p.56-59).
- Gaps in the current code that the original task did not mention:
  - `mapTemplateDidCancelNavigation:` is not handled. If the car's built-in navigation starts guidance,
    CarPlay guidance is cancelled by the system and the app must stop immediately (p.49).
  - Rerouting does not use `pauseTripForReason:CPTripPauseReasonRerouting` (p.49, 61), and
    `newRouteIsCalculated:NO` during guidance does nothing, so the car keeps a stale maneuver list.
- There is no separate HUD API. The HUD is fed by the same maneuver metadata. The second map is shown in
  the instrument cluster only, never in the HUD.
- Deployment target is iOS 15.0, so use `@available(iOS 15.4, *)` / `@available(iOS 17.4, *)` everywhere.
- Out of scope (iOS 26.4+): route sharing (`mapTemplateShouldProvideRouteSharing`, `CPRouteSegment`) and destination
  sharing. These are good follow-ups for cars with ADAS (p.60-61).

## 3. Will it work on an Audi e-tron HUD?

It depends on the car, not the app:
- HUD / virtual cockpit arrows work if the car firmware accepts CarPlay navigation metadata (iOS 17.4+).
  There is no other public API. Quick check in the car: if Google Maps or Waze show arrows in the HUD, OsmAnd will too
  after stage 2. If only Apple Maps does, the car does not support the public metadata path.
- The cluster map only works in cars that support the CarPlay instrument cluster scene. Many Audi virtual
  cockpits show their own built-in map instead, so stage 4 may do nothing there. It works in CarPlay Simulator.
- The iPhone needs iOS 17.4+.

## 4. Stages (4 PRs, ~8 commits)

Metadata first (it gives HUD arrows without any map work). Refactoring is a separate no-behavior-change stage.

### Stage 1 - Refactoring, no behavior change (2 commits)
**1a. `OACarPlayManeuverFactory`** (`Sources/CarPlay/OACarPlayManeuverFactory.h/.mm`).
Move maneuver building out of `onLocationUpdate` in `OACarPlayDashboardInterfaceController.mm`:
turn symbol (`OATurnDrawable`), lanes image (`OALanesDrawable`), secondary next-next maneuver,
`getNextTurnDescription` / `nextTurnsToString` / `shouldKeepLeft/Right`.
`onLocationUpdate` keeps only data selection, the `needToUpdate` check and sending to the session.
Stage 2 reuses the factory to build the full maneuver list.

**1b. `CarPlaySceneLaunchHelper.swift`**. Extract `configureScene()` / `OALaunchUpdateState` waiting from
`DashboardCarPlaySceneDelegate.swift` into a helper used by Dashboard and the new cluster delegate.
The main `CarPlaySceneDelegate` is not touched (iOS 18.5 `isWaitingForConfiguration` workaround, regression risk).

### Stage 2 - Maneuver sharing for cluster and HUD (3 commits), iOS 17.4+
**2a. Metadata in the factory**
- `trafficSide` from `OADrivingRegion isLeftHandDriving`; `junctionType` = roundabout / intersection.
- `maneuverType` mapping:

  | OASTurnType | CPManeuverType |
  |---|---|
  | C | `straightAhead` |
  | TL / TSLL / TSHL | `leftTurn` / `slightLeftTurn` / `sharpLeftTurn` |
  | TR / TSLR / TSHR | `rightTurn` / `slightRightTurn` / `sharpRightTurn` |
  | KL / KR | `keepLeft` / `keepRight` |
  | TU / TRU | `uTurn` |
  | RNDB / RNLB | `roundaboutExit1..19` by `exitOut`, else `enterRoundabout` |
  | OFFR | `noTurn` |
  | last direction | `arriveAtDestination` |

- `CPLaneGuidance` from `turnType.lanes`: angle from each lane's primary turn, active lane (`lane & 1`) -> `preferred`,
  otherwise `notGood`. Linked through `maneuver.linkedLaneGuidance`.

**2b. Session** (`OACarPlayDashboardInterfaceController.mm`)
- `mapTemplateShouldProvideNavigationMetadata:` returns `YES`.
- In `startNavigationSessionWithTrip:` build metadata maneuvers for all remaining route directions and call
  `addManeuvers:` + `addLaneGuidances:`.
- `onLocationUpdate`: copy metadata onto the first `upcomingManeuvers` item; update `maneuverState`
  (from `OAAnnounceTimeDistances isTurnStateActive:dist:turnType:`) only when it changes; keep `currentLaneGuidance` and
  `currentRoadNameVariants` up to date.

**2c. System cancel and reroute**
- `mapTemplateDidCancelNavigation:` -> `exitNavigationMode` and stop app navigation, no dialogs.
- Implemented: on a recalculated route (`newRouteIsCalculated:NO`) the maneuver list is re-added with `addManeuvers:`.
- Reroute pause/resume: `pauseTripForReason:CPTripPauseReasonRerouting` (the ObjC enum is `CPTripPauseReason...`; an earlier
  note saying `CPPauseReasonRerouting` was wrong) on `startProgress` / `updateProgress:` while a session exists. On
  `newRouteIsCalculated:NO` iOS 17.4+ resumes with `resumeTripWithUpdatedRouteInformation:` (CPRouteInformation: route maneuvers,
  empty lane guidances, first maneuver as current, trip and maneuver estimates); older iOS resumes via `upcomingManeuvers` in
  `onLocationUpdate` (assumption, not verified). If the new route has no maneuvers the trip stays paused. Not done:
  `resumeTripWithUpdatedRouteSegments:` (iOS 26.4+, route sharing).
- Verified against developer.apple.com JSON docs: CPManeuver metadata, CPLane `initWithAngles:highlightedAngle:isPreferred:`,
  CPNavigationSession `addManeuvers:` / `addLaneGuidances:` / `maneuverState` are all iOS 17.4+.

### Stage 3 - Cluster scene without a map (2 commits), iOS 15.4+
**3a. Manifest and service**
- `Resources/OsmAnd-Info.plist`: `CPSupportsInstrumentClusterNavigationScene = true` and role
  `CPTemplateApplicationInstrumentClusterSceneSessionRoleApplication`
  (`CPTemplateApplicationInstrumentClusterScene`, configuration `CarPlay-InstrumentCluster Configuration`,
  delegate `${PRODUCT_MODULE_NAME}.InstrumentClusterCarPlaySceneDelegate`).
- `UIApplication+Extension.swift`: configuration constant, `carPlayInstrumentClusterWindow`,
  `isCarPlayInstrumentClusterConnected`; include the cluster in `isCarPlayConnected` but **not** in
  `isAnyCarPlaySceneActive` (it would change viewport and gesture logic of the main map).
- `CarPlayService.swift`: `.instrumentCluster` case in the scene enum and in `disconnectScene`.

**3b. `InstrumentClusterCarPlaySceneDelegate.swift`**
(`CPTemplateApplicationInstrumentClusterSceneDelegate` + `CPInstrumentClusterControllerDelegate`):
launch through `CarPlaySceneLaunchHelper`; store controller, set `delegate`; set the cluster window root VC
(placeholder background by `contentStyle` at this stage); handle zoom in/out, compass and speed limit settings,
`contentStyleDidChange:`; clean up on disconnect. Register files in `project.pbxproj` (group `CarPlayDelegate`)
and the bridging header.

### Stage 4 - Map in the cluster on a second renderer (1-2 commits)
`Sources/CarPlay/OACarPlayClusterMapViewController.h/.mm` owns its own `OAMapRendererView`
(`createContext` on window connect, `suspendRendering` / `releaseContext` on disconnect).
No drawing logic is duplicated; it attaches the existing providers and collections of the main map.
- Base map: ObjC++ accessors in `OAMapViewController` plus `attachBaseMapProvidersTo:` (same `setProvider:forLayer:` /
  `addTiledSymbolsProvider:` calls the main map uses); re-attach on `mapSourceUpdatedObservable`.
- Route and position: getters for `OARouteLayer`'s `VectorLinesCollection` and `OAMyPositionLayer`'s `MapMarkersCollection`,
  added through `addKeyedSymbolsProvider:`.
  - Risk: verify in OsmAnd-core that a keyed collection can serve two renderers.
  - Fallback: extract the `VectorLineBuilder` / `MapMarkerBuilder` code into shared helpers and build separate collections.
- Minimal map per the guide (p.55): no terrain, 3D buildings, weather, POI, favorites or GPX.
- Camera: heading up, detailed view of the upcoming route (elevation ~60 deg, zoom 16-17, user zoom 13-18),
  position shifted down, viewport from `safeAreaLayoutGuide` and recomputed in `viewSafeAreaInsetsDidChange`.
- Performance: 30 fps limit (like `applyFrameRefreshRateLimit`), MSAA off, render only while the window is connected.
  Check the ANGLE / Metal path (`OSMAND_USE_ANGLE`) with a second context.

## 5. Testing on MacBook Pro M1 (CarPlay Simulator)

Prerequisites
1. macOS with the Xcode version used by the project; iOS Simulator runtimes **17.4+** (needed for metadata) and one 15.x/16.x runtime
   (to verify the `@available` guards).
2. Install **Additional Tools for Xcode** (developer.apple.com/download/all) and copy `Hardware/CarPlay Simulator.app`
   to `/Applications` (or `~/Applications`). This is where the CarPlay Simulator lives.
3. A free account cannot sign the CarPlay entitlement. In the Simulator the entitlement is not enforced, so build the
   `OsmAnd Maps` scheme for a simulator destination. If signing complains about `com.apple.developer.carplay-maps`,
   use a local, uncommitted copy of the entitlements for the simulator build.
4. Run Dependencies/Libraries setup as described in the repo README (OsmAnd core xcframeworks must be present).

Run steps
1. Open `OsmAnd.xcodeproj`, choose the `OsmAnd Maps` scheme and an iPhone simulator (iOS 17.4+), press Run.
2. In the iOS Simulator: **I/O -> External Displays -> CarPlay**. The CarPlay window opens (or launch CarPlay Simulator.app).
3. In CarPlay Simulator choose a vehicle configuration:
   - Main display: any preset.
   - **Instrument cluster**: presets "Standard Instrument Cluster" and "Widescreen Instrument Cluster" (p.62).
   - Custom checks: Manage... -> edit cluster: 300x200 @3x, 640x480 @2x, 1920x720 @3x with safe area 1080x720 at (420, 0),
     1920x720 @2x with safe area 640x480 at (640, 120).
4. Add OsmAnd to the CarPlay home screen, open it, search a destination, start a route.
   Set the iOS Simulator location: **Features -> Location -> City Run / Freeway Drive**, or a GPX file, to move along the route.

Checks per stage
- **Stage 1**: main CarPlay and Dashboard behave as before (map, turn symbol, lanes, second maneuver, estimates).
- **Stage 2**: CarPlay Simulator main window -> **Navigation** shows the upcoming maneuver the car received; **Show More** lists the
  full sequence. Check `maneuverType`, `junctionType`, `trafficSide`, lanes. Maneuver state must go
  continue -> initial -> prepare -> execute -> continue. Test a roundabout, a lane-guidance junction,
  a left-hand-traffic region, and a reroute (leave the route). "Route Sharing" panel is for iOS 26.4+ only.
- **Stage 3**: cluster window appears, connect/disconnect (toggle the cluster in the simulator) without crashes; main scene and
  Dashboard unchanged.
- **Stage 4**: cluster map renders at the same time as the main display, heading up, safe area respected, zoom buttons work,
  day/night switches, no leaks after reconnect (Instruments: Allocations, Metal System Trace).
- Logs: filter Xcode console by `[CarPlay]`.

Real car (Audi e-tron): after stage 2, iPhone iOS 17.4+, start guidance and check the HUD / virtual cockpit.

## 6. Key files

- `Resources/OsmAnd-Info.plist` (scene manifest, ~line 203)
- `Sources/CarPlay/OACarPlayDashboardInterfaceController.mm` (`present`, `onLocationUpdate`, `startNavigationSessionWithTrip:`)
- `Sources/AppHost/CarPlayDelegate/` (`CarPlaySceneDelegates.swift`, `DashboardCarPlaySceneDelegate.swift`, `CarPlayService.swift`)
- `Sources/SwiftExtensions/UIApplication+Extension.swift` (scene name constants and helpers)
- `Sources/Controllers/Map/OAMapViewController.mm`, `Sources/Views/OAMapRendererView.mm`
- `Sources/Controllers/Map/Layers/OARouteLayer.mm`, `OAMyPositionLayer.mm`
- `OsmAnd.xcodeproj/project.pbxproj` (groups: `CarPlay` DA5A795A26C563A000F274C7, `CarPlayDelegate` FA44BF562A72A8FC000D2F5F)

## 7. Environment note

Development here is on Windows, where the project cannot be built. All build and run verification happens on the Mac.
Files must be added to `project.pbxproj` by hand (PBXFileReference, PBXBuildFile, group, Sources phase); double check
them in Xcode on the Mac.

## 8. Scene ordering workaround (iOS 18.5+)

`CarPlaySceneDelegates.swift` (main scene) has `isWaitingForConfiguration`, added in commit 302d18572 (issue #4629, black screen).
Since iOS 18.5 (seen in CarPlay Simulator) `sceneWillEnterForeground` can arrive BEFORE `didConnect`, so the interface controller
and window are not set yet. `configureScene()` sets the flag and returns; `didConnect` calls `configureScene()` again if the
flag is set and the scene is in the foreground. Keep it. Whether iOS still behaves this way cannot be verified without a Mac.

- `DashboardCarPlaySceneDelegate` had NO such retry (`guard window != nil else { return }`), so it could stay unconfigured.
  Fixed: the shared `CarPlaySceneLaunchHelper` now has the same waiting flag (`run(isSceneConnected:)` +
  `takeWaitingForConnection()` from `didConnect`). Test on an iOS 18.5+ simulator.
- `InstrumentClusterCarPlaySceneDelegate` (stage 3) uses the helper the same way.
- The main `CarPlaySceneDelegate` keeps its own `isWaitingForConfiguration` (not migrated, regression risk).
