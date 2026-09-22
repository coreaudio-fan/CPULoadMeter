# CPULoadMeter — Design Specification

**Status:** Decided, 2026-09-21. Nothing is built yet.

**How this document is organized.** Sections 1–8 say what to build, stated as decided; they carry no argument. The reasoning, the rejected alternatives, the experiments, and the sources are in the appendices, and each section ends with a pointer to where its reasoning lives.

| Appendix | Holds |
|---|---|
| **A — Decision record** | Every decision, who made it, and where it is specified; the defaults adopted without discussion; how the document got here; what planning the implementation changed |
| **B — Rationale** | The reasoning behind the design, by topic |
| **C — Prior art** | How `top`, `ps`, and the kernel handle the same problems, read from Apple's source |
| **D — Experiments** | The probes that settled open questions, with their source |
| **E — Evidence** | What each factual claim rests on |

## 1. Overview

CPULoadMeter graphs the load on each CPU core over time. It recreates a lost Cocoa app in Swift and SwiftUI, as a vehicle for learning how to draw to the screen. Its eventual form draws the graph into the menu bar with no windows open; version 1 builds the window and lays the groundwork for that.

Three principles govern the design:

1. **The graph is drawn by hand.** Drawing is the point of the exercise, so the graph is built from samples with SwiftUI's drawing primitives rather than delegated to a charting framework.
2. **Pure SwiftUI.** There are no AppKit bridges: no app delegate and no `NSViewRepresentable`.
3. **Consistent with the system's own tools.** What this app reports agrees with `top`. Throughout this document "load" means what `top` calls *CPU usage* — the share of time a CPU spent busy — and never `top`'s *Load Avg*, which is the length of the run queue.

*Rationale: B.5. Prior art: Appendix C.*

## 2. Behavior

### 2.1 The application

- A regular macOS application named CPULoadMeter, with a Dock icon and the standard menu bar.
- Requires macOS 26.0 or later. Built universal; Intel Macs are supported but untested.
- Sandboxed, with the hardened runtime.
- Written entirely in Swift. The kernel interface is called directly from Swift.

*Rationale: B.11 (sandbox), B.14 (Intel), B.15 (Swift alone suffices).*

### 2.2 Lifetime

- Closing the main window does not quit the application.
- Sampling starts at launch and continues for the life of the process, whether or not a window is open.
- The application quits from its application menu or the Dock, as any app does.

*Rationale: B.1, B.9.*

### 2.3 Menus

The menu bar is SwiftUI's default set of menus, unmodified. That provides:

- **About CPULoadMeter**, which shows the standard About panel: icon, name, version, and copyright.
- **Settings…**, which opens the settings window.
- In the **Window** menu, an entry titled **CPULoadMeter** that shows the main window, or brings it forward if it is already open. The entry is there whether the window is open or closed.

*Rationale: B.1, B.14.*

### 2.4 The menu bar extra

- The app places an item in the system menu bar, shown as the `cpu` symbol.
- Its menu has two items: **Show CPULoadMeter**, which shows the main window or brings it forward, and **Settings…**. When another app is active, choosing *Show CPULoadMeter* does not bring this app to the foreground: SwiftUI has no way to activate the app, and a window of an inactive app cannot be ordered above the active app's key window. A known limitation of version 1, deferred (§8).
- The item is always present: there is no setting to hide it. The user can remove it by command-dragging it out of the menu bar, as with any menu bar extra, and if no window is showing when that happens the system quits the app. Nothing prevents either; version 1 accepts them.

*Rationale: B.1.*

### 2.5 The main window

- There is one main window. Its title is `CPULoadMeter`, which is the text the Window menu shows. The window itself has a hidden title bar and displays no title.
- It is freely resizable down to a minimum: as wide as the header needs, and as tall as the header plus 8 pt for each LoadView.
- It never scrolls.
- On first launch it opens 480 pt wide, with 20 pt for each LoadView below the header. After that it reopens at the size it last had. Its position is not remembered.

*Rationale: B.7 (title), B.8 (size and position), B.14 (minimum size).*

### 2.6 The header

The header is pinned to the top of the window at its natural height and spans the window's width.

```
Apple M2 Ultra · 24 cores                          Update every [  1 ][▾] seconds
CPU usage: 8% user, 4% system, 88% idle
```

- **The processor's name and the number of cores.** The count is the number of CPUs the kernel reports, which is also the number of LoadViews. If the name cannot be read, the header says "Unknown CPU".
- **The machine-wide CPU usage**, in `top`'s wording and order: user, system, and idle, as whole percentages that sum to 100. Before the first load is available the line reads `CPU usage: —`. While samples are failing it reads `CPU usage unavailable` (§2.15).
- **The update-period control** (§2.11).

The header says nothing about core kinds.

*Rationale: B.5 (wording and whole percentages), B.6 (no core kinds).*

### 2.7 The LoadViews

- Below the header, one LoadView per CPU fills the rest of the window.
- They stack top to bottom in the order the kernel reports the CPUs, which is CPU-ID order: the top view is CPU 0.
- They share the available height equally, and each spans the full width.
- They carry no labels. Adjacent views are separated by a hairline.

*Rationale: B.6.*

### 2.8 The graph

- Each LoadView plots its CPU's load history as vertical lines rising from the view's bottom edge.
- The view's width is divided into steps 1 pt wide, counted from the right edge. Step 0, at the right edge, holds the newest load; each step to its left is one sample older.
- A step's line is *load × view height* tall: a load of 50% in a view 10 pt tall draws a line 5 pt tall. The scale is fixed at 0–100% and never auto-ranges. Heights are not rounded.
- A zero load draws nothing.
- When the view's height changes, the whole history is redrawn at the new scale.

*Rationale: B.3.*

### 2.9 Load

- A CPU's **load** is the busy fraction of the ticks that elapsed between two consecutive samples: user, system, and nice ticks, divided by those plus idle ticks.
- One sample is only a baseline. The app takes a baseline at launch, and the first load is available one period later.
- The **machine-wide** figure applies the same definition to the ticks of all CPUs summed.
- These are the figures `top` reports as CPU usage, and they agree with `top` running alongside.

*Rationale: B.5. Prior art: C.2, C.4, C.6.*

### 2.10 History

- Each CPU retains exactly as many loads as its LoadView has steps. There is one step count for all CPUs, since all LoadViews share a width.
- The history starts as all zeros.
- Each new load shifts the others one step left; the oldest is discarded.
- When the view widens, the added steps hold zeros and are the oldest. When it narrows, the oldest loads are discarded first.
- With no window open the history keeps its last step count. At a launch with no window, it starts from the step count of the stored window width; if no width has ever been stored, from the first-launch window's.
- The history is not saved between launches.

*Rationale: B.4.*

### 2.11 The update period

- The period is a whole number of seconds from 1 to 60. The default is 1.
- Its control is an editable field with an attached pop-up of presets: 1, 2, 5, 10, and 30. Choosing a preset sets the field and the period.
- A typed entry takes effect when Return is pressed or the field loses focus. An entry that is not a whole number from 1 to 60 is rejected: the field reverts to the current period and nothing else changes. There is no alert and no beep.
- A new period takes effect immediately: the next sample is one new period away.
- Changing the period keeps the existing history. Steps sampled at the old period remain and simply stand for a different duration.
- The period is remembered between launches.

*Rationale: B.2, B.9.*

### 2.12 Settings

- The settings window has one checkbox, **Open main window at launch**, on by default.
- The checkbox always decides whether the main window opens at launch. The system does not restore the window on its own.
- With the box unchecked, clicking the Dock icon does not show the main window. The menu bar extra and the Window menu do.

*Rationale: B.8.*

### 2.13 Appearance

Colors are the system's semantic colors and follow the Light and Dark appearance with no appearance-specific code.

| Element | Color |
|---|---|
| Plot, primary header text | label color (`Color.primary`) |
| Secondary header text | secondary label color (`Color.secondary`) |
| Hairlines | separator color |
| Window and graph background | the default window background, unpainted |

*Rationale: B.14.*

### 2.14 Accessibility

Each LoadView has an accessibility label naming its CPU by index ("CPU 3") and a value giving its latest load as a percentage. The header is ordinary text.

*Rationale: B.14.*

### 2.15 Failures

- If a sample cannot be read, the header shows `CPU usage unavailable`, the graphs are left as they are, and sampling tries again at the next period. There is no alert.
- The next successful sample yields a load averaged over the whole interval since the last good one.
- If the number of CPUs changes between samples, the app takes a new baseline.

*Rationale: B.13.*

### 2.16 Sleep, wake, and late timers

- If the timer is late or deadlines are missed — the Mac slept, or the system throttled the app — the missed deadlines collapse into a single sample, never a burst.
- A late sample is still correct. It covers a longer interval, and the load is the average over that interval.

*Rationale: B.9.*

## 3. The project

A new directory `CPULoadMeter/` beside the other projects, with its own git repository. Work branches are named `users/coreaudio-fan/…`.

### 3.1 Targets

Two targets, named generically to match the `Config/` filename stems, as the sibling projects' are.

| Target | Product | Builds from | Contents |
|---|---|---|---|
| `App` | `CPULoadMeter.app` | `App/` | Everything: scenes and views, the monitor, and the pure core with its two kernel readers |
| `Tests` | `CPULoadMeter Tests.xctest` | `Tests/` | swift-testing; `@testable import CPULoadMeter`; hosted in the app |

The pure core is kept together in `App/Core/`. Nothing in it imports SwiftUI or refers to the monitor; that separation is a convention, kept by folder and by review.

*Rationale: B.10.*

### 3.2 Build settings

All build settings live in `Config/*.xcconfig`; every `buildSettings` dictionary in the project file is empty. The project uses `objectVersion = 77` synchronized root groups and one shared scheme, `App`.

- **`Project-{Common,Debug,Release}.xcconfig`** — byte-identical copies of the sibling projects'.
- **`App-*.xcconfig`** — modelled on SourceTools' app: `SUPPORTED_PLATFORMS = macosx`, `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `RUN_DOCUMENTATION_COMPILER = NO`, the sandbox entitlement and hardened runtime, `INFOPLIST_KEY_NSHumanReadableCopyright`, bundle ID `coreaudio-fan.CPULoadMeter`, and category `public.app-category.utilities`. No `LSUIElement`: this is a regular app that also has a menu bar extra.
- **`Tests-*.xcconfig`** — modelled on SourceTools' tests, plus `TEST_HOST` set to the app's executable and `BUNDLE_LOADER = $(TEST_HOST)`. `RUN_DOCUMENTATION_COMPILER = NO`.
- No DocC anywhere in the project; it publishes no API.
- The full C, C++, and Objective-C settings stay, though the source is Swift only.
- No architecture override; the app builds universal.

Tests run in the Debug configuration, where the shared project settings enable testability.

*Rationale: B.10, B.11, B.15.*

### 3.3 Housekeeping

When the project lands: a project `CLAUDE.md` and `README.md`, and an entry in the workspace `CLAUDE.md`, which is a dotfiles-managed file. The project's `CLAUDE.md` records the decision to use `@testable` and its reasoning (B.10), so that the departure from the sibling projects' convention reads as a decision rather than an oversight.

## 4. Architecture

The shape is a functional core inside an imperative shell. Everything with a branch in it is a pure function over value types, which the tests drive with hand-written tick values and no kernel. The shell sleeps, reads, and assigns.

```
kernel ──host_processor_info──▶ readProcessorTicks()                    impure edge   (App/Core)
                                   │ [CPUTicks]
                                   ▼
                  MonitorState.advanced(with:)                          pure          (App/Core)
                                   │ MonitorState
                                   ▼
        LoadMonitor  @Observable @MainActor — owns the Task, the period, the state    (App)
             ▲                     │ observation
  step count │                     ▼
   MainView ─▶ HeaderView(name, total, period)  +  LoadStackView ─▶ LoadView(history) × N
```

### 4.1 The pure core

`internal`, `Sendable` value types in `App/Core/`. The app target defaults to `MainActor` isolation, so every top-level declaration in `App/Core/` — these types and the two readers — is marked `nonisolated`.

| Type | Role | Invariant, and how it is enforced |
|---|---|---|
| `CPUTicks` | One CPU's four cumulative counters: user, system, idle, nice | — |
| `TickDelta` | The ticks that elapsed between two samples: user (with nice folded in), system, and idle. One CPU's, or the sum of several | The per-CPU initializer takes two `CPUTicks` and subtracts in 32 bits with wrapping arithmetic before widening, so a counter wrap is harmless by construction. Deltas add, in 64 bits, which is how the machine-wide figure is formed. |
| `CPULoad` | `user` and `system` fractions; `total` computed; `CPULoad.zero` | Each in 0…1 and `total` ≤ 1. Apart from `zero`, the only initializer takes a `TickDelta`, so the invariant holds by construction. A delta of zero ticks yields `zero`. |
| `UsagePercentages` | The header's three whole percentages: user, system, idle | Each in 0…100, summing to exactly 100. The only initializer takes a `CPULoad` and rounds cumulatively (§5.4). |
| `LoadHistory` | One CPU's retained loads, oldest first | **Always exactly `stepCount` loads.** `init(stepCount:)` is all zeros. `appending(_:)` drops the oldest and adds the newest, so the length cannot change. `resized(toStepCount:)` prepends zeros to grow and keeps the newest suffix to shrink. All three return new values. |
| `SamplingPeriod` | Whole seconds; `presets`; `default` | 1…60, through failable initializers only — `init?(seconds:)` and `init?(text:)`. There is no way to construct an out-of-range period. |
| `MonitorState` | The previous ticks, one `LoadHistory` per CPU, and the latest machine-wide load | `advanced(with: [CPUTicks])` is the entire per-sample logic as one pure function. `resized(toStepCount:)` maps the resize over every history. A change in the CPU count resets the baseline and replaces the histories with zeros at the current step count; the first sample is the same rule, going from no CPUs to N. |

The scheduling rule is pure as well: given the previous deadline, the period, and the present instant, `nextDeadline` returns the following deadline, collapsing any that were missed (§5.8).

Two impure readers complete the core: `readProcessorTicks()` (§5.6) and `readProcessorName()`, which returns the processor's name or `nil`.

### 4.2 The shell

`LoadMonitor` is an `@Observable`, `@MainActor` class. It owns the sampling task, the period, the current `MonitorState`, and the last error. It is created and owned by the `App`, not by any view, so its lifetime is the process's.

- **Its two collaborators are passed in.** The tick reader is an initializer parameter of type `() throws(MachError) -> [CPUTicks]`, defaulting to `readProcessorTicks`. The sleep is a second, of type `(ContinuousClock.Instant) async throws -> Void`, defaulting to `Task.sleep(until:clock:)` on the continuous clock. With both scripted, the monitor's whole behavior — what it does with a failed read, with a changed CPU count, with a new period — is exercised deterministically and without waiting on a real clock.
- **It persists nothing.** The `App` reads the stored period, hands it to the monitor, and stores it again when it changes. The monitor's tests run inside the app and share its real defaults, so a monitor that wrote its own period could change the user's setting during a test run.
- **The step count flows up from the view.** `LoadStackView` measures its width, converts it to a step count with `LoadView.stepLength`, and reports it to the monitor, which resizes its state. This is the one place the model depends on view geometry, and it does so by design (§2.10).
- **Views take values, not the monitor.** A parent reads what it needs from the monitor in its `body` and passes plain values down; `LoadView` receives one `LoadHistory`.

*Rationale: B.4 (history), B.16 (the injected reader), B.17 (the injected sleep; no persistence).*

## 5. Components

Code in this section shows the intended shape. Where it depends on platform behavior that has not yet been confirmed, the check is listed in §7.

### 5.1 The app and its scenes

```swift
@main
struct CPULoadMeterApp: App {
	@AppStorage("isMainWindowOpenedAtLaunch") private var isMainWindowOpenedAtLaunch = true
	@AppStorage("mainWindowWidth") private var mainWindowWidth: Double?
	@AppStorage("mainWindowHeight") private var mainWindowHeight: Double?
	@AppStorage("samplingPeriodSeconds") private var samplingPeriodSeconds = SamplingPeriod.default.seconds
	@State private var monitor: LoadMonitor

	var body: some Scene {
		Window("CPULoadMeter", id: "main") {
			MainView()
				.environment(monitor)
				.onGeometryChange(for: CGSize.self) { $0.size } action: { size in
					mainWindowWidth = size.width
					mainWindowHeight = size.height
				}
		}
		.windowStyle(.hiddenTitleBar)
		.defaultLaunchBehavior(isMainWindowOpenedAtLaunch ? .presented : .suppressed)
		.restorationBehavior(.disabled)
		.defaultWindowPlacement { content, _ in
			WindowPlacement(size: storedWindowSize ?? content.sizeThatFits(.unspecified))
		}

		Settings {
			SettingsView()
		}

		MenuBarExtra("CPULoadMeter", systemImage: "cpu") {
			MenuBarExtraMenu()
				.environment(monitor)
		}
	}
}
```

Three rules this arrangement must keep:

- **`Window` is declared before `MenuBarExtra`.** Otherwise the window is not presented at launch even when asked for.
- **The extra stays inserted.** Its presence in the menu bar is what lets the app outlive its window and what gives the window its Window-menu entry. No `isInserted` binding is offered, so the app never removes it; the user can (§2.4), and the app does not resist that.
- **The window's title is user-visible** in the Window menu, even though the window displays none.

There is no `import AppKit` and no app delegate.

**Remembering the window's size.** `restorationBehavior(.disabled)` makes the launch checkbox authoritative, and it also stops the system from saving the window's frame, so the app saves the size itself:

- The content reports its size through `onGeometryChange`, and the app stores the width and height in `UserDefaults`. They are optionals rather than zero sentinels: absent means "never shown", and the type says so.
- `storedWindowSize` is the stored size when both halves are present, and `nil` otherwise. `defaultWindowPlacement` places the window at that size, or else at the size the content asks for.
- The first-launch size (§2.5) is therefore not a constant computed ahead of layout, which would need the header's height before the header exists. It is the content's own ideal size: `MainView` has an ideal width of 480 pt and each `LoadView` an ideal height of 20 pt, and the header contributes its natural height.
- Within one run nothing more is needed: a closed window's object survives, hidden, and reopens as it was.

