# CPULoadMeter

A macOS Menu Bar Extra that graphs the individual loads of the CPU cores in the menu bar. Version 1 draws the graphs in a window and puts a static item in the menu bar; the live menu bar graph follows.

The app reads the kernel's per-CPU tick counters through `host_processor_info` and reports load the way `top` does: busy ticks over all ticks between two samples, so its numbers agree with `top`, `ps`, and Activity Monitor. It is written in SwiftUI, with the graph drawn by hand.

**Scaffold in progress.** The project builds and its tests run; the window shows the processor's name and the CPU count. `Design.md` is the specification: the design as decided in its body, and the reasoning and evidence behind every decision in its appendices.

## Building

```sh
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug build
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug test
```

The tests are hosted in the app, so a test run launches it. The app is sandboxed and runs with the hardened runtime; both kernel reads work under the plain sandbox with no exception entitlements.
