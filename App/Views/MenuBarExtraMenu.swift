import SwiftUI

///	The menu shown by the item in the menu bar: a way to the main window, and a way to the settings.
///
///	There is deliberately no Quit item. SwiftUI has no terminate action, and this is a regular app whose application
///	menu and Dock icon already offer Quit; see Design.md, B.1.
struct MenuBarExtraMenu: View {

	///	Opens the main window, or brings it forward if it is already open.
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		Button("Show CPULoadMeter") {
			openWindow(id: CPULoadMeterApp.mainWindowID)
		}
		SettingsLink()
	}

}
