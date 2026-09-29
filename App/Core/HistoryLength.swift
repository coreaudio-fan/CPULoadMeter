import Foundation

///	Limits of a history length: how many seconds of load a graph shows.
protocol HistoryLimits: SecondsLimits {
}

///	The limits of the window's history: 30 seconds to an hour, five minutes by default. A window has room to show far
///	more than the menu bar does, and the longer lengths are where several samples come to share a point.
enum WindowHistoryLimits: HistoryLimits {
	static let range = 30...3_600
	static let presetValues = [60, 300, 900, 3_600]
	static let defaultValue = 300
}

///	The limits of the menu bar graph's history: 30 seconds to two minutes, one minute by default.
enum MenuBarHistoryLimits: HistoryLimits {
	static let range = 30...120
	static let presetValues = [30, 60, 90, 120]
	static let defaultValue = 60
}

///	How many seconds of load the window's graphs show. Design.md, sections 2.10, 2.11, and 4.1.
typealias WindowHistoryLength = BoundedSetting<WindowHistoryLimits>

///	How many seconds of load the menu bar graph shows. Design.md, sections 2.4, 2.12, and 4.1.
typealias MenuBarHistoryLength = BoundedSetting<MenuBarHistoryLimits>

extension BoundedSetting where Limits: HistoryLimits {

	///	The samples a history of this length holds at `period`: the whole periods that fit, a partial one dropped, and
	///	never fewer than one. How wide a sample is drawn is no part of this: that is the graph's width divided among the
	///	samples, which the drawing works out (`LoadHistory.steps(count:)`).
	func sampleCount(at period: SamplingPeriod) -> Int {
		max(1, seconds / period.seconds)
	}

}
