import SwiftUI

///	Every CPU's graph, drawn in one `Canvas`: one row per CPU in CPU ID order from the top, the rows sharing the height
///	equally, a hairline on each boundary, and in each row the CPU's history as vertical lines rising from the row's
///	bottom edge, the newest at the right edge and each older one a step further left. A pure function of its input.
///
///	One canvas rather than one view per CPU because SwiftUI's cost is in laying out and compositing views, not in the
///	strokes: 24 canvases and 23 hairlines re-laid-out every sample cost the app 1.6% of a core and WindowServer 4
///	points, one canvas 0.5% and 0.4 (Design.md, D22 and D.6). The per-row drawing rules are section 5.5's. The canvas
///	carries no accessibility: VoiceOver was seen to attach only to the header's two controls, whatever the graphs
///	offered (D22). It measures its own width and reports the step count that width holds, which is the one place the
///	model depends on view geometry. Design.md, sections 2.7, 4.2, 5.3, and 5.5.
struct LoadStackView: View {

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	The stroke width. One point tiles the steps into a solid silhouette; half a point gives, at 2x, a one-pixel line
	///	and a one-pixel gap. A parameter so that the rendering tests exercise more than one, and because the menu-bar
	///	graph wants its own.
	var lineWidth: CGFloat = 1

	///	Told the step count whenever the width changes: the monitor's `setStepCount`.
	let reportStepCount: @MainActor (Int) -> Void

	///	The size of one device pixel in points, for the hairlines.
	@Environment(\.pixelLength) private var pixelLength

	///	Whether the view has appeared. Before it has, SwiftUI lays the window out once at a default size that no one
	///	sees -- 900 points wide here -- and reporting that width would cut a history built while no window was open down
	///	to 900 steps before the placement widened it again with zeros. The report at the placed width arrives after
	///	`onAppear` (observed 2026-09-22; Design.md, D.6), and if one ever did not, nothing would be lost: the monitor's
	///	initial count comes from the same stored width the placement uses.
	@State private var hasAppeared = false

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
		.frame(minHeight: 8 * CGFloat(histories.count), idealHeight: 20 * CGFloat(histories.count), maxHeight: .infinity)
		.onGeometryChange(for: Int.self) { proxy in
			LoadGraph.stepCount(forWidth: proxy.size.width)
		} action: { stepCount in
			if hasAppeared {
				reportStepCount(stepCount)
			}
		}
		.onAppear {
			hasAppeared = true
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

	///	Appends one history's lines to `path`, drawn in `rect` by the rules of Design.md section 5.5: step 0 is the
	///	newest load at the right edge, each later step one step length further left, each line rising from the bottom
	///	edge by the load's share of the height, its center half a line width left of a whole point, so that a 1 pt
	///	stroke fills its step exactly and a 0.5 pt stroke covers the right pixel of the pair at 2x. A zero load is a
	///	zero-length segment, which the butt cap draws as nothing. The prefix covers the frame or two during a live
	///	resize in which the history has not yet caught up with the view.
	static func appendLines(of history: LoadHistory, to path: inout Path, in rect: CGRect, lineWidth: CGFloat) {
		let steps = history.loads.reversed().prefix(LoadGraph.stepCount(forWidth: rect.width)).enumerated()
		for step in steps {
			let x = rect.maxX - (CGFloat(step.offset) * LoadGraph.stepLength) - (lineWidth / 2)
			path.move(to: CGPoint(x: x, y: rect.maxY))
			path.addLine(to: CGPoint(x: x, y: rect.maxY - (rect.height * step.element.total)))
		}
	}


}