The `App`'s initializer creates the monitor with the stored period and the initial step count (§2.10); it stores the period again whenever the monitor's changes.

The menu bar extra receives the monitor now, unused, so that the later live graph is a change to one view rather than to the app's wiring.

*Rationale: B.1, B.8, B.17 (the first-launch size). Experiments: D.2.*

### 5.2 The menu bar extra's menu

`MenuBarExtraMenu` has two items: a button titled *Show CPULoadMeter* that calls `openWindow(id: "main")`, which opens the window or brings an open one to the front; and a `SettingsLink`.

With another app active, the button does not bring this app to the foreground (§2.4). SwiftUI's environment offers no action that activates an app, and the AppKit activation requests tried in its place were declined by the system, or granted only with a Finder window in front; they were rolled back, and the limitation stands for version 1 (§8).

*Rationale: B.1. Results: D.6.*

### 5.3 Main window layout

```
MainView            VStack(spacing: 0)
├─ HeaderView         natural height (.fixedSize vertical), full width
├─ hairline
└─ LoadStackView      VStack(spacing: 0), fills the remainder; reports its step count
   ├─ LoadView          flexible; minHeight 8; nothing but the plot
   ├─ hairline
   ├─ LoadView
   └─ …
```

There is no `ScrollView` anywhere. The window's minimum size emerges from the content's minimums through the default `contentMinSize` resizability. Equal division can land on fractional points, so adjacent LoadViews may differ in height by one pixel.

### 5.4 The header

`HeaderView` takes the processor name, the CPU count, the latest machine-wide `CPULoad` (optional), whether the last sample failed, and a binding to the period. The name is read once at launch.

The three whole percentages come from `UsagePercentages`, which rounds cumulatively: *busy* is user plus system rounded to the nearest whole percent; *user* is user rounded; *system* is busy minus user; *idle* is 100 minus busy. Every figure is therefore non-negative and the three always sum to 100.

*Rationale: B.5, B.17 (the rounding).*

### 5.5 LoadView

`LoadView` is a pure function of its input: it takes one CPU's `LoadHistory` as a plain value and draws it as one stroked path in a `Canvas`.

```swift
struct LoadView: View {
	let history: LoadHistory
	var lineWidth: CGFloat = 1

	var body: some View {
		Canvas { context, size in
			let steps = history.loads.reversed().prefix(Int(size.width / Self.stepLength)).enumerated()
			let path = steps.reduce(into: Path()) { path, step in
				let x = size.width - (CGFloat(step.offset) * Self.stepLength) - (lineWidth / 2)
				path.move(to: CGPoint(x: x, y: size.height))
				path.addLine(to: CGPoint(x: x, y: size.height * (1 - step.element.total)))
			}
			context.stroke(path, with: .color(.primary), lineWidth: lineWidth)
		}
	}

	nonisolated static let stepLength: CGFloat = 1
}
```

The drawing rules:

- **The walk starts at the bottom-right.** Step 0 is the newest load; each later step is one `stepLength` further left. `reversed()` puts the newest first, and `prefix` covers the frame or two during a live resize when the history has not yet caught up with the view.
- **The y-axis points down.** The bottom edge is `y = size.height`, and a full-height line ends at `y = 0`.
- **A line's center is a pixel boundary plus half the line width.** The right edge of step *k*'s line sits at `width − k × stepLength`, a whole point, and the center is half a line width to its left.
- **One path and one stroke** per LoadView per redraw.
- **`stepLength` is 1 pt. `lineWidth` defaults to 1 pt**, which tiles the steps into a solid silhouette; the default's final value is chosen by eye against the running app (§8). It is a parameter rather than a constant so that the rendering tests can exercise more than one width, and because the later menu-bar graph will want its own.
- **`stepLength` is `nonisolated`** because `LoadStackView` reads it inside `onGeometryChange`'s transform, which runs off the main actor.

*Rationale: B.3.*

### 5.6 The kernel readers

```swift
func readProcessorTicks() throws(MachError) -> [CPUTicks]
```

`readProcessorTicks()` calls `host_processor_info` with the `PROCESSOR_CPU_LOAD_INFO` flavor, copies each CPU's `processor_cpu_load_info` into a `CPUTicks` value with named fields, and returns the array. The failure is in the signature. The host port is obtained once and reused, rather than asked for on every call.

**The kernel allocates the reply buffer on every call, and this function frees it on every call.** The `vm_deallocate` is a `defer` inside this one function, unconditional, and the function returns a Swift array — so no unsafe pointer escapes, and no caller ever holds the pointer or the obligation. The buffer cannot be allocated once and reused; it is not the caller's to allocate.

`readProcessorName()` reads `machdep.cpu.brand_string` with `sysctlbyname` and returns `nil` if the read fails.

*Rationale: B.12. Prior art: C.8. Seed code: D.1.*

### 5.7 The load math

Given the previous and current ticks for one CPU:

```
busy  = (Δuser &+ Δsystem &+ Δnice)        each Δ by wrapping subtraction
total = busy &+ Δidle
load  = total == 0 ? 0 : busy / total      as CPULoad { user, system }; nice counts as user
```

- **Subtract in 32 bits, then widen.** Each Δ is a 32-bit wrapping subtraction (`current.user &- previous.user`), and only its result is widened for summing. The counters wrap, and this order is what makes a wrap harmless.
- **Sum the deltas; never difference a sum.** The machine-wide figure is these same per-CPU deltas summed across CPUs and divided once. It is not a second kernel call, and not an average of per-CPU percentages.
- **Zero elapsed ticks yield a zero load.**

`TickDelta` is these rules as a type (§4.1): constructing one *is* the wrapping subtraction, adding two *is* the sum, and a `CPULoad` can be made from nothing else.

*Rationale: B.5. Prior art: C.2, C.4.*

### 5.8 Scheduling

`LoadMonitor` owns one `Task` that loops: sleep until a deadline on a monotonic clock, sample, advance the deadline by the period. If the new deadline is already past, it is reset to *now + period*, so missed deadlines collapse into one sample. Changing the period cancels the task and starts a new one, which is the whole of "takes effect immediately". The deadline rule is the pure function `nextDeadline` (§4.1), and the sleep is the injected one (§4.2), so the loop itself has no branches.

The sample runs on the main actor. It moves off the main actor only if measurement says it should (§7, P7).

**Diagnostics.** The app writes three kinds of debug-level message with `os.Logger`, under its bundle identifier as the subsystem: one at launch, with the processor's name and the CPU count; one per sample, with numeric fields only — the sample's index, how late it was, how long it took, the CPU count, and the machine-wide user, system, and idle tick deltas; and one whenever the step count changes. They are ordinary diagnostics, present in every build; debug-level messages are not persisted and cost almost nothing when no one is listening. They are how the cadence, the cost, and the agreement with `top` are observed from a shell (§7).

*Rationale: B.9, B.17 (the diagnostics).*

### 5.9 The period control

`PeriodControl` is a composed combo box: a narrow `TextField` bound to a draft string, and beside it a borderless `Menu` whose items are `SamplingPeriod.presets`.

- **Commit** happens on Return (`onSubmit`) and when the field loses focus (`@FocusState`). The draft is parsed through `SamplingPeriod.init?(text:)`: either a period comes out, or the draft reverts to the current period.
- **A preset pick** sets the period directly and rewrites the draft.
- **The draft is a string**, not `TextField(value:format:)`, so that the parse and the reject-and-revert rule live in one visible place.

*Rationale: B.2.*

### 5.10 Settings and persistence

Four `UserDefaults` keys, through `@AppStorage`:

| Key | Type | Default | Read through |
|---|---|---|---|
| `isMainWindowOpenedAtLaunch` | `Bool` | `true` | directly |
| `samplingPeriodSeconds` | `Int` | `1` | `SamplingPeriod.init?(seconds:)`; an invalid stored value falls back to the default |
| `mainWindowWidth` | `Double?` | absent | with its partner; both present, or the first-launch size is used |
| `mainWindowHeight` | `Double?` | absent | as above |

All four are read and written by the `App` and the settings view. The monitor and the core touch no defaults (§4.2).

`SettingsView` is a `Form` with one `Toggle`. Neither the load history nor the window's position is persisted.

### 5.11 Colors

As tabulated in §2.13. There are no `colorScheme` checks anywhere; if the app ever needs one, something upstream is wrong.

### 5.12 Failure handling

When `readProcessorTicks()` throws, the monitor records the error, leaves its state untouched, and carries on. **The previous good sample stays as the baseline**, so the next success yields a load averaged over the longer interval. The one case that resets the baseline is a change in the CPU count, where the old sample no longer lines up. There are no alerts.

*Rationale: B.13.*

### 5.13 Accessibility

