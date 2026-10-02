import Foundation

///	The limits of the window's history: 30 to 3,600 samples, 300 by default. A window has room to show far more than the
///	menu bar does, and the longer lengths are where several samples come to share a point.
enum WindowHistoryLimits: SettingLimits {
	static let range = 30...3_600
	static let presetValues = [60, 300, 900, 3_600]
	static let defaultValue = 300
}

///	How many samples of load the window's graphs hold. The menu bar graph has no such setting: its history is its width
///	(`GraphWidth`). Design.md, sections 2.10, 2.11, and 4.1.
typealias WindowHistoryLength = BoundedSetting<WindowHistoryLimits>

extension BoundedSetting where Limits == WindowHistoryLimits {

	///	The samples a history of this length holds, which is the setting itself. The length is in samples and not in
	///	seconds so that the period has no part in it: the period sets how fast the samples arrive, and so how much time
	///	the graph spans and how fast it moves, and never how finely it is drawn (Design.md, D32). How wide a sample is
	///	drawn is no part of this either: that is the graph's width divided among the samples, which the drawing works
	///	out (`LoadHistory.steps(count:)`).
	var sampleCount: Int {
		value
	}

}
