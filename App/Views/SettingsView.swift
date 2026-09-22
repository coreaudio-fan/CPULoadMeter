import SwiftUI

///	The settings window's content: the one setting the app has.
struct SettingsView: View {

	///	Whether the main window opens at launch. The app reads the same key to choose its launch behavior.
	@AppStorage(DefaultsKey.isMainWindowOpenedAtLaunch) private var isMainWindowOpenedAtLaunch = true

	var body: some View {
		Form {
			Toggle("Open main window at launch", isOn: $isMainWindowOpenedAtLaunch)
		}
		.padding(20)
		.frame(width: 360)
	}

}
