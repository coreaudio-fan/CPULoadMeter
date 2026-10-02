import Foundation

///	The limits of the window's history: 15 to 600 samples, 300 by default. The numbers are the user's (Design.md, D42):
///	600 is ten minutes at a one-second period, and the presets run through the spans a reader would pick, 15 seconds to
///	ten minutes at that period.
enum WindowHistoryLimits: SettingLimits {
	static let range = 15...600
	static let presetValues = [15, 30, 45, 60, 90, 120, 150, 180, 300, 600]
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
