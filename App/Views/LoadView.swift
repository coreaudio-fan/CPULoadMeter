import SwiftUI

///	One CPU's load history drawn as one stroked path in a `Canvas`: a vertical line per step, rising from the bottom
///	edge, the newest at the right edge and each older one a step further left. A pure function of its input. Design.md,
///	sections 2.8 and 5.5; the reasoning in B.3.
struct LoadView: View {

	///	The loads, oldest first.
	let history: LoadHistory

	///	The stroke width. One point tiles the steps into a solid silhouette; half a point gives, at 2x, a one-pixel line
	///	and a one-pixel gap. The final default is chosen by eye (Design.md, section 8). A parameter rather than a
	///	constant so that the rendering tests exercise more than one, and because the later menu-bar graph wants its own.
	var lineWidth: CGFloat = 1

	var body: some View {
		Canvas { context, size in
			//	Step 0 is the newest load, at the right edge; each later step is one step length further left. The
			//	prefix covers the frame or two during a live resize in which the history has not yet caught up with the
			//	view.
			let steps = history.loads.reversed().prefix(LoadGraph.stepCount(forWidth: size.width)).enumerated()
			let path = steps.reduce(into: Path()) { path, step in
				//	A line's right edge is a whole point, so its center sits half a line width to the left of one: a 1
				//	pt stroke fills its step exactly, and a 0.5 pt stroke covers the right pixel of the pair at 2x. The
				//	y axis points down: the bottom edge is the height, and a full-height line ends at zero. A zero load
				//	is a zero-length segment, which the butt cap draws as nothing.
				let x = size.width - (CGFloat(step.offset) * LoadGraph.stepLength) - (lineWidth / 2)
				path.move(to: CGPoint(x: x, y: size.height))
				path.addLine(to: CGPoint(x: x, y: size.height * (1 - step.element.total)))
			}
			context.stroke(path, with: .color(.primary), lineWidth: lineWidth)
		}
	}

}
