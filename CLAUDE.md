# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Purpose

**CPULoadMeter** is a macOS app that graphs the load on each CPU core over time, drawn by hand in SwiftUI, with a Menu Bar Extra that will ultimately carry the graph in the menu bar. `Design.md` is the specification: its body is the design as decided, and its appendices hold every decision's reasoning and the evidence behind it. See `~/.claude/CLAUDE.md` for the global style guide.

## Build and Test

```sh
# Build (Debug)
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug build

# Build (Release)
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Release build

# Run the tests
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug test
```

`App` is the only **shared** scheme — tracked at `CPULoadMeter.xcodeproj/xcshareddata/xcschemes/App.xcscheme`, so it exists in a fresh clone. It builds and runs the app, and its test action runs the `Tests` bundle. Use `-scheme App` for every action.

The tests are **hosted**: a test run launches the app and loads the test bundle into its process, so a window and the menu bar item appear for the duration of the run. Tests run in the Debug configuration only, because `@testable import` needs `ENABLE_TESTABILITY`, which Release turns off.

Checks made by hand, and the clean proof that the sandbox permits the kernel calls, use the **Release** product: a `test` run re-signs the Debug app with wider entitlements (see Testing below). The Release product is at `~/Library/Developer/Xcode/DerivedData/CPULoadMeter-<hash>/Build/Products/Release/CPULoadMeter.app`; `xcodebuild -showBuildSettings` prints the exact `BUILT_PRODUCTS_DIR`.

## Architecture

Two targets. Target names are generic, matching the `Config/` filename stems and the source directories rather than the products they build — the convention SourceTools and Utilities use:

| Target | Product | Builds from | Notes |
|---|---|---|---|
| `App` | `CPULoadMeter.app` | `App/` | The whole app: the pure core, the readers, and the SwiftUI scenes and views |
| `Tests` | `CPULoadMeter Tests.xctest` | `Tests/` | swift-testing; hosted in the app (`TEST_HOST`, `BUNDLE_LOADER`); `@testable import CPULoadMeter` |

There is no framework, on purpose: Design.md B.10 records the decision, and Testing below records what it means for the tests.

Inside `App/`, the code is layered as Design.md §3 and §4 describe:

- `App/Core/` is the pure core plus the two kernel readers. Nothing here carries an isolation annotation, and nothing needs one: the App target uses the project's default isolation, `nonisolated` (Design.md D21), and these are `Sendable` values and pure functions with no actor to belong to. Isolation is declared where it exists — the views and `CPULoadMeterApp` are main-actor through SwiftUI's `View` and `App` protocols, and the monitor will declare `@MainActor` — never assumed for a whole target and opted out of.
  - `CPUTicks` names the kernel's four cumulative counters. They are 32-bit and wrap; nothing compares them except by wrapping subtraction.
  - `readProcessorTicks()` calls `host_processor_info` and returns `[CPUTicks]` with the failure in its signature, `throws(MachError)`. The kernel allocates the reply in this task on every call and nothing frees it but the caller, so the `vm_deallocate` is a `defer` in that one function and no pointer escapes. The host port is obtained once, in a file-scope `let`, as libtop does.
  - `readProcessorName()` reads `machdep.cpu.brand_string` with `sysctlbyname`.
  - `nextDeadline(after:period:now:)`, the scheduling rule as a pure function: one period on, or one period from now if that has passed, so missed deadlines collapse into one late sample. `LoadGraph.stepLength` and `stepCount(forWidth:)`, the one geometric fact the model shares with the graph.
  - The value types of Design.md §4.1, each holding its invariant by construction and every operation returning a new value: `TickDelta` (the only place a counter is subtracted — in 32 bits with wrapping arithmetic, then widened; deltas add), `CPULoad` (made only from a `TickDelta`, or `zero`), `UsagePercentages` (cumulative rounding, always summing to 100), `LoadHistory` (always exactly `stepCount` loads, oldest first), `SamplingPeriod` (1…60 through failable initializers only), and `MonitorState` (`advanced(with:)` is the entire per-sample logic; a CPU-count change, the first sample included, is a baseline only). Nothing in the app uses them until the monitor lands; the test bundle reaches them through the app's debug dylib regardless.
