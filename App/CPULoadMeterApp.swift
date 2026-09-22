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

	var body: some Scene {
		//	The title is what the Window menu shows. The window itself displays none.
		Window("CPULoadMeter", id: Self.mainWindowID) {
			MainView(processorName: processorName, cpuCount: cpuCount)
		}
		.windowStyle(.hiddenTitleBar)
		.defaultLaunchBehavior(isMainWindowOpenedAtLaunch ? .presented : .suppressed)
		//	Launch behavior applies only in the absence of restored state, so restoration is disabled to let
		//	the checkbox alone decide. That also stops the system saving the window's frame; see Design.md, B.8.
		.restorationBehavior(.disabled)

		Settings {
			SettingsView()
		}

		MenuBarExtra("CPULoadMeter", systemImage: "cpu") {
			MenuBarExtraMenu()
		}
	}

}
