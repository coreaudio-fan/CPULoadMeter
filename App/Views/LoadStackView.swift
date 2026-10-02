import SwiftUI

///	Every CPU's graph, drawn in one `Canvas`: one row per CPU in CPU ID order from the top, the rows sharing the height
///	equally, a hairline on each boundary, and in each row the CPU's history as vertical lines rising from the row's
///	bottom edge, one line per point of width, the newest at the right edge. A pure function of its input.
///
///	The history is fitted to the width, not the width to the history: a row has as many lines as it has points, and the
///	history's samples are spread over them, a sample several points wide where points outnumber samples and a point the
///	peak of several samples where samples outnumber points (Design.md, D28 and D29). Resizing the window is therefore a
///	zoom, and the view reports nothing to the model.
///
///	One canvas rather than one view per CPU because SwiftUI's cost is in laying out and compositing views, not in the
///	strokes: 24 canvases and 23 hairlines re-laid-out every sample cost the app 1.6% of a core and WindowServer 4
///	points, one canvas 0.5% and 0.4 (Design.md, D22 and D.6). The per-row drawing rules are section 5.5's. The canvas
///	carries no accessibility: VoiceOver was seen to attach only to the header's two controls, whatever the graphs
///	offered (D22). Design.md, sections 2.7, 4.2, 5.3, and 5.5.
struct LoadStackView: View {

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	The stroke width. One point tiles the steps into a solid silhouette; half a point gives, at 2x, a one-pixel line
	///	and a one-pixel gap. A parameter so that the rendering tests exercise more than one.
	var lineWidth: CGFloat = 1

	///	The size of one device pixel in points, for the hairlines.
	@Environment(\.pixelLength) private var pixelLength

	var body: some View {
		Canvas { context, size in
			let rowHeight = Self.rowHeight(for: size.height, rowCount: histories.count)
			let plot = histories.enumerated().reduce(into: Path()) { path, row in
				Self.appendLines(of: row.element, to: &path, in: Self.rowRect(row.offset, rowHeight: rowHeight, width: size.width), lineWidth: lineWidth)
			}
			context.stroke(plot, with: .color(.primary), lineWidth: lineWidth)

			//	The hairlines sit on the row boundaries, one device pixel tall, drawn over the graphs' top pixel row so
			//	that every row keeps the same height.
			let boundaries = (1..<max(histories.count, 1)).reduce(into: Path()) { path, index in
				let y = rowHeight * CGFloat(index)
				path.addRect(CGRect(x: 0, y: y, width: size.width, height: pixelLength))
			}
			context.fill(boundaries, with: .style(.separator))
		}
	}

	///	The height of every row: the height shared equally, so that adjacent rows may differ by a pixel.
	static func rowHeight(for height: CGFloat, rowCount: Int) -> CGFloat {
		height / CGFloat(max(rowCount, 1))
	}

	///	Row `index`'s rectangle, the full width, counted from the top.
	static func rowRect(_ index: Int, rowHeight: CGFloat, width: CGFloat) -> CGRect {
		CGRect(x: 0, y: rowHeight * CGFloat(index), width: width, height: rowHeight)
	}

	///	Appends one history's lines to `path`, drawn in `rect` by the rules of Design.md section 5.5: the history fitted
	///	to as many steps as the rectangle has whole points of width; step 0 the newest at the right edge, each later
	///	step one step length further left; each line rising from the bottom edge by its load's share of the height, its
	///	center half a line width left of a whole point, so that a 1 pt stroke fills its step exactly and a 0.5 pt stroke
	///	covers the right pixel of the pair at 2x. A zero load is a zero-length segment, which the butt cap draws as
	///	nothing.
	static func appendLines(of history: LoadHistory, to path: inout Path, in rect: CGRect, lineWidth: CGFloat) {
		let steps = history.steps(count: LoadGraph.stepCount(forWidth: rect.width)).enumerated()
		for step in steps {
			let x = rect.maxX - (CGFloat(step.offset) * LoadGraph.stepLength) - (lineWidth / 2)
			path.move(to: CGPoint(x: x, y: rect.maxY))
			path.addLine(to: CGPoint(x: x, y: rect.maxY - (rect.height * step.element.total)))
		}
	}

}
