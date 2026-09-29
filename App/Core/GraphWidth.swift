import Foundation

///	The limits of the menu bar graph's width per CPU: 10 to 120 points, 30 by default. The floor is what keeps a graph
///	wide enough to read, whatever the period and the history length are set to.
enum GraphWidthLimits: SettingLimits {
	static let range = 10...120
	static let presetValues = [20, 30, 40, 60]
	static let defaultValue = 30
}

///	The width of one CPU's graph in the menu bar, in whole points. Design.md, sections 2.4, 2.12, and 4.1.
typealias GraphWidth = BoundedSetting<GraphWidthLimits>

extension BoundedSetting where Limits == GraphWidthLimits {

	///	The width as the drawing measures it.
	var points: CGFloat {
		CGFloat(value)
	}

}
