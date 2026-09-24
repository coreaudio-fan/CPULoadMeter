import SwiftUI

///	The menu bar's graph: every CPU's history side by side in one `Canvas`, the first CPU leftmost, a divider between
///	neighbors and an endcap at each end, each graph as many steps wide as its history holds and every step one point.
///	The rows of the window's stack laid end to end, in effect, and drawn by the same rule. A pure function of its input.
///
///	It is drawn in black and clear only, because it is shown as a template image: the system colors a template for the
///	menu bar it sits in, light or dark, and for the item's selected state, which is what Apple asks of a menu bar
///	extra's image. The dividers are wide and faint, black at a quarter opacity, and stand a point clear of the graphs on
///	either side, so that they read as furniture rather than as samples; the endcaps are dividers too, so that the item's
///	whole extent is drawn. Chosen by eye from a sampler of eight styles (Design.md, D.6). Design.md, sections 2.4, 2.13,
///	and 5.5.
struct MenuBarGraph: View {

	///	The graph's height in points, fitting the menu bar's 22 pt item with a margin.
	static let height: CGFloat = 16

	///	The width of a divider, and of each endcap.
	static let dividerWidth: CGFloat = 3

	///	The divider's opacity: black at this alpha, over a plot at full alpha.
	static let dividerOpacity = 0.25

	///	The clear space between a divider and the graph on either side of it.
	static let gap: CGFloat = 1

	///	One history per CPU, in CPU ID order, all at the same step count.
	let histories: [LoadHistory]

	///	The stroke width, as in the window: one point tiles the steps into a solid silhouette.
	var lineWidth: CGFloat = 1

	var body: some View {
		let stepCount = histories.first?.stepCount ?? 0
		Canvas { context, size in
			let plot = histories.enumerated().reduce(into: Path()) { path, graph in
				LoadStackView.appendLines(of: graph.element, to: &path, in: Self.graphRect(graph.offset, stepCount: stepCount, height: size.height), lineWidth: lineWidth)
			}
			context.stroke(plot, with: .color(.black), lineWidth: lineWidth)

			//	One divider slot before every graph, and one more after the last: the endcaps are the first and last.
			let dividers = (0...histories.count).reduce(into: Path()) { path, slot in
				path.addRect(CGRect(x: Self.dividerX(slot, stepCount: stepCount), y: 0, width: Self.dividerWidth, height: size.height))
			}
			context.fill(dividers, with: .color(.black.opacity(Self.dividerOpacity)))
		}
		.frame(width: Self.width(cpuCount: histories.count, stepCount: stepCount), height: Self.height)
	}

	///	The distance from one divider's left edge to the next: the divider, a gap, the graph, and a gap.
	private static func pitch(stepCount: Int) -> CGFloat {
		dividerWidth + gap + (CGFloat(stepCount) * LoadGraph.stepLength) + gap
	}

	///	The whole graph's width: a divider slot before every graph and one after the last, with the gaps.
	static func width(cpuCount: Int, stepCount: Int) -> CGFloat {
		(CGFloat(max(cpuCount, 0)) * pitch(stepCount: stepCount)) + dividerWidth
	}

	///	Divider `slot`'s left edge: slot 0 is the left endcap, slot n the divider after CPU n − 1.
	static func dividerX(_ slot: Int, stepCount: Int) -> CGFloat {
		CGFloat(slot) * pitch(stepCount: stepCount)
	}

	///	CPU `index`'s rectangle: its steps wide, the full height, a divider and a gap in from its slot.
	static func graphRect(_ index: Int, stepCount: Int, height: CGFloat) -> CGRect {
		CGRect(x: dividerX(index, stepCount: stepCount) + dividerWidth + gap, y: 0, width: CGFloat(stepCount) * LoadGraph.stepLength, height: height)
	}

}
