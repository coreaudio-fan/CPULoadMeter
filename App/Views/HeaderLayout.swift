import SwiftUI

///	The header's layout: four pieces, in this order: the name text, the usage text, the period control, and the history
///	control. Where the width allows, two rows, each with its text at the leading edge and its control at the trailing
///	edge; where it does not, a column of four rows, the texts and then the controls.
///
///	The two texts are in the same place in both arrangements, by construction: every row is as tall as the tallest
///	piece, a control, and a text is centered in its row, so the first two rows are the same rows whichever arrangement
///	the controls are in. Only the controls move, and no piece is ever given a size other than its own. It is a `Layout`
///	and not two alternative stacks so that the pieces are the same views in both arrangements: a field being edited
///	keeps its draft, and a move can be animated. Design.md, sections 2.6 and 5.4, and B.20.
struct HeaderLayout: Layout {

	///	The space between two rows.
	static let rowSpacing: CGFloat = 4

	///	The least space between a text and the control on its row, below which the two rows give way to the column.
	static let minimumGap: CGFloat = 8

	///	The sizes of the four pieces.
	struct Pieces: Equatable {
		let name: CGSize
		let usage: CGSize
		let period: CGSize
		let history: CGSize
	}

	///	Where the four pieces go, and the size they take up together.
	struct Arrangement: Equatable {
		let isColumn: Bool
		let size: CGSize
		let name: CGRect
		let usage: CGRect
		let period: CGRect
		let history: CGRect
	}

	///	The arrangement of `pieces` in `width`, or in the two rows' own width when none is given: the whole of the
	///	layout as a pure function. The two rows are used wherever they fit, which is wherever the wider row's text and
	///	control are at least the minimum gap apart; the column otherwise, which is never narrower than its widest piece.
	static func arrangement(of pieces: Pieces, inWidth width: CGFloat?) -> Arrangement {
		let rowHeight = max(pieces.name.height, pieces.usage.height, pieces.period.height, pieces.history.height)
		let rowsWidth = max(pieces.name.width + minimumGap + pieces.period.width, pieces.usage.width + minimumGap + pieces.history.width)
		let columnWidth = max(pieces.name.width, pieces.usage.width, pieces.period.width, pieces.history.width)
		let isColumn = (width ?? rowsWidth) < rowsWidth
		let fullWidth = isColumn ? max(width ?? columnWidth, columnWidth) : (width ?? rowsWidth)
		let rowCount: CGFloat = isColumn ? 4 : 2

		//	A piece's frame in row `row`: centered in the row's height, at the leading edge or the trailing one.
		func frame(_ size: CGSize, row: CGFloat, isTrailing: Bool) -> CGRect {
			CGRect(x: isTrailing ? (fullWidth - size.width) : 0, y: (row * (rowHeight + rowSpacing)) + ((rowHeight - size.height) / 2), width: size.width, height: size.height)
		}
		return Arrangement(
			isColumn: isColumn,
			size: CGSize(width: fullWidth, height: (rowCount * rowHeight) + ((rowCount - 1) * rowSpacing)),
			name: frame(pieces.name, row: 0, isTrailing: false),
			usage: frame(pieces.usage, row: 1, isTrailing: false),
			period: frame(pieces.period, row: isColumn ? 2 : 0, isTrailing: !isColumn),
			history: frame(pieces.history, row: isColumn ? 3 : 1, isTrailing: !isColumn))
	}

	///	The four pieces' own sizes. The layout is given exactly four subviews, in the order above; with any other number
	///	it lays out nothing.
	private func pieces(of subviews: Subviews) -> Pieces? {
		guard subviews.count == 4 else {
			return nil
		}
		let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
		return Pieces(name: sizes[0], usage: sizes[1], period: sizes[2], history: sizes[3])
	}

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		//	An unbounded width is no width to fill, so it is treated as none given, and the answer is the two rows' own.
		let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
		return pieces(of: subviews).map { Self.arrangement(of: $0, inWidth: width).size } ?? .zero
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		if let pieces = pieces(of: subviews) {
			let arrangement = Self.arrangement(of: pieces, inWidth: bounds.width)
			let frames = [arrangement.name, arrangement.usage, arrangement.period, arrangement.history]
			for (subview, frame) in zip(subviews, frames) {
				subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
			}
		}
	}

}