`Canvas` content is opaque to accessibility, so each `LoadView` carries an accessibility label ("CPU 3", using the CPU's index, which is its CPU ID) and a value (its latest load as a percentage).

## 6. Testing

swift-testing, with `@testable import CPULoadMeter`, hosted in the app. A test run launches the app, so a window and the menu bar symbol appear for its duration; the tests run inside the app's process, in its sandbox container, and share its real defaults. Tests run in the Debug configuration only.

**A test run is not the shipping sandbox.** The `test` action re-signs the Debug app with extra entitlements — `get-task-allow`, a read-only file exception for `/`, and Mach lookups for the test daemons — and a hosted run leaves the test bundle inside the app, in `Contents/PlugIns`; the XCTest and Testing frameworks are resolved from Xcode's own copies, not copied in. Neither exception covers a host-port call or a sysctl read, so the reader tests below still mean what they say; but the clean proof that the sandbox permits the kernel calls, and every check made by hand, uses a product of the plain `build` action — the Release build.

**The pure core** carries the valuable cases:

- **Delta math:** ordinary deltas; zero elapsed ticks; and counter wrap — a previous counter near `UInt32.max` and a current one just past zero must yield a small positive delta.
- **The machine-wide figure** equals the per-CPU deltas summed and divided once, not the mean of per-CPU percentages. The two differ whenever CPUs accrue unequal tick totals.
- **`CPULoad`** stays within its bounds.
- **`UsagePercentages`** always sums to 100 with no negative figure, including user 0.5% with system 99.5%, where rounding each independently would not.
- **`nextDeadline`:** the ordinary advance, and the collapse of missed deadlines.
- **`LoadHistory`:** fixed length under append; zero-fill at the *oldest* end on growth; oldest-first loss on shrink; identity on a same-size resize; a zero step count.
- **`SamplingPeriod`:** the boundaries 0, 1, 60, and 61, and unparseable text.
- **`MonitorState.advanced`:** first sample, steady state, and a change in the CPU count.

**The monitor**, driven through its injected reader and sleep: a failed read keeps the last good sample; a changed CPU count resets the baseline; a new period restarts the loop, which is asserted on the next deadline the monitor asks to sleep until. No test waits on a real clock.

**Hosting.** One test asserts that the tests are where they are supposed to be: inside the app's process, and inside its sandbox container.

**The two readers** get one smoke test each — at least one CPU comes back; a non-empty name comes back — and no more. Because the tests are hosted in the sandboxed app, these re-prove on every run that the sandbox permits the calls.

**One test stands in for an invariant the compiler cannot check.** "Every reply buffer is freed" is not expressible in the type system, so a runtime check guards it and says so: the test calls `readProcessorTicks()` a few thousand times and requires the physical footprint (`task_info`, `TASK_VM_INFO`) to grow by less than a bound well under what the leak would cost. The bound is wide, because the host process is busy; the test is proved able to fail by removing the `vm_deallocate` once.

**The drawing** is tested on its pixels. `ImageRenderer` renders a `LoadView` at a fixed size, at scales 1 and 2, and the tests compare the alpha of every pixel against the pattern §5.5 predicts: which pixels each step's line covers, that a zero load draws nothing, that the newest load is anchored to the right edge, and what a 0.5 pt line does at each scale. The reference alpha is measured from a full-height line rather than assumed. What these cannot see is where the canvas sits in the real window, which stays a check by eye (§7, P4). When validating against `top` by eye, note that `top` prints 76.06% as `76.6%`.

*Rationale: B.10, B.16, B.17. Prior art: C.2. Seed code: D.4.*

## 7. Bring-up verification

The design leans on some platform behavior that is recalled or documented but not yet observed in this app. Each such assumption is a check to run while bringing the app up, roughly in this order. P2 and P3 need only a skeleton app and come before any real code. Checks already settled by experiment are recorded in Appendix D; three of them are repeated here only to be re-confirmed in the real app.

| # | Check | Affects |
|---|---|---|
| **P2** | *Confirmed 2026-09-21 (D.6).* `host_processor_info`, the `sysctlbyname` read, and the menu bar extra all work inside the App Sandbox with the hardened runtime — shown on the **Release** product, by its launch message reporting the name and the CPU count with no sandbox denials logged, since a test run widens the sandbox (§6). If something is blocked: identify the denied operation from the sandbox's violation report, track down the entitlement for it, and then discuss. Turning the sandbox off is not the default fallback. | §2.1, §5.6 |
| **P3** | *Confirmed 2026-09-21, with one correction the design absorbed (D.6): the stored size is the window's content rect, including the hidden title bar's safe-area inset, or the window shrinks by that inset each relaunch; the first launch comes up one inset short of ideal.* The launch checkbox and the remembered size: `@AppStorage` works as the source of the launch behavior; `defaultWindowPlacement` is honored at every launch when no frame is saved, and sizes the first launch from the content's ideal size; a saved size round-trips without the window creeping each launch; `@AppStorage` accepts an optional `Double`; and a real Dock click with the box unchecked does what §2.12 says. The fallback, if `defaultWindowPlacement` disappoints, is `defaultSize` with a constant for the header's height. | §2.5, §2.12, §5.1 |
| **P1** | *Confirmed 2026-09-21 (D.6).* *Re-confirm with a real click:* closing the main window leaves the app running, and the Window menu lists and reopens the window. | §2.2, §2.3 |
| **P12** | *Confirmed 2026-09-21 (D.6).* Tests hosted in the app run at all. The settings (`TEST_HOST`, `BUNDLE_LOADER`) are the known part; the open part is whether the **hardened runtime** lets Xcode inject the test bundle into a sandboxed host, which no sibling project does. If it does not, the recourse to discuss is a Debug-only build-setting exception that leaves the sandbox, the hardened runtime, and Release untouched. Also: the core's declarations compile as `nonisolated` under the app target's `MainActor` default. | §3, §4.1, §6 |
| **P13** | *Confirmed 2026-09-21 except one item (D.6): the extra can be removed by command-drag, which the documentation allows, and doing so with no window showing quits the app, which the documentation says; both are accepted (D20). The others held.* `SettingsLink` works inside the extra's menu; the extra cannot be removed from the menu bar by the user; the traffic-light buttons remain under the hidden title bar, and the header sits clear of them; the About panel shows the icon, name, version, and copyright. | §2.3–§2.5, §5.2 |
| **P9** | *Failed 2026-09-21 and deferred (D19, D.6): selecting the item while another app was frontmost did not bring this app to the foreground; the bare `NSApplication.activate()` changed nothing; the cooperative `NSRunningApplication.activate(from:options:)` worked with a Finder window in front and with no other app's. Both were rolled back; the limitation is documented in §2.4, §5.2, and §8.* A window opened from the extra's menu comes forward while another app is active. | §2.4, §5.2 |
| **P14** | `onGeometryChange` delivers the width `LoadStackView` needs; if not, a `GeometryReader` does. A history read in a parent's `body` and passed down redraws the `LoadView` when it changes. | §4.2, §5.5 |
| **P4** | Strokes are crisp at 1× and 2× — the canvas's origin sits on a pixel boundary; a zero load draws nothing; unrounded heights do not leave soft top edges. Choose the final `lineWidth` here. | §2.8, §5.5 |
| **P5** | The period control commits on Return and on focus loss, rejects and reverts, and takes presets, as specified. | §2.11, §5.9 |
| **P6** | Sampling continues during live resize and menu tracking. Observe the cadence with the window closed and only the extra showing. Read from the per-sample log message (§5.8): intervals that match the period, and no gap beyond one and a half periods. | §2.2, §5.8 |
| **P7** | Redraw and sampling cost at full display width: the per-sample duration from the log, and the app's own CPU share from `top`, with the stored window width preset to the display's. Instruments where it helps. Decide whether sampling stays on the main actor. | §5.5, §5.8 |
| **P8** | *Confirmed 2026-09-21 (D.6).* *Re-confirmed by the regression test:* no leak from the kernel's reply buffer. | §5.6, §6 |
| **P10** | *With the later iteration, not version 1:* whether a `MenuBarExtra`'s label can host a live `Canvas`. The fallbacks are rendering the graph to an `Image` on each sample, or an `NSStatusItem`. | §8 |
| **P11** | *Re-confirm in the real app:* the machine-wide figure agrees with `top` running alongside, idle and under a known load. Do not expect agreement with `ps`, or with `top`'s per-process column; they measure something else. | §2.9 |

## 8. Deferred, and out of scope

**Decided later, against the running app:**

- **The stroke width.** It starts at 1 pt. A 0.5 pt stroke gives a lighter look — on a 2× display, a one-pixel line and a one-pixel gap. It is chosen by eye at P4.
- **The app icon.** A generic icon serves for bring-up. The real icon is a separate piece of work.
- **Activation from the menu bar extra.** *Show CPULoadMeter* does not bring the app to the foreground while another app is active (§2.4, §5.2). SwiftUI has no activation action; the AppKit requests tried — the bare `NSApplication.activate()`, and the cooperative `NSRunningApplication.activate(from:options:)` naming the frontmost app — were declined, or granted only with a Finder window in front, and were rolled back rather than pursued further for what is a tertiary behavior. The measurements are in B.1 and D.6, so that a later attempt starts from them.

**A later iteration:**

- **The live graph in the menu bar.** Version 1's extra is a static symbol. Whether a `MenuBarExtra` label can host a live `Canvas` is unknown (P10); the fallbacks are rendering the graph to an `Image` on each sample, or an `NSStatusItem`. If the app ever becomes menu-bar-only, the extra's menu gains a Quit item.

**Not in version 1:** anything about core kinds; per-CPU labels; separate colors for user and system time; per-process information; GPU or Neural Engine load; history persisted between launches; the window's position persisted; export; localizations beyond English, though strings go through the String Catalog machinery the project settings enable.

*Rationale: B.3 (stroke width), B.6 (core kinds), B.14.*

---

# Appendices

## Appendix A — Decision record

### A.1 Decisions

| # | Question | Decision | Decided by | Specified in | Rationale |
|---|---|---|---|---|---|
| **D1** | What does closing the main window do? | The app keeps running. The mechanism is an inserted `MenuBarExtra`; there is no app delegate. | You; mechanism by experiment | §2.2, §5.1 | B.1 |
| **D2** | Is a menu-bar graph in scope? | Planned. Version 1 ships a minimal extra — a static symbol with a short menu — and the live graph is a later iteration. | You | §2.4, §8 | B.1 |
| **D3** | What is a "pixel"? | Points. Whole-point steps and a stroked path, as the original app drew. | You | §2.8, §5.5 | B.3 |
| **D4** | What does "shifted past the left edge, it is gone" mean? | The history is exactly as long as the path has steps. Wider: zero-fill as the oldest. Narrower: drop the oldest first. | You | §2.10, §4.1 | B.4 |
| **D5** | How is the combo box built? | A `TextField` beside a `Menu` of presets, in pure SwiftUI. Invalid input is rejected and the field reverts. | You | §2.11, §5.9 | B.2 |
| **D6** | Core kinds, and per-core labels? | Nothing about core kinds is displayed anywhere. LoadViews carry no labels or indexes. Kernel order, implicit. | You | §2.6, §2.7 | B.6 |
| **D7** | "No title": a hidden title bar, or a title bar without text? | A hidden title bar. The window's title string is `CPULoadMeter`, with no spaces — the app's name. | You | §2.5 | B.7 |
| **D8** | Is the launch checkbox authoritative over window restoration? And a Dock click when it is unchecked? | The checkbox always wins (`restorationBehavior(.disabled)`), and the app saves and reapplies its own window size; position is not remembered. A Dock click showing nothing under an unchecked box is accepted for version 1. | You | §2.5, §2.12, §5.1 | B.8 |
| **D9** | Sample while the window is closed? | Continuously. | By implication of D2 | §2.2 | B.9 |
| **D10** | On a period change: keep or clear the history? Persist the period? Default? | Keep the mixed history; persist; default 1 s, which is also `top`'s default interval. | You | §2.11 | B.9 |
| **D11** | Target structure? | Two targets: `App`, and a `Tests` bundle hosted in it using `@testable import`. No framework. | You | §3.1, §6 | B.10 |
| **D12** | Plot color; separators? | `Color.primary`; hairline separators. | You | §2.7, §2.13 | B.14 |
| **D13** | Content and wording of the machine-wide line? | `top`'s three-way form and wording: `CPU usage: 8% user, 4% system, 88% idle`. | You | §2.6 | B.5 |
| **D14** | Intel support? | Supported, untested, with no special-casing. Built universal, like the siblings. | You | §2.1 | B.14 |
| **D15** | The app icon? | Deferred by nature: generic for bring-up. | — | §8 | B.14 |
| **D16** | App Sandbox and hardened runtime? | On. If the sandbox blocks a kernel call, the first recourse is to track down the appropriate entitlement, and then to discuss — not simply to turn the sandbox off. | You | §2.1, §7 (P2) | B.11 |
| **D17** | Stroke width and step length? | Deferred by nature: a 1 pt step, and a stroke starting at 1 pt, chosen by eye against the running app. | — | §5.5, §8 | B.3 |
| **D18** | The version-1 extra's symbol and menu? | The `cpu` symbol; *Show CPULoadMeter* and *Settings…*; no Quit item. | You | §2.4, §5.2 | B.1 |
| **D19** | *Show CPULoadMeter* did not bring the app to the foreground (P9). Activate through AppKit, or not? | Not for version 1: accept the behavior and document it as a known limitation; revisit later. Two AppKit forms were tried first and rolled back — the bare `NSApplication.activate()`, which changed nothing, and the cooperative `NSRunningApplication.activate(from:options:)`, which worked only with a Finder window in front. The pure-SwiftUI principle stands unbroken. | You | §1, §2.4, §5.1, §5.2, §8 | B.1, D.6 |
| **D20** | The extra can be removed by command-drag, and removing it with no window showing quits the app (P13). Prevent it? | Accept it and document it. SwiftUI offers no way to forbid the removal; re-inserting through an `isInserted` binding was the SwiftUI-only alternative, and an AppKit status item the full-Cocoa one. | You | §2.4, §5.1 | B.1, D.6 |

### A.2 Defaults adopted without discussion

These were offered as defaults marked *(proposed)*, to be vetoed, and were not. They are now part of the specification. They are listed so that they remain identifiable as defaults rather than as decisions that were argued for.

| Default | Specified in |
|---|---|
| A baseline is taken at launch; the first load arrives one period later; until then the graphs show their initial zeros. | §2.9 |
| Zero elapsed ticks yield a zero load. | §5.7 |
| Nice ticks count as user. | §2.9, §5.7 |
| The processor's name comes from `machdep.cpu.brand_string`; "Unknown CPU" when it cannot be read. | §2.6, §5.6 |
| Line heights are not rounded; the scale is fixed at 0–100%. | §2.8 |
| The minimum LoadView height is 8 pt; the minimum width is the header's natural width. | §2.5 |
| The first-launch size is 480 pt wide with 20 pt per LoadView. | §2.5 |
| A failed sample shows `CPU usage unavailable`; sampling retries each period; there is no alert. | §2.15 |
| Each LoadView has an accessibility label and value. | §2.14 |
| Missed timer deadlines collapse into one sample. | §2.16 |
| English only, with strings going through the String Catalog machinery. | §8 |
| The default menus are left untouched. | §2.3 |
| The header shows whole percentages. | §2.6 |
| A typed period commits on Return or on loss of focus; there is no beep. | §2.11 |
| `LoadMonitor`'s tick reader is passed in. This was marked *(proposed)* when the specification was declared decided. It is folded in because the style guide's Testability section — "pass collaborators in rather than reaching out for them" — asks for it, and because it costs one line. | §4.2, §6 |
| The buffer-leak regression test. | §6 |
| **Added while writing the clean version, and not previously discussed:** before the first load is available the header's second line reads `CPU usage: —`. The earlier drafts specified the failure text but not this initial state. | §2.6 |

### A.3 How the document got here

- **The loose spec** (2026-09-18). A bullet list describing a window-only SwiftUI app with a combo box, a pixel-scrolling graph, and a header giving the number of cores of each type.
- **Draft 1** (2026-09-18). An analysis of the loose spec — five places where it collided with SwiftUI, twelve ambiguities, and a table of gaps — with sixteen decisions to be made.
- **Draft 2** (2026-09-18). The five conflicts and the core-labelling question settled: a minimal menu bar extra in version 1; the combo box composed in pure SwiftUI; drawing in points with a stroked path, as the original; the history exactly as long as the path has steps; nothing about core kinds displayed.
- **Draft 2, annotated** (2026-09-18). How `top`, `ps`, and the kernel handle the same problems, read from Apple's source (now Appendix C). Four things changed as a result: the counter-wrap claim became source-backed rather than assumed; failure handling got simpler; the machine-wide line took `top`'s wording; and the agreement-with-`top` check (P11) was added. Then the question of the kernel's reply buffer was settled (C.8): allocated by the kernel on every call, freed by the caller on every call.
- **Draft 3** (2026-09-18). D7, D8, D10, D12, D13, D14, D16, and D18 decided, together with the rule for invalid period input.
- **D11** (2026-09-21). Two targets and `@testable`; no framework. The discussion produced two new sections of the style guide, *Proportionality* and *Testability*.
- **The clean specification** (2026-09-21). The specification restated cleanly, with the reasoning moved to these appendices, and brought into the repository as `Design.md`. The earlier drafts were working files and are not kept.
- **Implementation planning** (2026-09-21). Planning the build found two errors in the clean version, settled the question it had left open about the monitor's clock, and added the means of verifying the app without watching it. The changes are listed in A.4.
- **Bringing up the scaffold** (2026-09-21). The first checks against the running app, in D.6. The automated ones (P2, P8, P12) and most of the hand checks (P1, P3, P13) held; the stored window size needed the hidden title bar's safe-area inset added; P9 failed, two AppKit activation requests were tried and rolled back, and the behavior was accepted as a known limitation for version 1 (D19); the extra proved removable and its removal was accepted (D20).

### A.4 What planning the implementation changed

Planning the build (2026-09-21) surfaced these. They were put to you as a list with the implementation plan and approved with it. None reopens a decision in A.1. The reasoning is in B.17.

| Change | Kind | Specified in |
|---|---|---|
| The header's percentages round cumulatively — busy, then user, system as the difference, idle as the remainder. | **Correction of my own error.** The rule I added while writing the clean version (round user and system; idle is the remainder) could yield idle = −1. | §4.1, §5.4 |
| `TickDelta`: the wrap-safe difference between two samples, summable; `CPULoad` is built from one. | Correction. §4.1 said `CPULoad`'s only initializer took two `CPUTicks`, which cannot produce the machine-wide figure from summed deltas. | §4.1, §5.7 |
| `LoadMonitor`'s sleep is passed in beside its reader; the deadline rule is a pure function; the monitor persists nothing. | The question the clean version left "to be weighed when the monitor is written", weighed. | §4.1, §4.2, §5.8, §5.10 |
| Three debug-level log messages: at launch, per sample, and on a step-count change. | Addition. | §5.8, §7 |
| The first-launch window size comes from the content's ideal size, through `defaultWindowPlacement`, rather than from a constant through `defaultSize`. | Change of mechanism; the behavior in §2.5 is unchanged. | §5.1, §7 (P3) |
| A launch with no window starts from the step count of the stored window width. | Refinement of §2.10, which covered only "no window has ever been open". | §2.10 |
| `LoadView`'s line width is an initializer parameter with a default. | Refinement. | §5.5 |
| A change in the CPU count replaces the histories with zeros. | Detail the clean version left unsaid. | §4.1 |
| The host port is obtained once. | Detail. | §5.6 |
| A test run is not the shipping sandbox; P2's proof and every check by hand use the Release build. | Finding. | §6, §7 (P2, P12) |
| The drawing is tested on its pixels. | Addition to the testing approach; §6 had said only "verified by eye". | §6 |

## Appendix B — Rationale

The reasoning behind the design, by topic. Claims here carry the evidence labels defined in Appendix E.

### B.1 App lifetime, the menu bar extra, and the Window menu

**The problem.** The loose spec had a Window-menu item to show the main window and a setting that could launch the app with no main window, so the app had to keep running with no window open. Apple's `Window` documentation says: *"If your app uses a single window as its primary scene, the app quits when the window closes."* **[D]** The documentation for `WindowGroup` and `DocumentGroup` says nothing about app lifetime **[D, by omission]**. And the loose spec's opening paragraph said the original app drew "in the menu bar", while the spec itself described only a window. You confirmed that the menu bar graph is planned, that running with no windows open is a requirement, and you suggested exploring how document-based apps stay alive.

**The experiment.** A throwaway SwiftUI app in eleven variants (D.2). Each closes its own main window with `performClose(_:)` — documented to *"Simulate the user clicking the close button"* **[D]** — logs whether the process is still alive, and then looks for and invokes the window's entry in the Window menu. All results **[O]**.

| Variant | Scenes | On closing the main window | Window-menu entry for the main window |
|---|---|---|---|
| A (control) | `Window` | **quits** within 30 ms, as documented | none |
| A2 | `Window`, `Settings` — the draft-1 shape | **quits** | none |
| B | A2 + an app delegate returning `false` from `applicationShouldTerminateAfterLastWindowClosed(_:)` | survives; the delegate *was* consulted | **none, open or closed** — the window is unreachable once closed |
| C | `MenuBarExtra`, `Window`, `Settings` | survives — but the window is not shown at launch | present; invoking it opened the window |
| **D** | `Window`, `Settings`, `MenuBarExtra` | **survives, with no delegate** | **present while closed; invoking it reopened the window** |
| E | `WindowGroup`, `Settings` | survives, with no delegate | listed only while open |
| I | D with the extra declared but not inserted (`isInserted: .constant(false)`) | **quits** | none |

Four further variants — G, H, J, and K — add scene modifiers to these. They are tabulated in D.2 and bear on B.8.

What this established:

- **Your instinct about document apps was right, and the cause is broader than documents.** Variant E shows that a plain `WindowGroup` app also stays alive with no windows. Staying alive is the default; the lone `Window` is the exception SwiftUI carves out. So the document machinery is not needed to escape it, and it would be expensive to carry: *"Every document-based app must include"* `CFBundleDocumentTypes`, the document type must conform to `FileDocument` or `ReferenceFileDocument`, and the scene brings *"document-based menu support"* **[D]** that would all have to be suppressed.
- **The delegate route (B) works but costs two pieces of AppKit scaffolding**, because SwiftUI lists no Window-menu entry for a *primary* `Window`: the delegate itself, plus a hand-built menu command — an addition the spec wanted to avoid.
- **An inserted `MenuBarExtra` — which you wanted anyway — fixes both at once with no AppKit.** SwiftUI then treats the `Window` as an ordinary singleton: it survives close, gets its Window-menu entry, and reopens from it. Declaration order does not affect survival (C vs D), only launch: with the extra first, the window is not shown at launch, matching the documented `automatic` rule that *"a scene will only present itself if it is the first scene defined by the app."* **[D+O]** So the `Window` is declared first.
- **It is the extra's presence in the menu bar that counts, not its declaration** (variant I). One coherent rule explains every row: SwiftUI quits when the last piece of UI goes away.

**The Window-menu item** therefore needs no code. The system adds the entry, keeps it while the window is closed, and reopens the window from it **[O]** (variants D, H), so the spec's "no additions" holds. The documentation agrees: the system lists the window by its title *"in the list of available singleton windows that the Windows menu displays automatically"*, and `openWindow(id:)` *"brings the open window to the front"* if it is already open **[D]**.

**What the extra shows.** The `cpu` symbol, and a menu of *Show CPULoadMeter* and *Settings…*. There is no *Quit*: SwiftUI has no terminate action **[R]**, and this is a regular app whose application menu and Dock icon already offer Quit. If the app ever becomes menu-bar-only, a Quit item becomes necessary, and it is the one AppKit call worth making. Whether a window opened from the extra's menu comes forward while another app is active is P9; if it does not, activation is an AppKit call, and that would be the moment to weigh the pure-SwiftUI principle against the behavior. It did not **[O]** (your check, D.6), and the moment came. SwiftUI has no such action: its environment's actions are `dismiss`, `dismissWindow`, `newDocument`, `openDocument`, `openSettings`, `openWindow`, `pushWindow`, `refresh`, `rename`, and `resetFocus` **[O]** (the SDK's interface, D.6), and `OpenWindowAction`'s page promises only to bring a window to the front **[D]**. `NSApplication.activate()` is documented as a request that *"doesn't guarantee app activation"*, with cooperative activation expecting the other app to yield first **[D]**. You chose the one call over a URL-scheme round trip and over accepting the behavior (D19), and the bare call changed nothing **[O]** (your second check). A probe from inside the app, with a Finder window put in front, then measured the routes (D.6): `NSApplication.activate()` was declined in every cycle, as was the deprecated `activate(ignoringOtherApps: true)`; `makeKeyAndOrderFront` moved the window to second place, behind the active app's key window — the method's documentation says a window *"can't be moved in front of the key window unless it and the key window are in the same application"* **[D+O]**; `orderFrontRegardless()` put the window on top with the app still inactive **[D+O]**; and `NSRunningApplication.current.activate(from: frontmost, options: [])` returned `true` and activated the app in every cycle, three in one process, making the window key with no window call at all **[O]**. That form is the *"context"* the macOS 14 release notes say an app may give an activation request *"in cases where a more deterministic result is desired"* **[D]**; they promise nothing beyond a yield, and the frontmost app here yields nothing, so the grant was observed, not guaranteed. The Launch Services route, opening the app's own bundle, was also tried and was confounded: it activated the other instance of the same bundle that was running from Xcode. The re-check from the menu then showed the grant was Finder's doing, not the form's: the cooperative request works with a Finder window in front and with no other app's, Xcode's included **[O]** (your third check, D.6). The probe had used Finder as its only rival, so its 3-for-3 measured a special case. At that point you called the behavior tertiary and had both AppKit forms rolled back; version 1 documents the limitation instead (D19, §8), and the measurements stay here for whoever returns to it. Routes not tried: a URL scheme opened through Launch Services, which activates the handling app the way the Dock does; `orderFrontRegardless()`, which puts the window on top without activating the app.

**The user removing the extra.** Version 1 binds no `isInserted`, so I believed the extra could not be removed **[R]**. That was wrong: you command-dragged it out **[O]** (D.6), and the documentation both allows it and names the consequence — *"An app that only shows in the menu bar will be automatically terminated if the user removes the extra from the menu bar"* **[D+O]**, which is what happened with the window closed. SwiftUI exposes no way to forbid the removal; the only handle is the `isInserted` binding, documented as set to `false` on removal and as showing the item when set to `true` **[D]**, so a binding forced back to `true` could re-insert it — though whether the termination comes first is unobserved. You chose to accept the removal and document it (D20). If a "show in menu bar" setting is ever added, then with the extra hidden, closing the window quits the app again **[O]** (variant I) — which is arguably correct, since no UI would remain.

### B.2 The period control

**SwiftUI has no combo box.** A combo box is an editable text field with an attached list. SwiftUI's `Picker` has no free-text entry and `TextField` has no list. A case-insensitive search of the macOS 27 SDK's SwiftUI module interface for `combobox` finds nothing, while the same search pattern finds `Picker` **[O]**. Draft 1 proposed bridging AppKit's `NSComboBox` through `NSViewRepresentable`. You pointed out that a combo box is basically just an editable text field with a pop-up menu that sets preset values for it, which is a reasonable way to avoid bringing in Cocoa — so it is a `TextField` beside a `Menu`, with no AppKit bridge.

**Reject and revert, rather than clamp.** The loose spec said input should be "checked and only allowed in the range of 1 to 60", without saying what happens to `0`, `61`, `abc`, or `2.5`. Rejecting means a typo can never silently become a setting; clamping would leave the period at a value the user did not type, and `2.5` would need a rounding rule. There is no beep because the system beep is an AppKit call.

**The draft is a string, not `TextField(value:format:)`.** The formatted variant keeps its old value on a parse failure without telling the caller **[R]**; owning the parse keeps the reject-and-revert rule in one visible place. The modifier details (`menuStyle`, `menuIndicator`, focus handling) are **[R]** and are settled by hand at P5.

### B.3 Drawing: points, a stroked path, and crispness

**"Pixel" is not SwiftUI's unit.** SwiftUI lays out in points; on a 2× display one point is two device pixels. The loose spec said lines were "one pixel thick" and history shifted "by one pixel". SwiftUI exposes the device pixel through the `pixelLength` environment value **[D]**, and draft 1 proposed honoring "pixel" literally, with columns as filled rects one device pixel wide.

**What the original did, and what the design adopts.** You recalled that the original built one `NSBezierPath` of vertical lines with `move(to:)` / `line(to:)`, walking the view's bottom edge leftward from the bottom-right corner in whole-unit steps that were not necessarily 1:1 with device pixels, and stroked it at a width of about 0.5 in the menu bar — which might need to be wider for a resizable window. The design adopts exactly that: whole-point steps, a single stroked path, and the stroke width as a constant to be tuned by eye. `NSBezierPath`'s `move(to:)` / `line(to:)` become SwiftUI `Path`'s `move(to:)` / `addLine(to:)`, and `stroke()` becomes `GraphicsContext.stroke`. `Canvas` is *"A view type that supports immediate mode drawing"* **[D]**, the closest SwiftUI analogue to overriding `draw(_:)`.

**Why the line's center sits where it does.** A stroke straddles its center line, so where the center is put decides whether the line is crisp. The rule is *center = a pixel boundary + half the line width*. The right edge of step *k*'s line sits at `width − k × stepLength`, a whole point and therefore a pixel boundary, and the center is half a line width to its left. With a 1 pt step, a 1 pt stroke tiles edge to edge into a solid silhouette. A 0.5 pt stroke gives, on a 2× display, a one-pixel line and a one-pixel gap — the original's lighter look. Centered on the whole-point x instead, that same 0.5 pt stroke would smear across two device pixels at half intensity. On a 1× display 0.5 pt is half a pixel and can only render dim. Crispness also assumes the canvas's own origin sits on a device-pixel boundary **[R]**, which P4 checks by magnifying a screenshot.

**The y-axis points down**, the reverse of AppKit's default, which the original was drawn against. The bottom edge is `y = size.height`, and a full-height line ends at `y = 0`, so "rising from the bottom" is a subtraction.

**Zeros are invisible.** A zero load is a zero-length segment, which the default butt line cap draws as nothing **[R]**. That is what makes zero-filling the history look like blank space.

**No vertical rounding.** As in the original, a line's height is `load × view height` exactly, and a fractional top edge anti-aliases. To be revisited by eye at P4 if top edges look soft.

**A history is passed down as a value.** `LoadView`'s parent reads the history from the monitor in its `body` and passes it down, so the read that Observation must track happens in a `body`, which is where I understand SwiftUI to track it, rather than inside the canvas's renderer closure, where I am unsure it does. Both halves of that are **[R]**; passing the value down is correct under either.

**Cost.** Per sample: cores × steps line segments — 24 × 3,200 ≈ 77 k on this machine with the window 3,200 pt wide, at most once a second. (3,200 is the screen width that appears in the probes' saved window frames; that I am reading that string's layout correctly is **[R]**.) I expect that to be comfortable for `Canvas` **[R]**; P7 measures it.

**Alternatives considered.** A `Shape` view — the same geometry, retained rather than immediate, and a good thing to try later for comparison. Swift Charts, which defeats the purpose. An `NSViewRepresentable` around a custom `NSView` scrolling its own backing store — closest to the original and to the loose spec's literal wording, but it leaves SwiftUI, and it loses the rescaling on a height change.

### B.4 History semantics

**The loose spec described a bitmap; SwiftUI redraws from a model.** "Shifted past the left edge, it is gone" is how a view scrolling its own backing store behaves. `Canvas` is immediate-mode, so every redraw rebuilds the picture from stored samples, and "gone" had to be restated as a rule about the sample history. Draft 1 recommended a fixed capacity of 8,192 samples per core, independent of the view, so that the model would never depend on view geometry and a resize would never destroy data.

**What you decided.** In the original, the retained data was always equal in length to the number of steps in the bezier path: cycling in a new value is just shifting the storage array and inserting the new value, which is quick, and the code that built the path operated on whatever was stored. You are not concerned by a window resize needing to resize the retained data: when the size grows, the new values are zeros and are the oldest data; when it shrinks, data is discarded by age, oldest first.

**What that buys.** `LoadHistory` has no "partially full" state, which removes a case from everything that touches it: the draw code never asks how many loads there are, and blank graph area is simply zeros. Shifting an array of a few thousand elements once a second per core is, as you said, quick; the standard library has no deque, and adding a package for this would invert ALL-4's intent. And one pleasant consequence of redrawing from stored loads either way: when the view's *height* changes, the whole history rescales correctly, where a scrolled bitmap would keep old columns at their old scale.

**The step count flows up from the view.** This is the one place the model depends on view geometry, by your design. `LoadStackView` measures its width with `onGeometryChange` (or a `GeometryReader` if that proves unsuitable **[R]**) and reports a step count to the monitor. All LoadViews share one width, so there is one step count. With no window open the monitor keeps the last reported count; before any window has ever reported — a launch with the box unchecked — it uses the first-launch window's step count.

### B.5 What "load" is, and how it is reported

**The requirement.** You asked that whatever this app does be consistent with how `top` and `ps` answer the question of what "load" is, and with others in the OS such as Activity Monitor. Appendix C is the investigation that followed. The short of it: this app's figures are `top`'s *CPU usage* figures and agree with them; `ps` measures something else and cannot be matched (C.3); Activity Monitor is closed source, and imports the same kernel call this app uses (C.5).

**The word.** `top` shows two unrelated figures. *Load Avg* is `getloadavg()`: *"the average number of jobs in the run queue."* *CPU usage* — user, sys, and idle percentages from tick counters — is the quantity this app plots. The kernel itself calls the tick data "load" (`PROCESSOR_CPU_LOAD_INFO`; libtop's `/* Get CPU load. */`), so the app's name is well-founded; but a reader fluent in `top` will hear "load" as the run-queue average **[S]** (C.2).

**The definition.** `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO` returns, per CPU, *"number of ticks while running... in the given mode"* for four modes: user, system, idle, nice **[D]** (`mach/processor_info.h`, `mach/machine.h`). These are counters, so a load is a difference between two samples: `busy = Δuser + Δsystem + Δnice`, and `load = busy / (busy + Δidle)`. This is `top`'s definition exactly: user = USER + NICE ticks, sys = SYSTEM, idle = IDLE, each divided by their sum, all as deltas against the previous sample (`globalstats.c:321–350`) **[S]**. In a run under load, this design's arithmetic and `top`'s formula gave identical results to the tick, and `top`'s own printed samples sat beside them **[S+O]** (C.6). Per-process `%CPU` — in `top`'s process list and in `ps` — is a *different* quantity, measured against wall-clock time or taken from the scheduler, and will not match a per-core figure (C.2, C.3).

**The first sample.** One sample is a baseline, not a load. `top` does the same — a baseline at initialization (`libtop.c:360–364`) — and its man page owns up to the consequence: *"the first sample displayed will have an invalid %CPU … as it is calculated using the delta between samples."* (`top.1:141–142`) **[S]**. `top` prints that invalid first sample anyway; this app has the luxury of not plotting it.

**Counters are 32-bit and they wrap.** `unsigned int` in the header **[D]**; in the kernel each is a 64-bit quotient cast to `(uint32_t)`, which keeps the low 32 bits (`processor.c:810–814`) **[S]** — so they wrap, and do not saturate. This was my assumption in draft 2 and is now read from source, though not observed: at 100 ticks per second per CPU, one CPU's counter takes about 497 days in one mode to wrap. Wrapping subtraction (`&-`) on the 32-bit values gives the right delta across a single wrap. **A weakness of `top`'s not to copy:** it widens the counters to 64 bits *before* subtracting (`globalstats.c:317–340`), so across a wrap its difference underflows and one refresh shows nonsense **[S]**. Hence the rule: subtract in 32 bits, then widen. Widen first, as `top` does, and a wrapped counter yields a difference near 2⁶⁴.

**Zero elapsed ticks** make the ratio 0/0. `top` guards the same division — `if (0 == totalticks) return;` — and so leaves its previous line on screen (`globalstats.c:345–346`) **[S]**. A graph has to plot something at every step, and a zero is a more honest rendering of "no information" than a repeat of the last value, so this design plots zero; it is a deliberate difference. In practice it should not arise: every CPU accrued 100 ticks per second here whether busy or idle **[S+O]**.

**Nice needs no decision.** The kernel reports `CPU_STATE_NICE` as zero, always (`processor.c:883`, `host.c:521`) **[S]**; its raw counter read 0 on all 24 CPUs here **[S+O]**. `top` adds it to user regardless, and so does this design — harmless, and identical to `top` if a future kernel ever populates it.

**Resolution is 1% per core per second.** Ticks are not statistical samples: the kernel accounts CPU time exactly in 64 bits, then divides by 10 ms — *"BSD expects a tick to represent 10ms"* (`clock.c:392–396`) **[S]**. So a one-second sample of one core is a whole number of hundredths. That is ample for a graph, and it is a quiet argument for the one-second floor on the period: at a tenth of a second a core's load could take only eleven values.

**The machine-wide line.** It is `top`'s `CPU usage: 2.50% user, 17.61% sys, 79.88% idle`. `top` gets it from `host_statistics(HOST_CPU_LOAD_INFO)`, the machine-wide aggregate — which in the kernel is nothing but a loop over every processor calling the same helper that fills this app's per-CPU values (`host.c:503–536`) **[S]**. Summing this app's per-CPU deltas therefore reproduces `top`'s figure by construction, and did so to the tick in two runs **[S+O]** (C.6). Two consequences:

- **Sum the per-CPU deltas; never difference a sum.** The 32-bit aggregate wraps N times sooner than any one CPU's counter — about every 20.7 days of uptime on this 24-CPU machine — and `top`'s arithmetic does not survive it (C.2). Summing wrap-safe per-CPU deltas gives the identical result with no early wrap, and needs no second kernel call.
- **`top`'s wording and three-way split** were chosen over a bare "Load", given what "load" means to a `top` user. Activity Monitor's CPU pane shows the same three figures **[R]**. The alternatives were `Load: 12% (user 8%, system 4%)` and a single figure.

**Whole percentages.** A machine-wide figure over one second on this machine rests on 2,400 ticks, but nobody reads a header to the hundredth. `top` prints hundredths, and prints them unpadded — 76.06% as `76.6%` (C.2) — so whole percentages also sidestep copying a format that misleads.

### B.6 Core kinds, and labelling the LoadViews

The loose spec wanted the header to say how many cores of each type the machine has, and you later asked for each LoadView to carry a small label giving the core's kind and number.

**The counts are documented; the per-CPU mapping is not.** `hw.nperflevels` is *"The number of types of general purpose processor cores in the SoC"* and `hw.perflevelN.logicalcpu` gives the count per type, with *"Lower values of N indicate higher-performance core types."* **[D]** But a label needs a CPU-index-to-kind mapping, and I could not find a documented one: `PROCESSOR_BASIC_INFO` returns identical `cpu_type` and `cpu_subtype` for all 24 CPUs **[O]**; no sysctl lists kinds per CPU **[O]**; `hw.perflevelN.name` returns `Performance` / `Efficiency` here **[O]** but appears in neither Apple's "Determining system capabilities" page nor `man 3 sysctl` **[U]**; and the only per-CPU source found was the device tree's `cluster-type` property, which is readable from pure Swift but **[U]**, as is the correspondence between a device-tree node `cpuN` and the kernel's index N. On this machine the kernel's order interleaves kinds: E for CPUs 0–3 and 12–15, P for 4–11 and 16–23 **[O]**.

**What you decided.** Since the kind cannot be reliably determined, leave it out entirely — no P/E information anywhere, header included — and drop the index as well, since it is uninteresting and already implied by position. LoadViews stack in the order the kernel returns them, unlabelled. *If it is ever wanted back: the per-kind counts, unlike the per-CPU mapping, come from documented sysctls.*

**"The ordering can be implicit" is on firm ground.** Apple's kernel test suite has a test for exactly this call, `processor_cpu_info_order` — *"ensure host_processor_info iterates CPU in CPU ID order"* — which asserts *"CPU ID must equal array index"* (`xnu/tests/processor_info.c:116–145`) **[S]**. Here, `slot_num` equalled the array index on all 24 CPUs **[S+O]**. So a LoadView's position in the stack *is* its CPU ID. Neither `top` nor `ps` says anything about core kinds either (C.2, C.3).

### B.7 The window's title

"Displays no title" had two readings. `.windowStyle(.hiddenTitleBar)` *"hides both the window's title and the backing of the titlebar area, allowing more of the window's content to show."* **[D]** The traffic-light buttons remain **[R]**. The other reading keeps the title bar and removes only its text: `.toolbar(removing: .title)`, macOS 15+ **[D]**. Either way the window needs a title *string*, because the Window menu lists it by that title **[D+O]**. You chose the hidden title bar, and corrected my proposed "CPU Load Meter" to `CPULoadMeter`, no spaces — the name of the app.

### B.8 The launch checkbox, window restoration, the window's size, and the Dock

- **A run-time value works.** `defaultLaunchBehavior(isSuppressed ? .suppressed : .presented)` was honored in both directions **[O]** (variant H). The probe took its value from an environment variable; `@AppStorage` as the source is the small remaining check (P3).
- **Restoration outranks it.** Launch behavior applies *"in the absence of any previously saved state"* **[D]**. `restorationBehavior(.disabled)` makes the checkbox authoritative **[D]**.
- **But disabling restoration also stops the window's frame being saved.** In variants differing only in that modifier: without it, an `NSWindow Frame main` entry was written to the app's defaults; with it, nothing was **[O]** (variants J vs K, D.2). The documentation does not mention this. So an authoritative checkbox costs the window its remembered size and position, unless the app persists its own size — position is not readable in pure SwiftUI **[R]**.
- **Under `.suppressed`, a Dock click does not show the window.** Documented: the launch behavior *"will also be used to determine which scene is presented when clicking on the icon of a running application with no visible windows."* **[D]** Observed with a self-sent reopen Apple event standing in for the click: under `.presented`, or with no modifier, a closed window came back; under `.suppressed`, nothing appeared **[O]**. That the self-sent event is equivalent to a real Dock click is **[R]**. Overriding this needs an AppKit delegate, against the pure-SwiftUI principle; the menu bar extra's menu and the Window menu remain as routes to the window.

**What you decided.** Offered three courses — leave restoration alone (which I recommended, recalling that macOS's default "Close windows when quitting an application" setting would make the checkbox effective anyway **[R]**), the checkbox always wins, or the checkbox wins and the app saves its own size — you chose the third: launch is fully predictable, the app stores and reapplies the window's last size, and the lost *position* is accepted as the price. A Dock click showing nothing under an unchecked box is accepted for version 1, to be confirmed with a real click and revisited only if it proves annoying in use.

**The size persistence.** `defaultSize` should apply at every launch precisely because the system has saved no frame to override it. Within one run nothing is needed: a closed window's object survives, hidden, and reopens as it was **[O]** (variants B, D, H). Three parts are **[R]** and belong to P3: that `defaultSize` is honored on every launch when no frame is saved; that the size `onGeometryChange` reports and the size `defaultSize` takes are the same measure, so a saved size round-trips without the window creeping by a title bar's height each launch; and that `@AppStorage` accepts an optional `Double`.

**The scene arrangement** in §5.1 is exactly probe variant H's — launch behavior chosen at run time, restoration disabled, `Window` first, extra last — which survived closing its window, kept its Window-menu entry, reopened from it, and honored the launch behavior in both directions **[O]**. What H did not have is the size persistence.

### B.9 The period, continuous sampling, and scheduling

**The default.** `top`'s default interval is 1 second (`preferences.c:75`) and its default mode is *"CPU usage since the previous sample"* (`top.1`; `preferences.c:70`) **[S]** — this design's default period and its delta rule. Activity Monitor's update-frequency choices are 1, 2, and 5 seconds **[R]**, the first three of the spec's five presets.

**One step is one sample, not one second.** After the period changes from 1 s to 30 s, the history holds steps of both kinds with no visible boundary. The alternatives were to clear the history on a change, which loses what you were looking at each time you touch the control, or to insert a marker step, which adds a second kind of entry to the history model. You chose to keep the mixed history; this is presumably how the original behaved.

**Sampling is continuous**, by implication: a menu bar graph with no windows open requires it, so the sampler runs for the life of the process. App Nap may throttle timers **[R]**; because a load is a delta over whatever interval actually elapsed, late samples are still correct, merely sparser. The reason is structural, and `top` relies on it too: the denominator is *ticks*, not wall-clock time, so a late timer changes which interval is averaged but cannot bias the ratio. `top` timestamps its samples only because its per-*process* figure divides by wall time (`cpu.c:74–81`); its machine-wide line needs no clock at all **[S]** (C.2).

**`Task` and `Clock`, rather than `Timer`.** Both are first-party; the task's cancellation is structural, and it has no run-loop-mode behavior to reason about. A default-mode `Timer` pauses during live resize and menu tracking **[R]** — precisely when you are watching the graph. P6 checks that the task-based loop does not share that problem, and what the cadence looks like with the window closed. `top`'s loop is the same shape — sleep, shift current to previous, read (`libtop.c:467–469`) **[S]**. The sample itself is one Mach call plus a few hundred integer operations, which is why it starts on the main actor.

**Sleep and wake.** The ticks need no special handling. The kernel measures idle with `mach_absolute_time()` (`recount.c:1241–1257`) **[S]**, a clock that *"does not increment while the system is asleep"* **[D]** — so a sample spanning a sleep sees only the awake time on either side. Only the timer needs care, which is the collapse rule.

### B.10 Target structure: no framework, and `@testable`

Draft 3 recommended a third target, `CPULoadMeterCore.framework`, so that tests could import the logic as a plain client, as Utilities' and SourceTools' tests do with `@testable` banned. You declined: a whole framework just to facilitate testing is a lot of extra work and permanent extra structure for very little gain other than to follow a guideline. The accounting, in the form the style guide's *Proportionality* section asks for:

- *The guideline in play.* Testing is a use case every intentional API must be designed for, and a test is a client like any other — so **a test stands where the API's real clients stand**. For an API published from a module, that is a plain import rather than a testability escape hatch, so that API which stops being reachable fails the build.
- *What it buys here.* This app's core is full of intentional APIs — `LoadHistory`'s interface, `MonitorState.advanced(with:)`, `SamplingPeriod`'s failable initializers, the two readers — and each is designed to be tested through its contract. But they are *informal*: their clients are the monitor and the views, inside the same module, seeing `internal` declarations. `@testable import` gives the tests exactly that view and no more; `private` remains the enforced line around what no client may touch. So the tests already stand where the real clients stand. A plain import would add reachability checking for a *published* API, and nothing here is published — it would buy nothing.
- *What a framework would really have done.* Changed the API's audience for the test's sake: made the core `public` so that the one client with no say in the contract could import it differently.
- *The siblings as prior art.* Utilities and SourceTools ban `@testable`, and they are right to: their APIs are published from frameworks to real importers, so a plain import *is* their clients' position. Same principle, different audience, opposite import. Draft 3's recommendation inherited their conclusion instead of their reasoning.
- *What compliance would have cost.* A third target with its own xcconfig trio; an embed phase and runpath; `public` on every core type, and DocC comments enforced as build errors on all of them; and an app whose internals are split across a module boundary for no reason a user of the app would ever see.
- *What the cheaper course gives up.* One real thing: a module boundary would have *enforced* that the pure core never imports SwiftUI or reaches the monitor. Here that separation is a convention, kept by folder (`App/Core/`) and by review. And documentation comments are written but not build-enforced.

It took three passes to find the quality that actually decides the import form. I first pinned it on the target being an application; you called that overly specific. You then put it as the absence of a "natural" API; and then refined "natural" to "intentional", widening it to any contract between two pieces of code — which showed that the rule cannot be keyed on whether an API exists at all, only on the API's audience.

**Consequences of hosting the tests in the app:**

- `TEST_HOST` and `BUNDLE_LOADER` **[R]**. `@testable` needs `ENABLE_TESTABILITY`, which the shared project configs already set to `YES` in Debug and `NO` in Release **[O]** — so tests run in Debug, which is the configuration the siblings' documented test command uses anyway.
- **A test run launches the app.** Accepted; the alternative is production code that checks whether it is under test.
- **The tests run inside the sandbox.** That turns the two kernel-reader smoke tests and the leak regression test into a standing check of P2, run on every test pass — something the framework design could not have given, since its tests ran unsandboxed.
- **Actor isolation needs a decision the framework made implicitly.** The app target defaults to `MainActor` isolation, as SourceTools' does; with the pure core in that target, its value types would inherit it. They are marked `nonisolated` so they stay usable off the main actor (P7 may move sampling there) **[R]** — to be settled against the compiler at P12.
- **No DocC** — the same position HelloWorld takes: with no framework there is no published API for it to enforce.

### B.11 The sandbox

The sibling project SourceTools sandboxes its app with the hardened runtime, and this project follows. Every probe so far ran unsandboxed, so whether the sandbox permits `host_processor_info`, the sysctl read, and the menu bar extra is what P2 establishes. I had proposed "fallback: sandbox off", on the grounds that this is a personally distributed tool. You rejected that fallback: use the sandbox, and if the kernel calls do not work, discuss the options, the first of which is to track down the appropriate entitlement rather than just turning it off. There is precedent in this workspace for doing that properly: SourceTools' appex already carries a documented temporary-exception entitlement.

### B.12 The kernel's reply buffer

**The signature.** `readProcessorTicks()` uses typed `throws`, which puts the failure in the signature — the style guide's ALL-20, and Swift's own convention. It copies the ticks into `CPUTicks` values with named fields because the C array `cpu_ticks[4]` imports into Swift as an anonymous 4-tuple.

**The buffer.** You proposed that the buffer for the kernel call be allocated once in the lifetime of the program and reused, so that — as with `top` and `ps`, which simply exit — deallocating it would be unnecessary; and you guessed that the long-running `top` has no branch that frees such buffers. Both turned out otherwise. The full account is C.8; in summary:

- **The caller allocates nothing, so there is nothing to allocate once.** The array parameter is a pure out-pointer. On each call the kernel `kmem_alloc`s a fresh page-rounded buffer, fills it, and hands it off with `vm_map_copyin(…, TRUE, &copy)` (`host.c:1183–1249`) **[S]**; the reply message maps it into this process at an address the kernel chooses, and the MIG stub just returns that address **[S]**. Mach's old mechanism for receiver-supplied buffers is gone — the SDK defines `MACH_RCV_OVERWRITE` as `0x00000000 /* scatter receive (deprecated) */` **[D]**.
- **Nothing frees it automatically.** 2,000 calls without `vm_deallocate` returned 2,000 distinct addresses and grew the physical footprint by 32.9 MB — a whole 16 KB page per call, to carry 384 bytes **[O]**. At a 1-second period that is about 1.3 GiB a day, in an app meant to sit in the menu bar for weeks. The "it exits anyway" reasoning that excuses `hostinfo` does not transfer to a long-running process.
- **Freeing promptly delivers the intended effect anyway.** With the free paired to the call, all 2,000 replies were mapped at the *same* address with zero footprint growth **[O]**. In steady state the process holds exactly one such page, reused for the life of the program — by the VM system's doing rather than ours.
- **No alternative route avoids this.** `processor_info()` takes an in-line, caller-supplied buffer, but needs a processor port per CPU, and those come only from `host_processors(host_priv_t, …)` **[D]**; an unprivileged process is refused the privileged host port (`KERN_INVALID_ARGUMENT` as uid 501) **[O]**. `host_statistics` takes a caller buffer too, but is machine-wide only.
- **Prior art.** `top` frees every out-of-line array the kernel hands it, every sample (`libtop.c:1343`, `1349`, `1709`) **[S]**, and even one-shot `ps` frees its thread list (`tasks.c:240–243`) **[S]**. `top`'s *CPU* path needs no free only because `host_statistics` returns an in-line array into a caller-supplied buffer — which is the allocate-once pattern, available to `top` precisely because it wants only the machine-wide figure.

### B.13 Failure handling

Draft 2 re-baselined after a failed read, discarding the previous sample. `top` does the opposite, and it falls out of its structure for free: a failed read leaves "current" untouched, the next delta is zero, the zero-total guard keeps the old line, and the following success differences against the last good sample (`libtop.c:467–469`, `globalstats.c:345–346`) **[S]**. That is simply better: a delta across a gap is still a correct average for the interval it spans, re-baselining throws that information away and delays the next step by a further period, and keeping the sample needs no extra state. There are no alerts because a monitoring tool that interrupts is worse than one that shows a gap.

### B.14 Smaller matters

- **Minimum window size.** "Fully resizable, no scroller" needs a floor, and this machine has 24 LoadViews. `contentMinSize` is already the default resizability for non-Settings windows **[D]**, so content minimums propagate to the window.
- **Telling adjacent LoadViews apart.** Twenty-four unlabelled graphs with zero spacing read as one. A hairline uses the least vertical space, which matters with many cores in a short window. The alternatives were small gaps, which cost height, and nothing at all, where a tall spike in one view touches the baseline of the view above.
- **Plot color.** `Color.primary` is literally the loose spec's "dark on light, light on dark", and it is unaffected by the user's accent choice. The alternative was the accent color.
- **The processor's name.** `machdep.cpu.brand_string` is listed in `man 3 sysctl` as `char[]` **[D]** and returns `Apple M2 Ultra` here **[O]**. Any sysctl read can fail, so the name is optional and the header degrades to "Unknown CPU" rather than failing as a whole.
- **The app icon.** The About panel shows one, and none exists.
- **Intel Macs.** The 26.0 deployment target admits them, and they report hyperthreaded *logical* CPUs. With core kinds out of the UI, nothing needs special-casing; the only wrinkle is that the header's "cores" would count logical CPUs there. Building for Apple silicon alone would need an architecture override diverging from the siblings' byte-identical project settings, and buys little. Nothing here to test it on.
- **Accessibility.** *"A canvas doesn't offer interactivity or accessibility for individual elements"* **[D]**. The label is the one place the CPU index survives, because a screen reader has no "position in the stack" to glean it from — and the index is a real identifier, not just a position, since Apple tests that array index = CPU ID **[S+O]** (C.4).
- **Localization.** English only, but strings go through the String Catalog machinery the project settings already enable.
- **Menus beyond the three named.** A default SwiftUI app also has File, Edit, View, and Help menus **[R]**. They are left untouched: "standard, with no additions", and no subtractions.

### B.15 What held up from the loose spec

- **The C++ conditional resolved to "not needed".** The loose spec said that if the kernel APIs were not directly accessible in Swift, a C++ API should be used. A probe compiled with `-swift-version 6 -strict-concurrency=complete -warnings-as-errors` called `host_processor_info`, used the `PROCESSOR_CPU_LOAD_INFO` and `CPU_STATE_*` constants, freed the result with `vm_deallocate`, and read `sysctlbyname`, all from pure Swift (D.1). It compiled clean and ran, reporting 99–101 ticks per CPU across a one-second sleep. Reachability from Swift is **[O]** — Apple's reference page offers the declaration in Objective-C only — while the declarations themselves are **[D]** in the SDK headers. Three wrinkles, none needing C++: the function-like macro `mach_task_self()` is not imported, so the global `mach_task_self_` is used instead; the C array `cpu_ticks[4]` imports as a 4-tuple; and `MachError` lives in Foundation, not Darwin. The four-language build settings stay regardless, per the workspace rule.
- **Header pinned, stack fills the rest, equal division.** `VStack(spacing: 0)` with a fixed-height header above equally flexible children — ordinary SwiftUI layout **[R]**.
- **About, Settings.** The `Settings` scene *"causes SwiftUI to enable the app's Settings menu item"* **[D]**. The standard About panel is what a SwiftUI app's About item shows **[R]**; its copyright line falls back to `NSHumanReadableCopyright` **[D]**, and its version fields come from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` **[R]**, both already `1` in the shared `Project-Common.xcconfig` **[O]**.
- **Appearance.** Semantic colors adapt to Light and Dark without code, and `Canvas` re-renders when the color scheme changes **[R]**.
- **Availability.** Everything used is macOS 15 or earlier (`Window` and `MenuBarExtra` 13, `Canvas` 12, `defaultLaunchBehavior` / `restorationBehavior` 15) **[D]**, under the 26.0 deployment target the sibling projects use.
- **Project settings.** Utilities' and SourceTools' copies of `Project-{Common,Debug,Release}.xcconfig` already hash identically **[O]**. Each sibling has its own git repository, and the workspace root is not one **[O]**.
- **Toolchain observed:** Xcode 27.0 (27A266a), Swift 6.4, `MacOSX27.0.sdk` **[O]**. The sibling projects' `CLAUDE.md` files still name Xcode 26.6; I have not rebuilt them under 27.

### B.16 What the Testability mandate asks of this design

The style guide's *Testability* section makes testing a use case every intentional API must be designed for, informal APIs included.

- **`LoadMonitor`'s reader is passed in.** The monitor was the one piece of the design that reached out for a collaborator instead of being handed it: it called `readProcessorTicks()` directly. Passing the reader in costs a line, and lets the monitor's own behavior be exercised with scripted ticks. Whether its clock should be injectable too was left open here, as *Proportionality*'s territory; it was weighed when the implementation was planned, and the answer is in B.17.
- **There is no public-surface test file** of the kind Utilities keeps (`IDFactoryAPITests`), because there is no public surface (B.10).
- **Two test cases come straight from reading `top`:** counter wrap, the case `top`'s widen-then-subtract gets wrong; and the machine-wide figure as deltas summed and divided once (C.2).
- **One test stands in for an invariant the compiler cannot check.** "Every reply buffer is freed" is not expressible in the type system — the pointer comes from C, and the obligation is a convention — so, per the *Compile-Time Enforcement* stance, a runtime check is the fallback and says which invariant it guards. The probe shows the two outcomes are unmistakable: zero growth when freeing, 16 KB per call when not (C.8). What the design *can* enforce structurally it does: the free is a `defer` inside the one function that makes the call, and that function returns a Swift array.

### B.17 What planning the implementation found

Planning the build (2026-09-21) surveyed how the sibling projects are written and run, and had a planning agent pressure-test the draft plan against this specification, the SourceTools specimen, Apple's documentation, and the open-source basis of Xcode's build system. Much of what follows was read by that agent rather than by me, and is labelled **[A]** where so; the two claims with the largest consequences I checked myself. The changes are listed in A.4.

**The rounding error was mine.** Writing the clean version, I gave the header's percentages a rule — round user and system, and let idle be the remainder — that fails at the edge: user 0.5% and system 99.5% round to 1 and 100, leaving idle at −1. Cumulative rounding cannot: *busy* = round(user + system) is at most 100 and, since system is never negative, at least round(user); so system = busy − user and idle = 100 − busy are both non-negative, and the three sum to 100 by construction.

**`TickDelta`.** The clean version said `CPULoad`'s only initializer took two `CPUTicks`, to make its bounds hold by construction. But the machine-wide figure is one division over deltas *summed across CPUs* (B.5), which that initializer cannot express. Putting the difference in a type of its own keeps both properties: the per-CPU initializer is the only place a counter is subtracted, so "subtract in 32 bits, then widen" cannot be got wrong elsewhere; deltas add; and a `CPULoad` still cannot be made from anything that could break its bounds.

**The monitor's sleep is injected, and a clock is not.** The three behaviors §6 asks the monitor's tests to cover include "a new period restarts the loop", and periods are whole seconds, so a test on the real clock waits at least a second and is only probably right. The alternatives, weighed as *Proportionality* asks:

- *A generic `Clock` parameter.* It makes `LoadMonitor` a generic class, which complicates `@Observable` and the environment, and needs a manual test clock of some sixty lines.
- *Exposing the per-sample step to the tests.* A door opened for the test, which *Testability* rules out.
- *An injected stream of ticks.* It departs from §5.8's single loop.
- *An injected sleep.* One parameter, parallel to the injected reader. The class stays non-generic and the per-sample step stays private. A test hands the monitor a sleep it controls and asserts on the next deadline the monitor asks to sleep until — deterministic, because everything runs on the main actor.

The last is cheap and buys the most, so it is the design. The deadline rule moves into the core as a pure function for the same reason: the branch in the loop becomes a function a test can call.

**The monitor persists nothing.** Hosted tests run inside the app's process, so `UserDefaults.standard` in a test *is* the app's real domain. A monitor that stored its own period could change your setting during a test run; one that is handed its period cannot.

**The log messages.** Several bring-up checks are about behavior I cannot watch: the cadence with no window open (P6), the cost (P7), agreement with `top` (P11), the step count arriving from the view (P14). A debug-level `os.Logger` message per sample makes all four observable from a shell with `log stream`, whose `--level`, `--predicate`, and `--timeout` options are present on this machine **[A]**. This is ordinary diagnostic output, not a branch that asks whether the app is under test, which the design refuses (B.10). The per-sample message carries numbers only, which the logging system does not redact.

**The first-launch size.** §5.1 fed `defaultSize` a size computed ahead of layout, which needs the header's height before the header exists. `defaultWindowPlacement` (macOS 15+) hands the closure a proxy for the content, and Apple's own example sizes a window with `content.sizeThatFits(.unspecified)` **[D]**. The documentation adds that the returned placement *"acts as a default for when the window first appears"* and that *"During state restoration, the system restores the window to its most recent size and position, rather than the default placement."* **[D]** With restoration disabled (B.8) I expect the closure to govern every launch **[R]**, which is P3.

**A test run is not the shipping sandbox.** After `xcodebuild test`, SourceTools' Debug app carries `get-task-allow`, `temporary-exception.files.absolute-path.read-only` for `/`, and `temporary-exception.mach-lookup.global-name` for three test daemons **[O]**. The build system adds these under the `test` and `profile` scheme commands, builds a hosted test bundle into the host's `Contents/PlugIns`, and copies the XCTest and Testing frameworks into the host's `Contents/Frameworks` **[A]** (`swiftlang/swift-build`: `ProductTypes.swift`, `ProductPlan.swift`, `XCTestHostTaskProducer`; the shipped Xcode may differ). The shipped Xcode did differ on the last point: after a hosted run the app has no `Contents/Frameworks` at all, and the frameworks load from Xcode's own `Contents/SharedFrameworks` **[O]** (D.6). Neither exception bears on a host-port call or a sysctl read, so the hosted reader tests still show what they claim; but a sandbox with a read exception for the whole filesystem is not the one that ships, so the clean proof of P2 and every check by hand use the Release build.

**Hosted tests under the hardened runtime are the open question.** Xcode's own SwiftUI app template is sandboxed and hosts its unit tests in the app, so sandbox-plus-hosted is well travelled; but that template does not turn the hardened runtime on **[A]**. Xcode injects the test bundle through `DYLD_INSERT_LIBRARIES` **[A]**, and whether `get-task-allow` alone makes a hardened process honor that is not established. That is the real content of P12. If it fails, the recourse to discuss is a Debug-only `RUNTIME_EXCEPTION_ALLOW_DYLD_ENVIRONMENT_VARIABLES`, which touches neither the sandbox nor Release. A mismatched `TEST_HOST` path produces only a build-system warning, which does not fail a warnings-as-errors build **[A]**, so the first build's log is searched for it.

**Pixel tests.** `ImageRenderer`'s documentation mentions drawing to a `Canvas` and exporting it **[D]**; Swift Testing can attach values to a test's results (Swift 6.2+) **[D]**; and `xcresulttool export attachments` exists in this Xcode **[O]**. The reference alpha is measured rather than assumed because the label color's alpha is not documented. Asymmetric loads catch a vertically flipped image, and a self-check on a plain stack keeps a flipped helper from cancelling a flipped view.

**Isolation.** `nonisolated` on a struct, class, or enum declaration is SE-0449, implemented in Swift 6.1 **[D]**. `onGeometryChange`'s transform closure is `@Sendable` **[D]**, which is why `LoadView.stepLength` is `nonisolated`. The Tests target keeps the project's `nonisolated` default, so a core declaration that misses its annotation fails the test build — a compile-time guard, not a test.

**The host port.** Each call to `mach_host_self()` adds a user reference to the task's name for the host port **[R]**; `top` stores the port and reuses it (`libtop_port`, used at `libtop.c:712`) **[S]**. The reader does likewise.

## Appendix C — Prior art: how `top`, `ps`, and the kernel answer these questions

Whatever this app reports should agree with the system's own tools. This appendix records how those tools work, read from Apple's published source, and what that changes here. The specification, and the rationale in Appendix B, point back to it.

### C.1 Provenance

| Component | Source read | What runs on this machine | Match |
|---|---|---|---|
| `top` | `apple-oss-distributions/top`, tag `top-144` | `what /usr/bin/top` → `PROJECT:top-144` | **exact** |
| `ps` | `apple-oss-distributions/adv_cmds`, tag `adv_cmds-237` | `what /bin/ps` → `PROJECT:adv_cmds-240` | three revisions behind |
| Kernel | `apple-oss-distributions/xnu`, tag `xnu-12377.1.9` | `uname -v` → `xnu-13432.1.9` | one major release behind |
| Activity Monitor | closed source | — | imports only (C.5) |

So every **[S]** claim about `top` describes the binary actually installed here. **[S]** claims about the kernel describe xnu-12377; wherever the behavior could be checked on the running kernel I did, and those are **[S+O]**.

### C.2 `top`

**`top` reports two different things, and only one of them is what this app plots.**

| `top`'s line | What it is | Source |
|---|---|---|
| `Load Avg: 1.38, 1.48, 1.64` | `getloadavg()`. *"Load average over 1, 5, and 15 minutes. The load average is the average number of jobs in the run queue."* | `libtop.c:743–757`, `globalstats.c:295`, `top.1:315–316` |
| `CPU usage: 2.50% user, 17.61% sys, 79.88% idle` | **This app's quantity.** *"Percentage of processor usage, broken into user, system, and idle components. The time period for which these percentages are calculated depends on the event counting mode."* | `globalstats.c:314–360`, `top.1:308–310` |

On the word itself: the kernel flavor is `PROCESSOR_CPU_LOAD_INFO`, and libtop comments its fetch `/* Get CPU load. */` (`libtop.c:704`). So "load" for tick data is the kernel's own word and this app's name is well-founded — but `top`'s *user interface* says "CPU usage" and reserves "Load" for the run queue.

**Where the data comes from.** `host_statistics(libtop_port, HOST_CPU_LOAD_INFO, …)` (`libtop.c:711–712`) — the *aggregate* across all CPUs. `top` never calls `host_processor_info`.

**The formula** (`globalstats.c:321–346`, delta mode shown):

```c
userticks = tsamp->cpu.cpu_ticks[CPU_STATE_USER] + tsamp->cpu.cpu_ticks[CPU_STATE_NICE];
systicks = tsamp->cpu.cpu_ticks[CPU_STATE_SYSTEM];
idleticks = tsamp->cpu.cpu_ticks[CPU_STATE_IDLE];
…
	userticks -= (tsamp->p_cpu.cpu_ticks[CPU_STATE_USER]
			+ tsamp->p_cpu.cpu_ticks[CPU_STATE_NICE]);
	systicks -= tsamp->p_cpu.cpu_ticks[CPU_STATE_SYSTEM];
	idleticks -= tsamp->p_cpu.cpu_ticks[CPU_STATE_IDLE];
…
totalticks = userticks + systicks + idleticks;

if (0 == totalticks)
	return;
```

- Nice is folded into user. The three components are each divided by the *tick* total, not by wall-clock time, so they always sum to 100%.
- A zero total returns early, which leaves the previously displayed line on screen.

**Sampling.**
- A baseline is taken at initialization and copied into both "previous" and "current" (`libtop.c:360–364`). Each later sample shifts current into previous, then reads (`libtop.c:467–469`).
- The default mode computes *"CPU usage since the previous sample"* (`top.1`, non-event mode; `preferences.c:70`), and the **default interval is 1 second** (`preferences.c:75`).
- The man page concedes the first-sample problem: *"Note that the first sample displayed will have an invalid %CPU displayed for each process, as it is calculated using the delta between samples."* (`top.1:141–142`)
- **A failed read** is survived without special handling: the shift happens before the read, so a failure leaves "current" unchanged, the next delta is zero, and the zero-total guard keeps the old line. The following success simply differences against the last good sample, over a longer interval.

**Per-process %CPU is a different calculation.** `cpu.c:74–81` divides a process's CPU-time delta by the *wall-clock* delta, from `CLOCK_MONOTONIC_RAW` timestamps (`libtop.c:368`, `455–460`). That figure is per process, 100% means one full CPU, and it shows `0.0` on a process's first sample (`cpu.c:44–52`).

**Two weaknesses not to copy.**
1. **Counter wrap.** The counters are 32-bit `natural_t`, but `top` holds them in `unsigned long long` and subtracts *after* widening (`globalstats.c:317`, `321`, `336–340`). Across a wrap, current < previous, the 64-bit subtraction underflows, and one refresh shows nonsense. Worse, the aggregate wraps far sooner than any single CPU's counter: idle accrues at about N × 100 ticks/second, so on this 24-CPU machine the aggregate idle counter wraps every 2³² ÷ 2,400 ≈ 20.7 days of uptime. **[S]** — from reading the arithmetic; not observed, since uptime here was 4 days.
2. **Unpadded hundredths.** `cpu_percent` yields a fractional part of 0–99 (`globalstats.c:307–312`), printed with a bare `%PRIu64` (`352–360`). So 76.06% prints as `76.6%`. Observed: `CPU usage: 2.80% user, 21.13% sys, 76.6% idle` — figures that would sum to an impossible 100.53% as printed, and to 99.99% read as 76.06 **[S+O]**. Worth knowing before comparing this app's numbers with `top`'s.

### C.3 `ps`

- `%cpu` is the sum, over a task's threads, of `thread_basic_info.cpu_usage` (`tasks.c:194–220`), printed as `cp * 100.0 / TH_USAGE_SCALE` with `TH_USAGE_SCALE` 1000 (`print.c:957–976`).
- The kernel fills that field from the scheduler's own aged usage figure: *"To calculate cpu_usage, first correct for timer rate, then for 5/8 ageing."* — then clamps it to `TH_USAGE_SCALE` (`osfmk/kern/thread.c:2012–2028`).
- The classic BSD formula (`p_pctcpu`, `ccpu`, `exp`) is still in the file but compiled out under `#if FIXME` (`print.c:934–952`).
- The man page: *"The CPU utilization of the process; this is a decaying average over up to a minute of previous (real) time. Because the time base over which this is computed varies (some processes may be very young), it is possible for the sum of all %cpu fields to exceed 100%."* (`ps.1:255–262`)
- `ps` takes **one sample and computes no deltas**, and no tick counter, `host_statistics`, or `host_processor_info` appears anywhere in it.

So `ps` answers "how busy has this *process* been lately", with 100% meaning one full CPU. It says nothing about any particular core, and its figures are not comparable with a per-core graph. Observed: a fresh busy process read `0.0` at elapsed time 00:00 and `100.0` at 00:05 **[O]**.

### C.4 The kernel

Where the ticks come from (`osfmk/kern/processor.c:802–815`):

```c
void
processor_cpu_load_info(processor_t processor,
    natural_t ticks[static CPU_STATE_MAX])
{
	struct recount_usage usage = { 0 };
	uint64_t idle_time = 0;
	recount_processor_usage(&processor->pr_recount, &usage, &idle_time);

	ticks[CPU_STATE_USER] += (uint32_t)(usage.ru_metrics[RCT_LVL_USER].rm_time_mach /
	    hz_tick_interval);
	ticks[CPU_STATE_SYSTEM] += (uint32_t)(
		recount_usage_system_time_mach(&usage) / hz_tick_interval);
	ticks[CPU_STATE_IDLE] += (uint32_t)(idle_time / hz_tick_interval);
}
```

| Fact | Source | Observed here |
|---|---|---|
| **Ticks are not sampled.** They are exact 64-bit accumulated CPU time divided by a tick interval. | `processor.c:802–815` | — |
| **A tick is 10 ms**: *"BSD expects a tick to represent 10ms."* | `clock.c:392–396` | 100 ticks/second on every CPU, busy or idle **[S+O]** |
| **Counters wrap; they do not saturate.** The `(uint32_t)` cast of a 64-bit quotient keeps the low 32 bits. | `processor.c:810–814` | not observed (uptime too short) |
| **`CPU_STATE_NICE` is always zero.** Set to 0 after the helper runs; the helper never touches it. | `processor.c:883`, `host.c:521` | raw counter 0 on all 24 CPUs **[S+O]** |
| **User and system are separately accounted.** System is kernel-level time, plus secure-level time where configured. | `recount.c:453–460` | a real split, e.g. 41 user / 23 system on one CPU **[S+O]** |
| **The aggregate `top` reads is the sum of the per-CPU values** — `host_statistics` loops over every processor calling this same helper. | `host.c:503–536` | summed per-CPU deltas equalled the aggregate's deltas exactly, twice **[S+O]** |
| **Idle is kept current for the caller**, including the idle span in progress, measured with `mach_absolute_time()`. | `recount.c:1241–1257` | — |
| `mach_absolute_time` *"does not increment while the system is asleep."* So idle does not accrue across system sleep. | Apple, `mach_absolute_time` **[D]** | — |
| **The array is in CPU-ID order.** Apple's kernel test `processor_cpu_info_order` — *"ensure host_processor_info iterates CPU in CPU ID order"* — asserts *"CPU ID must equal array index"*. | `tests/processor_info.c:116–145` | `slot_num` equalled the index on all 24 CPUs **[S+O]** |

On who frees the returned array: Apple's two open-source callers of *this* call — `hostinfo` (`system_cmds`) and that kernel test — never free it, but both are one-shot programs that exit at once, so they settle nothing. The question is settled elsewhere, in C.8: the caller must free it, every call.

### C.5 Activity Monitor

Closed source. Its executable imports `host_processor_info` from libSystem and does not import `host_statistics` **[O]** (`dyld_info -imports`), and links the private `libsysmon` and `libsystemstats`. That is consistent with it using the same per-CPU call this app does; how it uses it I cannot say.

### C.6 The comparison run

Four `yes > /dev/null` processes for a few seconds, with `top -l 3 -s 2` and the probe sampling concurrently over 2-second windows:

| Measure | user | sys | idle |
|---|---|---|---|
| This design: per-CPU deltas summed across CPUs | 2.60% | 18.37% | 79.03% |
| `top`'s formula applied to the aggregate, same interval | 2.60% | 18.37% | 79.03% |
| `top`'s 2nd printed sample | 2.50% | 17.61% | 79.88% |
| `top`'s 3rd printed sample | 2.39% | 17.45% | 80.14% |

The first two rows agree to the tick (4,806 ticks each) because they are the same numbers reached two ways. `top`'s own samples sit beside them, differing only because their windows start at slightly different instants. `top`'s *first* sample, which its man page disowns, read 2.80 / 21.13 / 76.06.

### C.7 What this changes

| This project's problem | How the tools solve it | What this design does |
|---|---|---|
| What is "load"? | `top`: busy ticks ÷ all ticks, nice folded into user. | The same (§2.9, §5.7). |
| The word "load" | The kernel says "load"; `top`'s UI says "CPU usage" and keeps "Load" for the run queue. | Keep the app's name; use `top`'s wording for the header line (§2.6). |
| The first sample | `top`: baseline at init; man page warns the first sample is invalid. `ps`: a new process reads 0.0. | Baseline at start; plot nothing real until the second sample (§2.9). |
| Nice | The kernel reports 0, always. `top` adds it to user anyway. | Add it to user; harmless and consistent. |
| Counter wrap | The kernel wraps. `top` mishandles it. | Subtract in 32 bits with `&-`, *then* widen (§5.7). |
| A machine-wide total | `top` differences the 32-bit aggregate, which wraps every ~20 days here. | **Sum the per-CPU deltas; never difference a sum** (§5.7). Identical result, no early wrap. |
| Zero elapsed ticks | `top` keeps the previous line. | Plot zero — a graph must plot *something* each step, and a gap is the honest rendering of "no information" (§5.7). |
| A failed read | `top` keeps the last good sample as its baseline. | Adopted — simpler than re-baselining, and it loses nothing (§5.12). |
| Update interval | `top` defaults to 1 s. | Default 1 s (§2.11). |
| Timer jitter | `top` needs timestamps only for per-*process* math. | None needed: the denominator is ticks, so a late timer changes the interval, not the ratio (§5.8). |
| Sleep and wake | Idle is measured on a clock that stops during sleep. | No special handling for the ticks; only the timer needs care (§5.8). |
| Order of the cores | Apple tests that array index = CPU ID. | Order is implicit, as you wanted; accessibility labels use the index (§5.13). |
| Matching `ps` | `ps` measures something else. | No attempt; don't expect agreement. |
| The kernel's reply buffer | `top` frees every out-of-line array it receives, every sample; so does one-shot `ps`. `top`'s CPU call avoids the issue by using an in-line, caller-supplied buffer — possible only because it wants the machine-wide figure. | Free on every call, paired with the call in one function. Allocate-once is not available for per-CPU data (§5.6, C.8). |

### C.8 Out-of-line memory: who allocates, who frees

Three questions, asked of `host_processor_info`: does the long-running `top` free such buffers; does MIG free anything automatically; and can the buffer be allocated once and reused?

**Who allocates: the kernel, afresh, every call.** `osfmk/kern/host.c:1183–1249` **[S]**:

```c
needed = pcount * icount * sizeof(natural_t);
size = vm_map_round_page(needed, VM_MAP_PAGE_MASK(ipc_kernel_map));
result = kmem_alloc(ipc_kernel_map, &addr, size, KMA_DATA, VM_KERN_MEMORY_IPC);
…
result = vm_map_copyin(ipc_kernel_map, (vm_map_address_t)addr, (vm_map_size_t)needed, TRUE, &copy);
…
*out_array = (processor_info_array_t)copy;
```

The caller's `processor_info_array_t *` is a pure out-pointer. There is no way to pass a buffer in.

**What MIG does with it.** I generated the client stub from this SDK's `mach_host.defs` with `xcrun mig` and read the `host_processor_info` routine **[S]** — with the caveat that this is code generated here from the SDK's definitions, which I take to match what libsystem ships but did not compare against it.

| Path | What the stub does | Generated `mach_host_user.c` |
|---|---|---|
| Success | Returns the address the kernel mapped the data at, and nothing else: `*out_processor_info = (processor_info_array_t)(Out0P->out_processor_info.address);` | line 1015 |
| Reply fails validation | **Automatic deallocation**: `mach_msg_destroy(&Out0P->Head);` releases any out-of-line memory and ports in the bad reply, so the caller never sees them. | lines 1006–1010 |
| Kernel routine returns an error | The reply carries no descriptor, so there is nothing to free. | — |

MIG's other automatic deallocation is on the *sending* side: every out-of-line descriptor has a `deallocate` bit (`mach/message.h:314`) by which a sender gives up its copy. Here the sender is the kernel, which consumes its own buffer through `vm_map_copyin`'s `TRUE` (source-destroy) argument. So your recollection is right that MIG frees memory automatically in surprising places — on the sender's side, and on the receiver's *failure* path. On the receiver's success path it frees nothing: the mapping is the caller's.

**Whether a receiver can supply the buffer.** Mach once allowed it — "scatter receive". In this SDK, `MACH_RCV_OVERWRITE` is `0x00000000 /* scatter receive (deprecated) */` (`mach/message.h:735`) and the `MACH_MSG_OVERWRITE` copy option is `/* deprecated */` (`:256`) **[D]**. The generated stub uses neither.

**What `top` and `ps` do.** Both free. `top`, per sample: `mach_vm_deallocate` after `task_threads` (`libtop.c:1665`, freed at `1709`), after `processor_set_tasks_with_flavor` (`1311`, freed at `1343`), and after `host_processor_sets` (`1297`, freed at `1349`) **[S]**. `ps`, though it exits at once: `/* Deallocate the list of threads. */` then `vm_deallocate` (`tasks.c:240–243`) **[S]**. All of these are `^array[] of …` types, as `processor_info_array_t` is (`mach_types.defs:214`, `216`, `452`, `470`) **[D]**. By contrast `top`'s CPU figure comes through `host_info_t`, `array[*:68] of integer_t` (`mach_types.defs:416`) — in-line, into the caller's own buffer.

**Observed** **[O]**, 2,000 calls per loop, 16,384-byte pages, 384-byte payload:

| Loop | Distinct addresses returned | Physical footprint growth | Virtual growth |
|---|---|---|---|
| with `vm_deallocate` | 1 | 0 B | 0 B |
| without | 2,000 | 32,899,096 B — 16,449 B per call | 32,768,000 B — 16,384 B per call |
| with, run again afterwards | 1 | 0 B | 0 B |

The no-free loop is its own control: it shows the measurement can see a leak, so the zeros in the other rows mean something. (In the third loop the region enclosing the returned address measured 32,768 B rather than 16,384; I take that to be the mapping coalescing with an adjacent leaked page, and did not verify it.)

**The alternatives.** `processor_info()` takes an in-line, caller-supplied `processor_info_t` (`processor.defs:105–109`) but needs a `processor_t` per CPU, which only `host_processors(host_priv_t, …)` supplies (`host_priv.defs:170–172`) **[D]**; `host_get_host_priv_port` returned `KERN_INVALID_ARGUMENT` for uid 501 **[O]**. `host_statistics` is machine-wide only.

**Conclusion.** Allocate-once is the right instinct and is exactly what `top` does where the API allows it. This API does not: the buffer is the kernel's to allocate, per call, and the caller's to free, per call. Freed promptly, it costs nothing — the kernel reuses one address indefinitely.

## Appendix D — Experiments

The probes that settled open questions. Their sources lived in a session scratchpad, which does not persist, so the listings here are the durable copies. Conditions for all of them are given in Appendix E.

### D.1 The kernel probe

Established that the kernel interface is reachable from pure Swift under the projects' compiler settings (B.15). Its core is kept as the seed for `readProcessorTicks()`. It is evidence, not final code — among other things it returns `Result` where the design uses typed `throws`.

```swift
import Foundation

func sampleTicks() -> Result<[Ticks], MachError> {
	var processorCount: natural_t = 0
	var info: processor_info_array_t? = nil
	var infoCount: mach_msg_type_number_t = 0
	let status = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount)
	guard status == KERN_SUCCESS, let info else {
		return .failure(MachError(MachErrorCode(rawValue: status) ?? .failure))
	}
	defer {
		let byteCount = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
		vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), byteCount)
	}
	let ticks = info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(processorCount)) { loads in
		UnsafeBufferPointer(start: loads, count: Int(processorCount)).map {
			Ticks(user: $0.cpu_ticks.0, system: $0.cpu_ticks.1, idle: $0.cpu_ticks.2, nice: $0.cpu_ticks.3)
		}
	}
	return .success(ticks)
}
```

Compiled with `xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -enable-upcoming-feature MemberImportVisibility`. It ran and reported 99–101 ticks per CPU, on 24 CPUs, across a one-second sleep.

### D.2 The lifetime probe

The harness behind B.1 and B.8, trimmed to its method. One source file; each variant is a different `App` selected with `-D VARIANT_x`. The app delegate here exists only to *observe* — it is scaffolding for the experiment, not part of the design, and only variants B and G gave it a say in termination.

```swift
class ProbeDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ notification: Notification) {
		Task { @MainActor in
			try? await Task.sleep(for: .seconds(2))
			log("before close: \(describeWindows())")
			NSApp.windows.first { $0.title == mainWindowTitle && $0.isVisible }?.performClose(nil)
			try? await Task.sleep(for: .seconds(2))
			//	Reaching this line at all is the result: the process outlived its window.
			log("ALIVE 2 s after close: \(describeWindows())")
			log("Window menu: \(windowsMenuTitles())")
			if let menu = NSApp.windowsMenu, let itemIndex = menu.items.firstIndex(where: { $0.title == mainWindowTitle }) {
				menu.performActionForItem(at: itemIndex)
			}
			try? await Task.sleep(for: .seconds(1))
			log("after menu action: \(describeWindows())")
			exit(0)
		}
	}

	func applicationWillTerminate(_ notification: Notification) {
		//	Seeing this before "ALIVE" means SwiftUI quit the app when the window closed.
		log("applicationWillTerminate")
	}
}

//	Variant H — the shape the design adopts.
@main
struct ProbeApp: App {
	@NSApplicationDelegateAdaptor private var delegate: ProbeDelegate
	var body: some Scene {
		Window(mainWindowTitle, id: "main") { ContentView() }
			.defaultLaunchBehavior(isLaunchSuppressed ? .suppressed : .presented)
			.restorationBehavior(.disabled)
		Settings { ContentView() }
		MenuBarExtra("Probe", systemImage: "cpu") { Text("probe") }
	}
}
```

Variants A, A2, B, C, D, E, and I are tabulated in B.1. The other four add scene modifiers:

| Variant | Scenes | Result |
|---|---|---|
| G | B, plus a run-time `defaultLaunchBehavior` and `restorationBehavior(.disabled)` | Suppressed: no window at launch; the app stayed alive; no Window-menu entry, so the window was unreachable. |
| H | D, plus the same two modifiers | Presented: as D. Suppressed: no window at launch; the app stayed alive; the Window-menu entry was present, and invoking it opened the window. |
| J | D, plus only `restorationBehavior(.disabled)` | Survived; the entry reopened the window; **no** `NSWindow Frame main` was saved. |
| K | D, plus only `defaultLaunchBehavior(.presented)` | Survived; the entry reopened the window; the frame was saved. |

**The reopen event.** A self-sent `kAEReopenApplication` stood in for a Dock click. Under H with `.suppressed`, no window appeared. In the two controls — H with `.presented`, and D with no modifier — a closed window became visible again.

**Frame saving.** After each run, `defaults read` of the probe's domain showed `NSWindow Frame main` for A, A2, B, C, D, E, I, and K, and no defaults domain at all for G, H, and J — the three with `restorationBehavior(.disabled)`. J and K each differ from D by one modifier. Whether a saved frame is *restored* was not tested.

**Two controls kept the results honest.** Variant A, a lone `Window`, had to quit — and did — or a "survived" elsewhere would have meant nothing. And the reopen event had to visibly *work* somewhere before its doing nothing under `.suppressed` could count as a finding rather than a mis-delivered event.

The Window menu was read after forcing it to populate (`menuNeedsUpdate`, `update()`), so that an absent entry could not be an artifact of lazy population. The probes left nothing behind: each persisted only a preferences domain (`com.example.claude-lifetime-probe.*`), and those were deleted.

### D.3 The tick probe: per-CPU ticks against the aggregate `top` uses

Reads the per-CPU ticks (`host_processor_info`, what this app uses) and the aggregate (`host_statistics`, what `top` uses) over the same interval, and checks the kernel-source claims on the running kernel: nice always zero, a real user/system split, and aggregate = Σ per-CPU. The results are in C.4 and C.6. It is the basis of check P11.

```swift
import Foundation

//	Probe: do per-CPU ticks (host_processor_info) and the aggregate top uses (host_statistics) agree,
//	and do the kernel-source claims hold on this machine (nice == 0, real user/system split, wrap)?

struct Ticks {
	let user: UInt32
	let system: UInt32
	let idle: UInt32
	let nice: UInt32
}

func readPerCPU() -> [Ticks] {
	var processorCount: natural_t = 0
	var info: processor_info_array_t? = nil
	var infoCount: mach_msg_type_number_t = 0
	guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount) == KERN_SUCCESS, let info else { return [] }
	defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
	return info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(processorCount)) { loads in
		UnsafeBufferPointer(start: loads, count: Int(processorCount)).map {
			Ticks(user: $0.cpu_ticks.0, system: $0.cpu_ticks.1, idle: $0.cpu_ticks.2, nice: $0.cpu_ticks.3)
		}
	}
}

func readAggregate() -> Ticks {
	var load = host_cpu_load_info()
	var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
	let status = withUnsafeMutablePointer(to: &load) { pointer in
		pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
	}
	precondition(status == KERN_SUCCESS)
	return Ticks(user: load.cpu_ticks.0, system: load.cpu_ticks.1, idle: load.cpu_ticks.2, nice: load.cpu_ticks.3)
}

func percent(_ part: UInt64, of whole: UInt64) -> String {
	whole == 0 ? "n/a" : String(format: "%.2f%%", (Double(part) * 100) / Double(whole))
}

let firstPerCPU = readPerCPU()
let firstAggregate = readAggregate()
Thread.sleep(forTimeInterval: 2)
let secondPerCPU = readPerCPU()
let secondAggregate = readAggregate()

print("--- per-CPU deltas over 2 s (user / system / idle / nice)")
var summedUser: UInt64 = 0
var summedSystem: UInt64 = 0
var summedIdle: UInt64 = 0
for (index, pair) in zip(firstPerCPU, secondPerCPU).enumerated() {
	let user = pair.1.user &- pair.0.user
	let system = pair.1.system &- pair.0.system
	let idle = pair.1.idle &- pair.0.idle
	let nice = pair.1.nice &- pair.0.nice
	summedUser += UInt64(user)
	summedSystem += UInt64(system)
	summedIdle += UInt64(idle)
	print(String(format: "cpu %2d: %4u %4u %4u %4u   raw nice counter = %u", index, user, system, idle, nice, pair.1.nice))
}

let summedTotal = summedUser + summedSystem + summedIdle
print("\n--- design's total: deltas summed across CPUs")
print("user \(percent(summedUser, of: summedTotal))  sys \(percent(summedSystem, of: summedTotal))  idle \(percent(summedIdle, of: summedTotal))   (\(summedTotal) ticks)")

let aggregateUser = UInt64((secondAggregate.user &+ secondAggregate.nice) &- (firstAggregate.user &+ firstAggregate.nice))
let aggregateSystem = UInt64(secondAggregate.system &- firstAggregate.system)
let aggregateIdle = UInt64(secondAggregate.idle &- firstAggregate.idle)
let aggregateTotal = aggregateUser + aggregateSystem + aggregateIdle
print("\n--- top's formula on the aggregate (host_statistics), same interval")
print("user \(percent(aggregateUser, of: aggregateTotal))  sys \(percent(aggregateSystem, of: aggregateTotal))  idle \(percent(aggregateIdle, of: aggregateTotal))   (\(aggregateTotal) ticks)")

print("\n--- wrap check: aggregate counter vs 64-bit sum of the per-CPU counters (second sample)")
for (name, aggregate, perCPU) in [("user", secondAggregate.user, secondPerCPU.map(\.user)), ("system", secondAggregate.system, secondPerCPU.map(\.system)), ("idle", secondAggregate.idle, secondPerCPU.map(\.idle))] {
	let wideSum = perCPU.reduce(UInt64(0)) { $0 + UInt64($1) }
	let truncatedSum = UInt32(truncatingIfNeeded: wideSum)
	let wrapCount = wideSum >> 32
	//	The two reads are not atomic, so allow the counters to have advanced slightly in between.
	let difference = Int64(aggregate) - Int64(truncatedSum)
	print("\(name): aggregate=\(aggregate)  sum64=\(wideSum)  sum64 mod 2^32=\(truncatedSum)  (sum64 has wrapped 2^32 \(wrapCount)x)  aggregate - (sum mod 2^32) = \(difference)")
}
```

### D.4 The leak probe: who frees the kernel's reply buffer

Calls `host_processor_info` thousands of times with and without `vm_deallocate`, watching the returned addresses and the process's footprint. The results are in C.8. It is the seed for the regression test in §6. The no-free loop is its own control: it shows the measurement can see a leak, so the zeros in the other rows mean something.

```swift
import Foundation

//	Probe: does each host_processor_info call map a NEW region into the caller, and does anything
//	free it automatically? Compare a loop that deallocates with one that does not.

struct Footprint {
	let physicalBytes: UInt64
	let virtualBytes: UInt64
}

func readFootprint() -> Footprint {
	var info = task_vm_info_data_t()
	var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride)
	let status = withUnsafeMutablePointer(to: &info) { pointer in
		pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
	}
	precondition(status == KERN_SUCCESS)
	return Footprint(physicalBytes: info.phys_footprint, virtualBytes: UInt64(info.virtual_size))
}

func regionSize(at address: vm_address_t) -> UInt64 {
	var regionAddress = mach_vm_address_t(address)
	var size: mach_vm_size_t = 0
	var info = vm_region_basic_info_data_64_t()
	var count = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.stride / MemoryLayout<integer_t>.stride)
	var objectName: mach_port_t = 0
	let status = withUnsafeMutablePointer(to: &info) { pointer in
		pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { mach_vm_region(mach_task_self_, &regionAddress, &size, VM_REGION_BASIC_INFO_64, $0, &count, &objectName) }
	}
	return status == KERN_SUCCESS ? size : 0
}

func runLoop(callCount: Int, isDeallocating: Bool) {
	var addresses = Set<UInt>()
	var firstRegionBytes: UInt64 = 0
	var payloadBytes = 0
	let before = readFootprint()
	for callIndex in 0..<callCount {
		var processorCount: natural_t = 0
		var info: processor_info_array_t? = nil
		var infoCount: mach_msg_type_number_t = 0
		guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &info, &infoCount) == KERN_SUCCESS, let info else { fatalError("call failed") }
		let address = UInt(bitPattern: info)
		addresses.insert(address)
		payloadBytes = Int(infoCount) * MemoryLayout<integer_t>.stride
		if callIndex == 0 { firstRegionBytes = regionSize(at: vm_address_t(address)) }
		if isDeallocating {
			vm_deallocate(mach_task_self_, vm_address_t(address), vm_size_t(payloadBytes))
		}
	}
	let after = readFootprint()
	let physicalGrowth = Int64(after.physicalBytes) - Int64(before.physicalBytes)
	let virtualGrowth = Int64(after.virtualBytes) - Int64(before.virtualBytes)
	print("\(isDeallocating ? "WITH   " : "WITHOUT") vm_deallocate, \(callCount) calls: distinct addresses = \(addresses.count); payload = \(payloadBytes) B; first region = \(firstRegionBytes) B")
	print("        footprint growth: physical \(physicalGrowth) B (\(physicalGrowth / Int64(callCount)) B/call), virtual \(virtualGrowth) B (\(virtualGrowth / Int64(callCount)) B/call)")
}

print("page size: \(vm_kernel_page_size) B")
runLoop(callCount: 2000, isDeallocating: true)
runLoop(callCount: 2000, isDeallocating: false)
runLoop(callCount: 2000, isDeallocating: true)
```

### D.5 Smaller probes

- **Core kinds (B.6).** `host_processor_info` with `PROCESSOR_BASIC_INFO` printed identical `cpu_type` and `cpu_subtype` for all 24 CPUs, and `slot_num` equal to the array index for every one. A pure-Swift IOKit probe read `cluster-type` keyed by `logical-cpu-id` from the `IODeviceTree:/cpus` children, compiled under the same strict flags as D.1; it showed the data to be reachable, and says nothing about what Apple guarantees for it.
- **The privileged host port (C.8).** A C probe of `host_get_host_priv_port` as uid 501 returned `KERN_INVALID_ARGUMENT`.
- **The MIG stub (C.8).** `xcrun mig -arch arm64` over the SDK's `mach/mach_host.defs` generated the client stub that C.8 reads.
- **No SwiftUI combo box (B.2).** `grep -ci combobox` over the SDK's `SwiftUI.swiftinterface` returned 0, with a control grep for `public struct Picker<` returning 2.

### D.6 Bring-up results

The §7 checks as they were run, with what was seen. Conditions unless stated: the `scaffold` branch of 2026-09-21, macOS 27.0 (26A428), Xcode 27.0 (27A266a), the Release product for everything by hand, the Debug product for the hosted tests. "You" marks a check made with your hands; the rest were made from a shell.

| Check | Result | Evidence |
|---|---|---|
| **P12** hosted tests under the hardened runtime | **Held**, with nothing added: the `get-task-allow` the `test` action applies is enough. | From inside the host, `_dyld_get_image_name`: `libXCTestBundleInject.dylib` at image index 1, ahead of the app's own binary at 3; the test bundle from `Contents/PlugIns`; `XCTest`, `XCTestCore`, `XCTestSupport`, and `Testing` from Xcode's `Contents/SharedFrameworks`. The environment's `XCTestBundleInjectPath` names a copy in the app's `Contents/Frameworks` first, but no such directory exists; `DYLD_FRAMEWORK_PATH` resolves the frameworks. The build log has no "Unable to find a target which creates the host product". A control run with `TEST_HOST` and `BUNDLE_LOADER` removed fails both location tests, reporting `com.apple.dt.xctest.tool` and the real home directory. |
| **P2** the sandbox permits the kernel calls | **Held**, on the Release product. | Entitlements `app-sandbox` and `get-task-allow` only; `flags=0x10000(runtime)`. With `log stream --debug` running, the launch line `Launched on Apple M2 Ultra with 24 CPUs` was written from inside the sandbox. The same stream shows `deny(1) system-info vfs.disk-space` many times and `deny(1) iokit-open-user-client AppleNVMeEANUC` once; SourceTools' sandboxed app, which makes no kernel reads, logs both at launch too, so neither is this app's. What those operations are for is undocumented **[U]**. |
| **P8** no leak | **Held**, and the guard fires. | 4,000 calls in 27 ms with the footprint's growth under the 16 MB bound. With the `vm_deallocate` removed in a scratch copy: growth 65,830,960 bytes, one 16 KB page per call, and the test failed. |
| The `nonisolated` guard | **Fires as a build error**, not a test. | With `nonisolated` dropped from `readProcessorTicks()`, the test build fails at `ProcessorTicksReaderTests.swift:19`: "main actor-isolated global function 'readProcessorTicks()' cannot be called from outside of the actor". |
| **P3** launch checkbox and remembered size | **Held after one correction.** `@AppStorage` takes an optional `Double`; `defaultWindowPlacement` is honored at every launch; the unchecked box gives no window; a Dock click then shows nothing. | Storing the view's size as §5.1 first sketched shrank the window each relaunch: seeded with 700×400, the frame went 400, 368, 336. A scratch build printing the placement's inputs and the geometry proxy showed why: `sizeThatFits` 480×240, `safeAreaInsets.top` 32, the view 368 tall in a 400-tall window — the hidden title bar's region is a safe-area inset inside a content rect that the placement sizes whole. Storing the view's size plus its insets held 700×400 across three relaunches, and the empty-defaults path settled at 480×272 and held. The first launch stays one inset short of ideal. The last three items: you. |
| **P1** the app outlives its window | **Held.** You. | Closing the window with a click left the app running; Window ▸ CPULoadMeter reopened it. |
| **P9** the extra's item brings the window forward | **Failed twice.** You. | With another app frontmost, *Show CPULoadMeter* did not bring the app to the foreground; with `NSApplication.shared.activate()` added after `openWindow`, no change. |
| **P9**, third check | **Failed with any app but Finder in front.** You. | With the cooperative `NSRunningApplication.activate(from:options:)` shipped, *Show CPULoadMeter* brought the app to the foreground when a Finder window was in front, and did not when any other app's window was — Xcode's, for one. Both AppKit forms rolled back; the limitation is documented (D19). |
| **P9**, the activation routes measured | Probe, from inside the app, 2026-09-21; its rival app was Finder only, which the third check showed to be a special case. | A hosted test put a Finder window in front (`NSWorkspace.shared.open` of `/Applications`) and tried each route, reading `NSApplication.isActive`, `NSWorkspace.frontmostApplication`, the window's `isKeyWindow`, and the front-to-back owners of the on-screen layer-0 windows from `CGWindowListCopyWindowInfo`. Three cycles in one process: `NSApplication.shared.activate()` — declined 3/3 (`isActive` false, Finder frontmost); `activate(ignoringOtherApps: true)` — declined; `makeKeyAndOrderFront(nil)` — the window rose from fourth to second, behind Finder's key window, app inactive; `orderFrontRegardless()` — the window first, app inactive; `NSRunningApplication.current.activate(from: frontmost, options: [])` — returned `true` and activated 3/3, the window key and first, and returned `true` again when already active. `NSWorkspace.openApplication(at:)` on the app's own bundle activated the *other* running instance of the same bundle (launched from Xcode), so it measured nothing. Test host launched inactive, behind Terminal. |
| **P13** the extra and the standard UI | **Held except one item.** You. | `SettingsLink` works from the extra; the traffic lights are present; About shows the name, version, and copyright. The extra *can* be removed by command-drag, and with the window closed that quit the app — as Apple's `MenuBarExtra` overview says it will. Accepted, D20. |
| The test bundle links core code the app does not use | Observation from PR 2, 2026-09-22. | The plan had flagged undefined symbols as a risk once the test bundle referenced core types nothing in the app calls, with a Debug-only `DEAD_CODE_STRIPPING = NO` as the fallback. It did not arise: all six core types and their 34 tests link and run against the unchanged settings, so no divergence was recorded. |
| The extra, seen from inside | Observation, not a check. | `CGWindowListCopyWindowInfo` from another process shows no status item this project can interpret. A disposable hosted test importing AppKit listed `NSApplication.shared.windows`: an `NSStatusBarWindow`, visible, level 25, 32×30 at the top-right of a 3200-wide screen, and the Window menu holding `CPULoadMeter`. |

## Appendix E — Evidence

Every factual claim in Appendices B, C, and D carries one of these labels, because a plausible claim and a checked claim look identical on the page. The specification itself (§1–§8) carries none: it states the design, and the assumptions it still leans on are the checks in §7.

| Label | Meaning |
|---|---|
| **[D+O]** | Documented *and* observed on this machine. Safe to build on. |
| **[D]** | Documented; not yet observed here. |
| **[O]** | Observed here; I found no documentation. Scoped to the conditions below. |
| **[S]** | Read in Apple's published source, cited by file and line. The version read, and how it relates to what runs on this machine, is in Appendix C.1. |
| **[S+O]** | Read in source *and* observed on this machine. |
| **[R]** | Recalled from memory. Not verified. A hypothesis until a bring-up proof (§7) covers it. |
| **[U]** | Undocumented Apple behavior. I do not know what it guarantees, and nothing in the design rests on it. |
| **[A]** | Reported by a planning agent that read the named source or file on this machine. I did not re-read it. Weaker than **[S]** or **[O]** for that reason, and used only in B.17. |

Conditions for every **[O]**: Mac with Apple M2 Ultra (24 CPUs), macOS 27.0, Xcode 27.0 (27A266a), Swift 6.4, `MacOSX27.0.sdk`, 2026-09-18, unsandboxed. The lifetime probes were additionally: built with `swiftc -parse-as-library` targeting macOS 26.0, wrapped in minimal `.app` bundles, ad-hoc signed, launched as direct children of a shell with `-ApplePersistenceIgnoreState YES`, and self-driving (no human input).

| Claim | Source |
|---|---|
| `host_processor_info` signature | SDK `usr/include/mach/mach_host.h:136`. Apple's reference page (`documentation/kernel/1502854-host_processor_info`) has the signature only. |
| Returned array is out-of-line | SDK `mach/mach_host.defs:131`; `mach/mach_types.defs:452` (`^array[] of integer_t`). |
| Receiver must `vm_deallocate` it, every call; nothing frees it automatically; it cannot be allocated once | No Apple prose says so — `osfmk/man/host_processor_info.html` in apple-oss-distributions/xnu is a 404 and `processor_info.html` covers only `PROCESSOR_BASIC_INFO` — so this rests on source and observation. Kernel: `xnu-12377.1.9 osfmk/kern/host.c:1183–1249`. MIG: client stub generated here with `xcrun mig -arch arm64` from the SDK's `mach/mach_host.defs`. Headers: `mach/message.h:256, 314, 735`; `mach/mach_types.defs:214, 216, 416, 452, 470`; `mach/processor.defs:105–109`; `mach/host_priv.defs:170–172`. Prior art: `top-144 libtop.c:1297–1349, 1665–1709`; `adv_cmds-237 ps/tasks.c:195, 240–243`. Observation: leak probe, 3 × 2,000 calls, footprint from `task_info(TASK_VM_INFO)`; and a C probe of `host_get_host_priv_port` as uid 501. Figures in C.8. |
| Tick counters and modes | SDK `mach/processor_info.h:115–116`; `mach/machine.h:74–79`. |
| How `top` computes CPU usage, samples, and defaults | `apple-oss-distributions/top` at `top-144` — the version installed here. `globalstats.c:292–360`, `libtop.c:360–368, 455–469, 704–757`, `cpu.c:36–89`, `preferences.c:70–75`, `top.1:86–116, 141–142, 308–316`. Details and quotations in C.2. |
| How `ps` computes `%cpu` | `apple-oss-distributions/adv_cmds` at `adv_cmds-237` (installed: `-240`). `ps/tasks.c:194–220`, `ps/print.c:931–976`, `ps/ps.1:255–262`; kernel side `xnu osfmk/kern/thread.c:2012–2028`. C.3. |
| What the ticks are: exact time ÷ 10 ms, truncated to 32 bits; nice always 0; aggregate = Σ per-CPU; idle kept current; CPU-ID order | `apple-oss-distributions/xnu` at `xnu-12377.1.9` (running: `xnu-13432.1.9`). `osfmk/kern/processor.c:802–815, 869–890`, `osfmk/kern/host.c:503–536`, `osfmk/kern/clock.c:392–396`, `osfmk/kern/recount.c:453–460, 1241–1257`, `tests/processor_info.c:116–145`. C.4. |
| `mach_absolute_time` stops during sleep | Apple, `mach_absolute_time`. |
| Kernel claims observed on the running kernel | Tick probe, 2 s window, idle machine: every CPU accrued 199–202 ticks; nice delta and raw counter 0 on all 24; user and system both nonzero on busy CPUs; per-CPU deltas summed = aggregate deltas (3.48 / 1.71 / 94.81% over 4,801 ticks); `host_statistics` counters equalled the 64-bit sums of the per-CPU counters exactly. `slot_num` = index for all 24 from the earlier `PROCESSOR_BASIC_INFO` probe. Wrap itself not observed — uptime 4 days, largest counter 848,063,324 of 2³². |
| Agreement with `top`; `ps` ramp | Four `yes > /dev/null` for a few seconds; `top -l 3 -n 0 -s 2` concurrent with the tick probe. Figures in C.6. `ps -o %cpu` on one generator: `0.0` at etime 00:00, `100.0` at 00:05. The generators were killed afterwards and confirmed gone. |
| Activity Monitor's imports | `xcrun dyld_info -imports` on its executable: `_host_processor_info` and `_vm_deallocate` from libSystem; no `host_statistics`. `-linked_dylibs`: `libsysmon`, `libsystemstats`. |
| Apple's own callers of `host_processor_info` | `gh search code host_processor_info --owner apple-oss-distributions`: callers are `system_cmds/hostinfo/hostinfo.c` and `xnu/tests/processor_info.c`; neither deallocates, both exit immediately, so neither bears on a long-running caller. |
| Pure-Swift access works; ~100 ticks/s per CPU | Kernel probe, D.1. `swiftc` exit 0 under the flags shown; 24 CPUs each reporting 99–101 ticks across a 1 s sleep. |
| `mach_task_self_` usable under strict concurrency | SDK `mach/mach_init.h:80` annotates it `__swift_nonisolated_unsafe`. Older SDKs not checked. |
| `machdep.cpu.brand_string` | `man 3 sysctl`, `CTL_MACHDEP` table, type `char[]`. |
| Core kinds — investigated, then dropped (B.6) | `host_processor_info` with `PROCESSOR_BASIC_INFO`: `cpu_type=16777228 cpu_subtype=2` for all 24 CPUs. `sysctl -a` filtered for cluster / perflevel / per-CPU lists: only `hw.perflevelN.name` and counts. IODeviceTree `cpuN` nodes: `cluster-type` E for `logical-cpu-id` 0–3 and 12–15, P for 4–11 and 16–23, read both by `ioreg` and by a pure-Swift IOKit probe — undocumented. Documented counts: Apple, "Determining system capabilities". |
| Lone `Window` quits on close; `Window` listed in the Window menu; `openWindow` brings to front | Apple, SwiftUI `Window`. |
| App-lifetime results, variants A–K | Lifetime probe, D.2. Timeline logs: A and A2 reached `applicationShouldTerminate` ~30 ms after `performClose`; B logged the delegate being asked, then "ALIVE"; C, D, E, H, J, K logged "ALIVE" with no delegate method; I quit. The Window menu was read after forcing population (`menuNeedsUpdate`, `update()`). |
| Window-menu entry reopens the window | Same probe: `performActionForItem(at:)` on the entry, then the window reported `visible=true` (C, D, H, J, K). |
| Reopen event under each launch behavior | Same probe, self-sent `kAEReopenApplication`. Controls (H with `.presented`; D with no modifier): closed window became visible again. H with `.suppressed`: no window appeared. Equivalence to a Dock click is **[R]**. |
| `restorationBehavior(.disabled)` stops frame saving | `defaults read` of each probe's domain after its run: `NSWindow Frame main` present for A, A2, B, C, D, E, I, K; no domain at all for G, H, J — the three with the modifier. J and K differ from D by one modifier each. Whether a saved frame is *restored* was not tested. |
| `performClose` simulates the close button | Apple, `NSWindow.performClose(_:)`. |
| Launch and restoration behavior; the Dock-click sentence | Apple, `Scene.defaultLaunchBehavior(_:)`, `SceneLaunchBehavior`, `Scene.restorationBehavior(_:)`. |
| `MenuBarExtra`: persistent control; termination when a menu-bar-only app's extra is removed; `LSUIElement` | Apple, SwiftUI `MenuBarExtra`. |
| `DocumentGroup` requirements; silence on lifetime | Apple, SwiftUI `DocumentGroup`. `WindowGroup` likewise silent on lifetime. |
| `applicationShouldTerminateAfterLastWindowClosed(_:)` | Apple, `NSApplicationDelegate`. |
| Hidden title bar; title removal; resizability defaults | Apple, `HiddenTitleBarWindowStyle`; `ToolbarDefaultItemKind.title`; `WindowResizability`. |
| `Canvas`; `Settings` | Apple, SwiftUI pages of those names. |
| About panel copyright fallback | Apple, `NSApplication.orderFrontStandardAboutPanel(options:)`. The page fetched did not list the other fields' sources. |
| No SwiftUI combo box | `grep -ci combobox` over the SDK's `SwiftUI.swiftinterface` → 0; control grep for `public struct Picker<` → 2. |
| No SwiftUI action activates an app | `grep -o 'public var [a-zA-Z]+: SwiftUI[A-Za-z]*\.[A-Za-z]+Action'` over the same interface lists exactly `dismiss`, `dismissImmersiveSpace`, `dismissSearch`, `dismissWindow`, `newDocument`, `openDocument`, `openImmersiveSpace`, `openSettings`, `openWindow`, `preferredPencilDoubleTapAction`, `pushWindow`, `refresh`, `rename`, `resetFocus`; a grep for `activat` finds only `allowsWindowActivationEvents`, search-scope and dictation activation, and accessibility. Apple, `OpenWindowAction`: no sentence about activating the app. |
| `NSApplication.activate()` is a request | Apple, `NSApplication.activate()` (macOS 14.0+): *"Use this method to request app activation; calling this method doesn't guarantee app activation. For cooperative activation, the other app should call yieldActivation(to:) or equivalent before the target app invokes activate()."* |
| Activation is driven by user intent; the cooperative form provides context | Apple, *AppKit Release Notes for macOS 14*: *"In macOS 14, app activation is driven by user intent. It is treated by the system as a request and is not always guaranteed to be honored or to succeed. Apps have the ability to provide context with activation requests in cases where a more deterministic result is desired."* … *"The cooperative activation mechanism guarantees successful activation as long as the yielding app is active at the time of the request and the receiver can become active."* The page says nothing about status items or menu bar extras. |
| `NSRunningApplication.activate(from:options:)` | Apple (macOS 14.0+): *"Attempts to activate the application using the specified options"*; returns *"`true` if the request is allowed by the system, otherwise `false`"*; the discussion repeats that activation is not guaranteed and that the other app should yield first. Granted 4 of 4 times here without a yield — with a Finder window in front, which the hand check then showed to be the only case in which it is granted (D.6). |
| A window cannot pass another app's key window; `orderFrontRegardless` can | Apple, `NSWindow.orderFrontRegardless()`: *"Normally an NSWindow object can't be moved in front of the key window unless it and the key window are in the same application. You should rarely need to invoke this method."* Both halves observed (D.6). |
| The user can remove a menu bar extra, and the app then quits when it shows only in the menu bar | Apple, `MenuBarExtra` overview: *"An app that only shows in the menu bar will be automatically terminated if the user removes the extra from the menu bar."* Apple, `MenuBarExtra.init(_:systemImage:isInserted:content:)`: *"If the user removes the item from the menu bar, the binding will be set to `false`"*; *"The item will be displayed in the system menu bar when the specified binding is set to `true`."* Observed by you, 2026-09-21, on the Release build with the window closed. |
| The hidden title bar is a safe-area inset; the placement sizes the whole content rect | Observed 2026-09-21 (D.6, P3). Apple, `HiddenTitleBarWindowStyle`, says only that it hides *"the backing of the titlebar area, allowing more of the window's content to show"*; Apple, `Scene.defaultWindowPlacement(_:)`, sizes its own example with `content.sizeThatFits(.unspecified)` and says nothing about safe areas. |
| The XCTest frameworks are not copied into the host | Observed 2026-09-21 (D.6, P12): no `Contents/Frameworks` in the app after a hosted run; the frameworks' image paths are under `/Applications/Xcode.app/Contents/SharedFrameworks`. |
| Shared project xcconfigs | `shasum`: Utilities' and SourceTools' `Project-{Common,Debug,Release}.xcconfig` match pairwise; HelloWorld's `Project-Common` differs. |
| The specimen is sound under the current toolchain | 2026-09-21: `xcodebuild` Debug build and test of SourceTools under Xcode 27.0 — build succeeded with 15 of 23 object files recompiled in that run; 65 tests in 7 suites passed; the app was signed with an Apple Development identity, sandboxed, with the runtime flag. |
| A test run widens the Debug app's entitlements | `codesign -d --entitlements` on SourceTools' Debug app after that `xcodebuild test`: `get-task-allow`; `temporary-exception.files.absolute-path.read-only` = `/`; `temporary-exception.mach-lookup.global-name` = `com.apple.testmanagerd`, `com.apple.dt.testmanagerd.runner`, `com.apple.coresymbolicationd`. I did not list the app's full entitlements before that test run — only counted the sandbox key — so that it is the `test` action which adds them rests on the build system's source (next row), not on a before-and-after observation of mine. SourceTools' tests are not hosted, so nothing was copied into its bundle. |
| How the build system hosts a test bundle; the template's settings; the warning on a `TEST_HOST` mismatch | **[A]** `swiftlang/swift-build` (`ProductTypes.swift`, `ProductPlan.swift`, `XCTestHostTaskProducer`), and Xcode 27's project templates and build-setting specifications on this machine. The open-source build system is the basis of Xcode's, and the shipped copy may differ. |
| `defaultWindowPlacement` | Apple, `Scene.defaultWindowPlacement(_:)`: macOS 15.0+; the example sizing a window with `content.sizeThatFits(.unspecified)`; the sentences on first appearance and on state restoration. |
| `ImageRenderer` exports a `Canvas`; `onGeometryChange` | Apple, `ImageRenderer` (macOS 13.0+; the overview's Canvas export) and `View.onGeometryChange(for:of:action:)` (macOS 13.0+; `T: Equatable & Sendable`; an `@Sendable` transform). |
| `SettingsLink`; Swift Testing attachments | Apple, `SettingsLink` (macOS 14.0+; the page does not say where it may be used) and `Testing.Attachment` (Swift 6.2+, Xcode 26.0+). |
| `nonisolated` on type declarations | Swift Evolution SE-0449, "Allow `nonisolated` to prevent global actor inference", implemented in Swift 6.1. It does not discuss the default-isolation build setting. |
| Tools for the pixel tests and the cost check | `xcrun --find xcresulttool` and `xctrace` both resolve in Xcode 27.0; `xcresulttool export` lists an `attachments` subcommand; `xctrace list templates` includes Time Profiler and SwiftUI. |
| The repository's merge settings | `gh api repos/coreaudio-fan/CPULoadMeter`: squash merges titled by the PR with the commit messages as the body; branches deleted on merge. Identical to SourceTools'. |