- `App/LoadMonitor.swift` is the sampler: `@Observable @MainActor`, owning one loop `Task`, the period, the `MonitorState`, and the last error, and persisting nothing. Its reader and its sleep are passed in (`@MainActor` function types; defaults are the real reader and `Task.sleep` on the continuous clock), which is what makes every behavior testable without a clock: the tests drive it with `ScriptedTicks` and `ScriptedSleep`. Its `deinit` is `isolated` — a plain `deinit` cannot cancel the main-actor `loop`. The `App` creates it in `init` from the stored period and the stored window width, owns it as `@State`, and passes plain values down; the extra receives it through the environment, unused until the live graph.
- `App/Views/` holds the SwiftUI views. `LoadView` is Design.md §5.5 as written — one CPU's history as one stroked path in a `Canvas`, a line per step rising from the bottom edge, newest at the right, the line's center half a width left of a whole point; `lineWidth` is a parameter. `LoadStackView` stacks one per CPU with a `Hairline` between, carries the accessibility label and value, and reports the step count its width holds through `onGeometryChange` — only after it has appeared, because SwiftUI lays the window out once at a default 900-pt width before placing it and that report would truncate a windowless history (Findings below). `HeaderView` is the two lines of §2.6 — name and core count with `PeriodControl` beside them, the usage line in `top`'s wording below (`CPU usage: —` before the first load, `CPU usage unavailable` while samples fail) — and `PeriodControl` is the combo box of §5.9 composed from a `TextField` and a borderless `Menu`: the draft commits on Return and on focus loss through `committedPeriod(from:current:)`, the reject-and-revert rule as one pure function. `MainView` owns the field's `@FocusState` and clears it on a click on the graphs or the header's text — nothing else in the window can take focus, so without that a click elsewhere never ends editing. Switching apps or windows is deliberately *not* a commit: the draft waits, as in every Mac app (Design.md D.6, P5). `MainView` is the layout of §5.3. `MenuBarExtraMenu`'s *Show CPULoadMeter* calls `openWindow` and nothing else: with another app active it does **not** bring the app to the foreground, a known limitation of version 1 that Design.md D19 and §8 record and defer. The design is pure SwiftUI — no `import AppKit`, no app delegate, no `NSViewRepresentable` — and any AppKit call needs a decision recorded in the spec; see the Findings below for the two that were tried here and rolled back.
- `App/Views/MainWindowContent.swift` is the window's root view and **the one place the monitor is read**: it hands `MainView` plain values and stores the period when it changes. The `App` body must never read the monitor's state — a scene body that observes a value is re-evaluated when it changes, and the menus are rebuilt with the scenes, once a second in this app's case (Findings below).
- `App/CPULoadMeterApp.swift` declares the scenes. Their order is load-bearing: `Window` first, `Settings`, `MenuBarExtra` last, and the extra always inserted, because the extra's presence is what lets the app outlive its window and gives the window its Window-menu entry (Design.md B.1, D.2).
- `App/Diagnostics.swift` is the `os.Logger`, subsystem `coreaudio-fan.CPULoadMeter`, category `monitor`. Its messages are debug level and present in every build; read them with `/usr/bin/log stream --debug --predicate 'subsystem == "coreaudio-fan.CPULoadMeter"'`.
- `App/DefaultsKey.swift` names the `UserDefaults` keys. The app and its views read and write defaults; the core and the readers touch none.

### The window's size

Restoration is disabled so that the launch checkbox alone decides whether the window opens, and that also stops the system saving the window's frame, so the app saves the size itself: `onGeometryChange` reports it, two optional doubles in `UserDefaults` hold it, and `defaultWindowPlacement` restores it.

What is stored is the window's **whole content rect**, the view's size plus its safe-area insets. Under `.windowStyle(.hiddenTitleBar)` the title bar's region is a safe-area inset — 32 pt on macOS 27.0 — that the view is laid out below, while the placement sizes the whole rect. Storing the view's size alone shrank the window by one inset on every relaunch: seeded with 700×400, the frame went 400, 368, 336 (observed 2026-09-21). The content's ideal size from `sizeThatFits` is likewise the view's without the inset, so a first launch comes up one inset shorter than ideal; every later launch uses the stored rect, which is exact.

### Languages

The targets are configured to host **C, C++, Objective-C, and Swift**, not Swift alone. The sources are Swift-only, but the build settings are deliberately broader: `GCC_C_LANGUAGE_STANDARD = gnu23`, `CLANG_CXX_LANGUAGE_STANDARD = gnu++23`, and the full Objective-C and C++ warning and static-analyzer allowlists.

Do not read the current file list as the project's language scope, and do not prune C, C++, or Objective-C settings as dead weight. Apple frequently reuses a build setting that is ostensibly for one language to control another, and frequently does not document that it does.

