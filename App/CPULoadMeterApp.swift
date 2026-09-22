import SwiftUI

///	The CPULoadMeter app: one main window, the settings window, and an item in the menu bar.
///
///	The order of the scenes, and the presence of the menu bar extra, are load-bearing. An app whose only scene
///	is a `Window` quits when that window closes; it is the extra's presence in the menu bar that lets this app
///	outlive its window, and that makes SwiftUI list the window in the Window menu and reopen it from there. And
///	`Window` has to be declared before `MenuBarExtra`, or the window is not presented at launch even when asked
///	for. Both were established by experiment and are recorded in Design.md, B.1 and D.2. No `isInserted` binding
///	is offered for the extra, because an app whose extra is out of the menu bar goes back to quitting on close.
@main
struct CPULoadMeterApp: App {

	///	The main window's scene identifier, shared with whatever opens the window.
	static let mainWindowID = "main"

	///	Whether the main window opens at launch: the settings window's one checkbox.
	@AppStorage(DefaultsKey.isMainWindowOpenedAtLaunch) private var isMainWindowOpenedAtLaunch = true

	///	The main window's last width. Optional rather than a zero sentinel: absent means the window has never been
	///	shown, and the type says so.
	@AppStorage(DefaultsKey.mainWindowWidth) private var mainWindowWidth: Double?

	///	The main window's last height, kept with its partner.
	@AppStorage(DefaultsKey.mainWindowHeight) private var mainWindowHeight: Double?

	///	The processor's name, read once at launch; `nil` if the kernel would not say.
	private let processorName: String?

	///	How many CPUs the kernel reported at launch. Zero if the read failed, until the monitor arrives.
	private let cpuCount: Int

	///	Reads the processor's name and the CPU count, and writes the launch diagnostic.
	init() {
		processorName = readProcessorName()
		cpuCount = (try? readProcessorTicks())?.count ?? 0
		Diagnostics.logLaunch(processorName: processorName, cpuCount: cpuCount)
	}

	///	The stored window size when both halves are present, and `nil` otherwise.
	private var storedWindowSize: CGSize? {
		if let mainWindowWidth, let mainWindowHeight {
			CGSize(width: mainWindowWidth, height: mainWindowHeight)
		} else {
			nil
		}
	}

	var body: some Scene {
		//	The title is what the Window menu shows. The window itself displays none.
		Window("CPULoadMeter", id: Self.mainWindowID) {
			MainView(processorName: processorName, cpuCount: cpuCount)
				//	Fills the window, so that what is measured below is the window's content, not the view's own size.
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				//	What is stored is the window's whole content rect, which is what the placement below sizes. Under
				//	the hidden title bar the title bar's region is a safe-area inset that the view is laid out below,
				//	32 pt on macOS 27.0, and storing the view's size alone was seen to shrink the window by that inset
				//	on every relaunch (2026-09-21).
				.onGeometryChange(for: CGSize.self) { proxy in
					CGSize(
						width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
						height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
				} action: { size in
					mainWindowWidth = size.width
					mainWindowHeight = size.height
				}
		}
		.windowStyle(.hiddenTitleBar)
		.defaultLaunchBehavior(isMainWindowOpenedAtLaunch ? .presented : .suppressed)
		//	Launch behavior applies only in the absence of restored state, so restoration is disabled to let
		//	the checkbox alone decide. That also stops the system saving the window's frame, so the app saves
		//	the size itself: the content reports it above, and the placement below restores it. Design.md, B.8.
		.restorationBehavior(.disabled)
		//	The content's ideal size is the view's, without the safe-area inset, so a first launch comes up one inset
		//	shorter than ideal. Every later launch uses the stored rect, which is exact.
		.defaultWindowPlacement { content, _ in
			WindowPlacement(size: storedWindowSize ?? content.sizeThatFits(.unspecified))
		}

		Settings {
			SettingsView()
		}

		MenuBarExtra("CPULoadMeter", systemImage: "cpu") {
			MenuBarExtraMenu()
		}
	}

}
