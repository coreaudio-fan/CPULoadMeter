# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Purpose

**CPULoadMeter** is a macOS app that graphs the load on each CPU core over time, drawn by hand in SwiftUI, with a Menu Bar Extra that will ultimately carry the graph in the menu bar. See `~/.claude/CLAUDE.md` for the global style guide.

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

Scaffold in progress; full documentation lands with the project.
