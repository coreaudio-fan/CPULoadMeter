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

- `App/Core/` is the pure core plus the two kernel readers. Everything at top level here is marked `nonisolated`, because the App target defaults to `MainActor` isolation and the Tests target does not: a missed annotation fails the *test* build with "main actor-isolated global function … cannot be called from outside of the actor", which is the compile-time guard (observed 2026-09-21).
  - `CPUTicks` names the kernel's four cumulative counters. They are 32-bit and wrap; nothing compares them except by wrapping subtraction.
  - `readProcessorTicks()` calls `host_processor_info` and returns `[CPUTicks]` with the failure in its signature, `throws(MachError)`. The kernel allocates the reply in this task on every call and nothing frees it but the caller, so the `vm_deallocate` is a `defer` in that one function and no pointer escapes. The host port is obtained once, in a file-scope `let`, as libtop does.
  - `readProcessorName()` reads `machdep.cpu.brand_string` with `sysctlbyname`.
- `App/Views/` holds the SwiftUI views. `MainView` is a placeholder until the header and the graphs land. `MenuBarExtraMenu`'s *Show CPULoadMeter* calls `openWindow` and nothing else: with another app active it does **not** bring the app to the foreground, a known limitation of version 1 that Design.md D19 and §8 record and defer. The design is pure SwiftUI — no `import AppKit`, no app delegate, no `NSViewRepresentable` — and any AppKit call needs a decision recorded in the spec; see the Findings below for the two that were tried here and rolled back.
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
| `App-*.xcconfig` | App target: platform, packaging, runpath, entitlements, hardened runtime, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| `Tests-*.xcconfig` | Test bundle: platform, packaging, and the host — `TEST_HOST` and `BUNDLE_LOADER` |
| `App.entitlements` | The sandbox alone |

Deliberate divergences from the siblings' baseline, each on purpose:

- `RUN_DOCUMENTATION_COMPILER = NO` on both targets. The project publishes no API — there is no framework — so there is nothing for the documentation compiler to enforce. HelloWorld takes the same position.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in `App-Common.xcconfig` only, mirroring Apple's app template; the project baseline stays `nonisolated` for the Tests target, which is what makes the `nonisolated` annotations in `App/Core/` compiler-checked.
- The Tests target sets `TEST_HOST` and `BUNDLE_LOADER`, which the siblings' test bundles do not. `TEST_HOST` must equal the app's `$(BUILT_PRODUCTS_DIR)/$(EXECUTABLE_PATH)` exactly; a mismatch is only a build-system warning ("Unable to find a target which creates the host product"), which a warnings-as-errors build does not fail on, so a changed product name has to be checked in the build log. The target sets no signing, runpath, or entitlement overrides: it inherits the project's team signing, which the host's library validation requires.

## Testing

The suite uses **swift-testing** — `import Testing`, `struct` suites, `@Test` functions, `#expect`/`try #require`. 6 tests in 3 suites as of this writing.

**`@testable import` is used here, where the sibling projects forbid it.** That is a decision, recorded in Design.md B.10 and reasoned from the style guide's *Testability* section: a test stands where the API's real clients stand. SourceTools' and Utilities' APIs are published from frameworks to real importers, so a plain import is their clients' position and `@testable` would hide access-control regressions. Nothing here is published: the app's own code, which sees `internal` declarations, is the only client there is, and `@testable import` gives a test exactly that view while `private` stays the enforced line. A framework target existing only so that a plain import could be written would be structure bought to satisfy a guideline whose reason does not arise (*Proportionality*).

**The tests are hosted in the app.** `Tests/HostingTests.swift` asserts it: the tests run inside the app's process (`Bundle.main.bundleIdentifier`), inside its sandbox container (`NSHomeDirectory()`), and can reach the app's internal declarations. A control run with `TEST_HOST` and `BUNDLE_LOADER` removed fails the first two, reporting `com.apple.dt.xctest.tool` and the real home directory (2026-09-21), so the assertions can fail. Because every test runs in the sandboxed app, the readers' smoke tests re-prove on every run that the sandbox permits the kernel calls.

**Two guards were proved able to fire** on 2026-09-21, in scratch copies:

- `readerFreesEveryReplyBuffer` stands in for an invariant the type system cannot express. It calls `readProcessorTicks()` 4,000 times and requires the physical footprint (`task_info`, `TASK_VM_INFO`) to grow by under 16 MB. With the `vm_deallocate` removed it failed with a growth of 65,830,960 bytes — one 16 KB page per call.
- The `nonisolated` annotations in `App/Core/` are guarded by the build, not by a test: with `nonisolated` dropped from `readProcessorTicks()`, the test build failed at `Tests/ProcessorTicksReaderTests.swift:19`.

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

### The menu bar extra, seen from inside (2026-09-21)

`CGWindowListCopyWindowInfo` from another process does not show the status item in a form this project could interpret. From inside the app, `NSApplication.shared.windows` lists it plainly: an `NSStatusBarWindow`, visible, level 25, 32×30 at the top-right of the menu bar; and the Window menu lists `CPULoadMeter`, the signature of the inserted-extra lifetime that Design.md D.2 established. That observation was a disposable hosted test importing AppKit; the app itself imports none.
