import SwiftUI

///	The menu bar's graph: every CPU's history side by side in one `Canvas`, the first CPU leftmost, a divider between
///	neighbors, each graph as many steps wide as its history holds and every step one point. The rows of the window's
///	stack laid end to end, in effect, and drawn by the same rule. A pure function of its input.
///
///	It is drawn in black and clear only, because it is shown as a template image: the system colors a template for the
///	menu bar it sits in, light or dark, and for the item's selected state, which is what Apple asks of a menu bar
///	extra's image. The dividers are black at reduced opacity, the template's only way of saying "secondary". Design.md,
///	sections 2.4, 2.13, and 5.5.
struct MenuBarGraph: View {

	///	The graph's height in points, fitting the menu bar's 22 pt item with a margin.
	static let height: CGFloat = 16

	///	The width of the divider between two CPUs' graphs.
	static let dividerWidth: CGFloat = 1

	///	The divider's opacity: black at this alpha, over a plot at full alpha.
	static let dividerOpacity = 0.4

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

			//	A divider fills the point between each graph's right edge and the next graph's left edge, full height.
			let dividers = (1..<max(histories.count, 1)).reduce(into: Path()) { path, index in
				let graph = Self.graphRect(index, stepCount: stepCount, height: size.height)
				path.addRect(CGRect(x: graph.minX - Self.dividerWidth, y: 0, width: Self.dividerWidth, height: size.height))
			}
			context.fill(dividers, with: .color(.black.opacity(Self.dividerOpacity)))
		}
		.frame(width: Self.width(cpuCount: histories.count, stepCount: stepCount), height: Self.height)
	}

	///	The whole graph's width: every CPU's steps, and a divider between each pair of neighbors.
	static func width(cpuCount: Int, stepCount: Int) -> CGFloat {
		(CGFloat(cpuCount) * CGFloat(stepCount) * LoadGraph.stepLength) + (CGFloat(max(cpuCount - 1, 0)) * dividerWidth)
	}

	///	CPU `index`'s rectangle: its steps wide, the full height, one graph and one divider further right per CPU.
	static func graphRect(_ index: Int, stepCount: Int, height: CGFloat) -> CGRect {
		let graphWidth = CGFloat(stepCount) * LoadGraph.stepLength
		return CGRect(x: CGFloat(index) * (graphWidth + dividerWidth), y: 0, width: graphWidth, height: height)
	}

}
