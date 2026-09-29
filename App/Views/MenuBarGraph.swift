import SwiftUI

///	The menu bar's graph: every CPU's history side by side in one `Canvas`, the first CPU leftmost, a divider between
///	neighbors and an endcap at each end, every CPU's graph the same width, which is a setting. The rows of the window's
///	stack laid end to end, in effect, and drawn by the same rule: one line per point of width, the history fitted to
///	them. A pure function of its input.
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

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	The width of one CPU's graph in points, whatever its history holds.
	let graphWidth: CGFloat

	///	The stroke width, as in the window: one point tiles the steps into a solid silhouette.
	var lineWidth: CGFloat = 1

	var body: some View {
		Canvas { context, size in
			let plot = histories.enumerated().reduce(into: Path()) { path, graph in
				LoadStackView.appendLines(of: graph.element, to: &path, in: Self.graphRect(graph.offset, graphWidth: graphWidth, height: size.height), lineWidth: lineWidth)
			}
			context.stroke(plot, with: .color(.black), lineWidth: lineWidth)

			//	One divider slot before every graph, and one more after the last: the endcaps are the first and last.
			let dividers = (0...histories.count).reduce(into: Path()) { path, slot in
				path.addRect(CGRect(x: Self.dividerX(slot, graphWidth: graphWidth), y: 0, width: Self.dividerWidth, height: size.height))
			}
			context.fill(dividers, with: .color(.black.opacity(Self.dividerOpacity)))
		}
		.frame(width: Self.width(cpuCount: histories.count, graphWidth: graphWidth), height: Self.height)
	}

	///	The distance from one divider's left edge to the next: the divider, a gap, the graph, and a gap.
	private static func pitch(graphWidth: CGFloat) -> CGFloat {
		dividerWidth + gap + graphWidth + gap
	}

	///	The whole graph's width: a divider slot before every graph and one after the last, with the gaps.
	static func width(cpuCount: Int, graphWidth: CGFloat) -> CGFloat {
		(CGFloat(max(cpuCount, 0)) * pitch(graphWidth: graphWidth)) + dividerWidth
	}

	///	Divider `slot`'s left edge: slot 0 is the left endcap, slot n the divider after CPU n − 1.
	static func dividerX(_ slot: Int, graphWidth: CGFloat) -> CGFloat {
		CGFloat(slot) * pitch(graphWidth: graphWidth)
	}

	///	CPU `index`'s rectangle: the graph width wide, the full height, a divider and a gap in from its slot.
	static func graphRect(_ index: Int, graphWidth: CGFloat, height: CGFloat) -> CGRect {
		CGRect(x: dividerX(index, graphWidth: graphWidth) + dividerWidth + gap, y: 0, width: graphWidth, height: height)
	}

}
