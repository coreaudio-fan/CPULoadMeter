import Foundation

///	What the graph and the model share about the graph's geometry.
enum LoadGraph {

	///	The width of one step: one point, so a view's width in points is its step count, and one history load is one
	///	line. Read by the view that draws, by the view that measures its width, and by the app when it starts the
	///	monitor from a stored width. Design.md, sections 2.8 and 5.5.
	static let stepLength: CGFloat = 1

	///	The step count for a width: the whole steps that fit.
	static func stepCount(forWidth width: CGFloat) -> Int {
		Int(width / stepLength)
	}

}
