import Foundation

///	Limits of a history length: how many samples of load a graph holds.
protocol HistoryLimits: SettingLimits {
}

///	The limits of the window's history: 30 to 3,600 samples, 300 by default. A window has room to show far more than the
///	menu bar does, and the longer lengths are where several samples come to share a point.
enum WindowHistoryLimits: HistoryLimits {
	static let range = 30...3_600
	static let presetValues = [60, 300, 900, 3_600]
	static let defaultValue = 300
}

///	The limits of the menu bar graph's history: 30 to 120 samples, 60 by default.
enum MenuBarHistoryLimits: HistoryLimits {
	static let range = 30...120
	static let presetValues = [30, 60, 90, 120]
	static let defaultValue = 60
}

///	How many samples of load the window's graphs hold. Design.md, sections 2.10, 2.11, and 4.1.
typealias WindowHistoryLength = BoundedSetting<WindowHistoryLimits>

///	How many samples of load the menu bar graph holds. Design.md, sections 2.4, 2.12, and 4.1.
typealias MenuBarHistoryLength = BoundedSetting<MenuBarHistoryLimits>

extension BoundedSetting where Limits: HistoryLimits {

	///	The samples a history of this length holds, which is the setting itself. The length is in samples and not in
	///	seconds so that the period has no part in it: the period sets how fast the samples arrive, and so how much time
	///	the graph spans and how fast it moves, and never how finely it is drawn (Design.md, D32). How wide a sample is
	///	drawn is no part of this either: that is the graph's width divided among the samples, which the drawing works
	///	out (`LoadHistory.steps(count:)`).
	var sampleCount: Int {
		value
	}

}
