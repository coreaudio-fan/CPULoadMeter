import Foundation

///	What the graph and the model share about the graph's geometry.
enum LoadGraph {

	///	The width of one step: one point, so a graph's width in points is its step count, and the path has one line per
	///	point whatever the history holds. How many samples those steps stand for is the history's business
	///	(`LoadHistory.steps(count:)`). Design.md, sections 2.8 and 5.5.
	static let stepLength: CGFloat = 1

	///	The step count for a width: the whole steps that fit.
	static func stepCount(forWidth width: CGFloat) -> Int {
		Int(width / stepLength)
	}

}
