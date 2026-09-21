///	The names under which the app keeps its settings in `UserDefaults`.
///
///	They are gathered here because more than one view reads the same setting, and a key spelled two ways is
///	two settings. The app and its views read and write these; the monitor and the core touch no defaults.
enum DefaultsKey {

	///	Whether the main window opens at launch. A `Bool`, true when absent.
	static let isMainWindowOpenedAtLaunch = "isMainWindowOpenedAtLaunch"

}