Platform scope is a separate axis and *is* narrow: `SUPPORTED_PLATFORMS = macosx` on both targets, because the app reads the kernel through Mach and sysctl and draws into the macOS menu bar.

### Adding files

`App/`, `Tests/`, and `Config/` are `PBXFileSystemSynchronizedRootGroup`s (`objectVersion = 77`). Files are picked up by folder membership — **drop a file into the directory and it joins the target with no `project.pbxproj` edit** — and subdirectories such as `App/Core/` and `App/Views/` are organization only. This is also why XCODE-1 (navigator mirrors the filesystem) holds by construction. `Config` belongs to no target: it anchors the xcconfig references and carries the entitlements, so nothing in it joins a build phase.

### Build settings (`Config/`)

All build settings live in `.xcconfig` files; every `buildSettings` dict in `project.pbxproj` is empty, wired via `baseConfigurationReferenceAnchor` + `baseConfigurationReferenceRelativePath`. When changing a setting, edit the `.xcconfig` — anything set in Xcode's Build Settings UI gets written back as an inline pbxproj override that silently shadows the file. **This includes the Tests target's Host Application pop-up**: the host is set by `TEST_HOST` and `BUNDLE_LOADER` in `Tests-Common.xcconfig`, and the pop-up must be left alone. The files reproduce the organization of Xcode's Build Settings UI; see HelloWorld's CLAUDE.md for the exact formatting rules.

| File | Scope |
|---|---|
| `Project-{Common,Debug,Release}.xcconfig` | Byte-identical copies of SourceTools' and Utilities' — language standards, warning and analyzer allowlists, Swift language mode and concurrency, signing, and the optimization/testability split |
| `App-*.xcconfig` | App target: platform, packaging, runpath, entitlements, hardened runtime; no isolation override |
| `Tests-*.xcconfig` | Test bundle: platform, packaging, and the host — `TEST_HOST` and `BUNDLE_LOADER` |
| `App.entitlements` | The sandbox alone |

Deliberate divergences from the siblings' baseline, each on purpose:

- `RUN_DOCUMENTATION_COMPILER = NO` on both targets. The project publishes no API — there is no framework — so there is nothing for the documentation compiler to enforce. HelloWorld takes the same position.
- **No `SWIFT_DEFAULT_ACTOR_ISOLATION` override** in `App-Common.xcconfig`, where SourceTools' app sets `MainActor` "mirroring Apple's app template". The project baseline, `nonisolated`, applies to both targets. A `MainActor` default puts everything in one isolation domain so that a simple app need not think about synchronization, and its cost here was a `nonisolated` on every pure declaration to escape it (Design.md D21, 2026-09-22). Do not reintroduce it; declare `@MainActor` where mutable UI-facing state lives.
- The Tests target sets `TEST_HOST` and `BUNDLE_LOADER`, which the siblings' test bundles do not. `TEST_HOST` must equal the app's `$(BUILT_PRODUCTS_DIR)/$(EXECUTABLE_PATH)` exactly; a mismatch is only a build-system warning ("Unable to find a target which creates the host product"), which a warnings-as-errors build does not fail on, so a changed product name has to be checked in the build log. The target sets no signing, runpath, or entitlement overrides: it inherits the project's team signing, which the host's library validation requires.

## Testing

The suite uses **swift-testing** — `import Testing`, `struct` suites, `@Test` functions, `#expect`/`try #require`. 62 tests in 14 suites as of this writing.

**`@testable import` is used here, where the sibling projects forbid it.** That is a decision, recorded in Design.md B.10 and reasoned from the style guide's *Testability* section: a test stands where the API's real clients stand. SourceTools' and Utilities' APIs are published from frameworks to real importers, so a plain import is their clients' position and `@testable` would hide access-control regressions. Nothing here is published: the app's own code, which sees `internal` declarations, is the only client there is, and `@testable import` gives a test exactly that view while `private` stays the enforced line. A framework target existing only so that a plain import could be written would be structure bought to satisfy a guideline whose reason does not arise (*Proportionality*).

**The drawing is tested on its pixels.** `Tests/PixelGrid.swift` renders a view with `ImageRenderer` at a fixed size and scale, redraws it into a cleared RGBA8 context of its own so the memory layout is known, and exposes alpha with row 0 at the top; an orientation check on a plain stack keeps a flipped helper from cancelling a flipped view. `LoadViewRenderingTests` computes every pixel's expectation from §5.5's rules and compares whole grids; the reference alpha is measured from the full-height line, never assumed. Each grid is attached as a PNG: run the tests with `-resultBundlePath X.xcresult`, then `xcrun xcresulttool export attachments --path X.xcresult --output-path DIR` (no scheme change needed; the manifest maps names to files). The renderer draws lines of one or two device pixels one pixel taller and antialiases nothing, so the tests use loads three pixels or taller (see Findings).

