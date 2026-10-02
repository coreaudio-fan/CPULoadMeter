# CPULoadMeter

A macOS app that graphs the load on each CPU core over time, drawn by hand in SwiftUI, in a window and in the menu bar.

The app reads the kernel's per-CPU tick counters through `host_processor_info` and reports load the way `top` does: busy ticks over all ticks between two samples, so its numbers agree with `top` and Activity Monitor to the tick. It is sandboxed, runs with the hardened runtime, and touches nothing but the two kernel reads.

## What it shows

- **The header**, in two lines where the window is wide enough and in one column where it is not, the controls moving below the texts without changing size: the processor's name and core count; the machine-wide usage in `top`'s wording — `CPU usage: 8% user, 4% system, 88% idle` — the update period, *Sample every … seconds*, a whole number of seconds from 1 to 60 with presets of 1, 2, 5, 10, 15, 30, 45, and 60; and the history length, how many samples the graphs hold, from 15 to 600 with presets of 15, 30, 45, 60, 90, 120, 150, 180, 300, and 600. The two are independent: the period sets how fast samples arrive, and so how fast the graph moves and how much time it spans, and never how finely it is drawn. A typed value takes effect on Return or when the field loses focus; anything that is not a whole number in range is rejected and the field reverts.
- **One graph per core**, top to bottom in the kernel's order, sharing the window's height — all drawn in one canvas, since SwiftUI's cost is in laying out views, not in strokes. Each is a stroked path of vertical lines, one for every point of width, the newest load at the right edge and the height the load's share of the interval. The history holds as many samples as the history length says, and is fitted to the width: with more points than samples a sample is a crisp block several points wide, and with more samples than points each point shows the peak of the samples it stands for, so no spike is lost. Resizing the window is a zoom. The history is not kept between launches.
- **The menu bar item**: every core's graph side by side, the first core leftmost, a faint 3-point divider between with a point of clear space on either side, and an endcap at each end — drawn by the same rules, one point per step, and handed to the system as a template image so that it is colored for the menu bar, light or dark, and for the selected item. It has two settings of its own: an update period like the window's, and the width of each core's graph, 15 to 60 points (presets 15, 20, 25, 30, 45, 60; 15 by default). The width is also its history: one sample for every point. Its menu opens the main window and the settings. Closing the window leaves the app running; the Window menu and the item bring it back.

Sampling for the window runs while the window is shown; closing it stops sampling and drops the history, and reopening starts fresh, as at launch. The menu bar graph samples on a monitor of its own for the life of the process. A failed read keeps the last good sample as the baseline, so the next success averages over the longer interval; a change in the number of CPUs takes a new baseline. Colors are the system's: the plot in the label color, the hairlines in the separator color, so Light and Dark need no code.

## Building

```sh
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug build
xcodebuild -project CPULoadMeter.xcodeproj -scheme App -configuration Debug test
```

The tests are hosted in the app, so a test run launches it. The drawing is tested on its pixels — `ImageRenderer` renders a graph and every pixel's alpha is compared with the pattern the drawing rules predict — and the sampler is tested through a scripted reader and a scripted sleep, so no test waits on a clock.

## Known limitations

- *Show CPULoadMeter* in the menu bar item's menu does not bring the app to the foreground while another app is active. SwiftUI has no way to activate an app, and the AppKit requests tried were declined by the system or granted only with a Finder window in front; deferred.
- The menu bar item can be command-dragged out of the menu bar, as any can, and doing so with the window closed quits the app, as macOS documents for an app that then shows only in the menu bar.
- Nothing stops the menu bar item being set wider than the menu bar has room for, and macOS does not show an item that does not fit. The app keeps running; reduce the graph width in Settings, from the application menu, to bring it back.
- The app has no icon yet.

`Design.md` is the specification: the design as decided in its body, and in its appendices the reasoning behind every decision, what `top`, `ps`, and the kernel do, the experiments, and every bring-up result with its evidence.
