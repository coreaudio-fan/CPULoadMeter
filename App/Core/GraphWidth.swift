import Foundation

///	The limits of the menu bar graph's width per CPU: 15 to 60 points, 15 by default. The numbers are the user's,
///	settled by living with the item (Design.md, D35).
enum GraphWidthLimits: SettingLimits {
	static let range = 15...60
	static let presetValues = [15, 20, 25, 30, 45, 60]
	static let defaultValue = 15
}

///	The width of one CPU's graph in the menu bar, in whole points, which is also how many samples it holds. Design.md,
///	sections 2.4, 2.12, and 4.1.
typealias GraphWidth = BoundedSetting<GraphWidthLimits>

extension BoundedSetting where Limits == GraphWidthLimits {

	///	The width as the drawing measures it.
	var points: CGFloat {
		CGFloat(value)
	}

	///	The samples a menu bar graph of this width holds: one for every point, so that each line of the graph is its own
	///	sample. The menu bar graph has no history setting; its width is its history (Design.md, D35).
	var sampleCount: Int {
		value
	}

}