**The tests are hosted in the app.** `Tests/HostingTests.swift` asserts it: the tests run inside the app's process (`Bundle.main.bundleIdentifier`), inside its sandbox container (`NSHomeDirectory()`), and can reach the app's internal declarations. A control run with `TEST_HOST` and `BUNDLE_LOADER` removed fails the first two, reporting `com.apple.dt.xctest.tool` and the real home directory (2026-09-21), so the assertions can fail. Because every test runs in the sandboxed app, the readers' smoke tests re-prove on every run that the sandbox permits the kernel calls.

**Guards proved able to fire**, in scratch copies:

- `readerFreesEveryReplyBuffer` stands in for an invariant the type system cannot express. It calls `readProcessorTicks()` 4,000 times and requires the physical footprint (`task_info`, `TASK_VM_INFO`) to grow by under 16 MB. With the `vm_deallocate` removed it failed with a growth of 65,830,960 bytes — one 16 KB page per call.
- Under the App target's earlier `MainActor` default (2026-09-21), a `nonisolated` missing from a core declaration failed the *test* build (`Tests/ProcessorTicksReaderTests.swift:19`) and, once the core types referenced each other, the app build too. D21 removed that default and the annotations with it; there is nothing left to guard.

**A test run is not the shipping sandbox.** The `test` action re-signs the Debug app with `get-task-allow`, a read-only file exception for `/`, and Mach lookups for `com.apple.testmanagerd`, `com.apple.dt.testmanagerd.runner`, and `com.apple.coresymbolicationd`, and it builds the test bundle into the app's `Contents/PlugIns`. None of that touches a host-port call or a sysctl read, so the hosted reader tests mean what they say; but the clean proof of the sandbox, and every check by hand, uses the Release product.

## Findings

Dated, with what was observed, so that a later reader can tell a decision from an accident.

### Hosted tests under the hardened runtime (2026-09-21)

The open question at bring-up was whether the hardened runtime would let Xcode inject a test bundle into a sandboxed host, which no sibling project does. It does, with nothing added: the `test` action's `get-task-allow` is enough. Observed from inside the host process with `_dyld_get_image_name`: `libXCTestBundleInject.dylib` loaded at image index 1, ahead of the app's own binary; the test bundle from `Contents/PlugIns`; and `XCTest.framework`, `Testing.framework`, `XCTestCore.framework`, and `XCTestSupport.framework` **from Xcode's own `Contents/SharedFrameworks`**, resolved through `DYLD_FRAMEWORK_PATH`. Nothing was copied into the app: its `Contents/Frameworks` does not exist after a test run, although the injector's path list names a copy there first. Design.md §6 says the frameworks are copied into the host; on Xcode 27.0 they are not.

### Sandbox denials that are not this app's (2026-09-21)

With the log streaming during a Release launch, the kernel reports `deny(1) system-info vfs.disk-space` many times and `deny(1) iokit-open-user-client AppleNVMeEANUC` once. Neither reader provokes them: SourceTools' sandboxed app, which makes no kernel reads, logs both at launch too. What those two operations are for is not documented, and nothing here is decided on them. The launch line — `Launched on Apple M2 Ultra with 24 CPUs` — is written from inside the shipping sandbox, which is the proof that both reads are permitted.

### The first hand checks (2026-09-21)

On the Release build: closing the window leaves the app running and Window ▸ CPULoadMeter reopens it (P1); the launch checkbox, the remembered size, and a Dock click with the box unchecked behave as specified (P3); `SettingsLink` works from the extra, the traffic lights are present, and About is right (P13). Two things did not hold, and the spec records both as decisions (Design.md A.1, D19 and D20; results in D.6):

