import AppKit
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

			//	The one AppKit call in the app, and its form matters. SwiftUI's environment offers no action that
			//	activates an app, and with openWindow alone this item did not bring the app to the foreground.
			//	Activation is a request the system may decline, and it declined the bare NSApplication.activate() every
			//	time, from this menu and from a probe; the same request naming the frontmost app as the one handing
			//	activation over was granted every time (Design.md, D.6). The result is the system's answer, and nothing
			//	further can be done with a refusal. Design.md, section 5.2 and B.1.
			_ = NSRunningApplication.current.activate(from: NSWorkspace.shared.frontmostApplication ?? .current, options: [])
		}
		SettingsLink()
	}

}
