///	The names under which the app keeps its settings in `UserDefaults`.
///
///	They are gathered here because more than one view reads the same setting, and a key spelled two ways is two
///	settings. The app and its views read and write these; the monitor and the core touch no defaults.
enum DefaultsKey {

	///	Whether the main window opens at launch. A `Bool`, true when absent.
	static let isMainWindowOpenedAtLaunch = "isMainWindowOpenedAtLaunch"

	///	The sampling period in whole seconds. An `Int`, 1 when absent; a stored value out of range falls back to the
	///	default.
	static let samplingPeriodSeconds = "samplingPeriodSeconds"

	///	The window's history length in samples. An `Int`, 300 when absent; a stored value out of range falls back to the
	///	default.
	static let historySamples = "historySamples"

	///	The width of one CPU's graph in the menu bar in whole points. An `Int`, 30 when absent; a stored value out of
	///	range falls back to the default.
	static let menuBarGraphWidth = "menuBarGraphWidth"

	///	The menu bar graph's sampling period in whole seconds. An `Int`, 1 when absent; a stored value out of range
	///	falls back to the default.
	static let menuBarPeriodSeconds = "menuBarPeriodSeconds"

	///	The menu bar graph's history length in samples. An `Int`, 60 when absent; a stored value out of range falls back
	///	to the default.
	static let menuBarHistorySamples = "menuBarHistorySamples"

	///	The main window's last width in points. A `Double`, absent until the window has been shown.
	static let mainWindowWidth = "mainWindowWidth"

	///	The main window's last height in points. A `Double`, absent until the window has been shown.
	static let mainWindowHeight = "mainWindowHeight"

}