- ***Show CPULoadMeter* does not bring the app to the foreground** with another app frontmost. SwiftUI has no activation action. Two AppKit requests were tried after `openWindow` and **rolled back** (D19): the bare `NSApplication.activate()`, which changed nothing — a probe from inside the app with a Finder window in front showed the system declines it every time, along with the deprecated `activate(ignoringOtherApps:)`; and `NSRunningApplication.activate(from:options:)` naming the frontmost app, which the same probe saw granted every time, but which the hand check showed works *only* with a Finder window in front — with Xcode or any other app in front it does nothing. The probe's one rival app was Finder, so its result was a special case. Also measured: `makeKeyAndOrderFront` alone gets the window to second place, behind the active app's key window, which is the rule Apple states on `orderFrontRegardless()`; `orderFrontRegardless()` itself puts the window on top with the app still inactive. Deemed tertiary and deferred; the measurements are in Design.md B.1 and D.6. Untried: a URL scheme opened through Launch Services, and `orderFrontRegardless()` as the shipped behavior.
- **The menu bar extra can be command-dragged out of the menu bar, and with the window closed that quits the app.** Both are documented: Apple's `MenuBarExtra` overview says an app that only shows in the menu bar is terminated when the user removes the extra. SwiftUI offers no way to forbid the removal, only the `isInserted` binding. Accepted as is; do not "fix" it without reopening D20.

### Cadence and agreement with `top` (2026-09-22)

Measured on the Release product with the per-sample log line. With no window open, period 2 s, 74 seconds: intervals min 1.89 s, median 2.00 s, max 2.12 s — no App Nap stretching — and every sample about 90 ms after its deadline (1.8–131 ms), which looks like the sleep's system-chosen tolerance; harmless, because the deadline advances by the period, not from the wake. A sample costs 0.3 ms. Through a ten-second live resize and a ten-second menu hold at a 1 s period: 105 samples, intervals 0.936–1.061 s, no stall — the task-based loop has none of a default-mode `Timer`'s run-loop-mode pauses; lateness was ~50 ms there, so the tolerance is about 5% of the period. Against `top -l 16 -s 2` over the same phases, busy agreed within 0.73 points idle and 0.01 points under four `yes` processes; `yes > /dev/null` shows as system time. Design.md D.6 has the numbers.

### A snapped window elsewhere re-fits when this app launches (2026-09-22)

Not a bug here. Launching the app adds a Dock tile of its own — the Dock never lists it among its recent applications, for reasons unknown, where Font Book and Calculator take a recents slot and add no tile — so a full Dock scales its icons down, the screen's visible frame narrows by 6 pt on the Dock's side (measured with `NSScreen.visibleFrame`), and any window another app has *snapped* to a screen edge re-fits itself to the new frame; quitting reverses it. A freely placed window does not move. Design.md D.6 has the measurements.

### Scene bodies observe too (2026-09-22)

After PR 4, open menus showed one set of items and then another, and sometimes closed with the button held. The `App`'s body read `monitor.state` to pass `MainView` its values, so Observation re-evaluated the scenes once a second — a probe counted 8 evaluations in 8 s — and SwiftUI rebuilt the menu bar and the extra's menu each time. Moving every read of the monitor into `MainWindowContent` cut the app's body to one evaluation in 8 s with the window content at nine. Rule: the `App` body hands objects down and reads nothing observable; the first view under a scene does the reading.

### The renderer, and the transient layout (2026-09-22)

`ImageRenderer`'s output of a `Canvas` has no antialiasing — every pixel is the label color's full alpha (216/255) or zero — and lines one or two device pixels tall come out one pixel taller, at both scales and both stroke widths, while three pixels and taller are exact. Undocumented; the pixel tests stay on lines the renderer draws faithfully, and what the shortest lines look like on screen is a check by eye.

SwiftUI lays a window out once at a default size — 900 pt wide here — before `defaultWindowPlacement` applies, and that layout's `onGeometryChange` report arrives 2 ms *before* the content's `onAppear`; the placed size's report arrives after. `LoadStackView` reports its step count only after appearing, or a history built while no window was open would be cut to 900 steps and zero-filled back. Also observed: `Step count 900, 3200, 3072` at a stored width of 3,200 — the display allows 3,072.

### Cost at full display width (2026-09-22)

At 3,072 steps × 24 CPUs, period 1 s, Release: the app takes a median 4.0% (max 6.8%) of one core by `top -pid`, 0.76 ms per sample by the log; WindowServer's share attributable to it is a point at most. Sampling stays on the main actor.

### The menu bar extra, seen from inside (2026-09-21)

`CGWindowListCopyWindowInfo` from another process does not show the status item in a form this project could interpret. From inside the app, `NSApplication.shared.windows` lists it plainly: an `NSStatusBarWindow`, visible, level 25, 32×30 at the top-right of the menu bar; and the Window menu lists `CPULoadMeter`, the signature of the inserted-extra lifetime that Design.md D.2 established. That observation was a disposable hosted test importing AppKit; the app itself imports none.
