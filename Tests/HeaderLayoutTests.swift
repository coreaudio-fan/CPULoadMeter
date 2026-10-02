@testable import CPULoadMeter
import CoreGraphics
import Testing

///	The header's arrangement as a pure function: `HeaderLayout.arrangement(of:inWidth:)`. The pieces here are a name
///	text of 100 × 16, a usage text of 200 × 16, and two controls of 150 × 24 and 160 × 24, so the two rows need 200 + 8
///	+ 160 = 368 points and the column 200.
struct HeaderLayoutTests {

	private let pieces = HeaderLayout.Pieces(name: CGSize(width: 100, height: 16), usage: CGSize(width: 200, height: 16), period: CGSize(width: 150, height: 24), history: CGSize(width: 160, height: 24))

	@Test func twoRowsWhereTheyFitWithTheControlsAtTheTrailingEdge() async throws {
		let arrangement = HeaderLayout.arrangement(of: pieces, inWidth: 500)

		#expect(!(arrangement.isColumn))
		#expect(arrangement.size == CGSize(width: 500, height: 52))
		#expect(arrangement.name == CGRect(x: 0, y: 4, width: 100, height: 16))
		#expect(arrangement.usage == CGRect(x: 0, y: 32, width: 200, height: 16))
		#expect(arrangement.period == CGRect(x: 350, y: 0, width: 150, height: 24))
		#expect(arrangement.history == CGRect(x: 340, y: 28, width: 160, height: 24))
	}

	@Test func aColumnWhereTheRowsDoNotFitWithTheControlsBelowTheTexts() async throws {
		let arrangement = HeaderLayout.arrangement(of: pieces, inWidth: 300)

		#expect(arrangement.isColumn)
		#expect(arrangement.size == CGSize(width: 300, height: 108))
		#expect(arrangement.period == CGRect(x: 0, y: 56, width: 150, height: 24))
		#expect(arrangement.history == CGRect(x: 0, y: 84, width: 160, height: 24))
	}

	//	The rows fit down to the width at which the wider row's text and control are the minimum gap apart, and a point
	//	below that the column takes over.
	@Test func theArrangementChangesWhereTheWiderRowsEndsWouldMeet() async throws {
		#expect(!(HeaderLayout.arrangement(of: pieces, inWidth: 368).isColumn))
		#expect(HeaderLayout.arrangement(of: pieces, inWidth: 367).isColumn)
		#expect(HeaderLayout.arrangement(of: pieces, inWidth: nil) == HeaderLayout.arrangement(of: pieces, inWidth: 368))
	}

	//	What the layout is for: across the change, the two texts are exactly where they were, and no piece is another
	//	size. Only the controls move.
	@Test func theTextsStayInPlaceAndNothingChangesSizeWhenTheArrangementChanges() async throws {
		let rows = HeaderLayout.arrangement(of: pieces, inWidth: 368)
		let column = HeaderLayout.arrangement(of: pieces, inWidth: 367)

		#expect(column.name == rows.name)
		#expect(column.usage == rows.usage)
		#expect(column.period.size == rows.period.size)
		#expect(column.history.size == rows.history.size)
		#expect(column.period.origin != rows.period.origin)
		#expect(column.history.origin != rows.history.origin)
	}

	//	The column is never narrower than its widest piece, however little width it is offered, which is what the
	//	window's minimum width comes from.
	@Test func theColumnIsAtLeastAsWideAsItsWidestPiece() async throws {
		#expect(HeaderLayout.arrangement(of: pieces, inWidth: 0).size == CGSize(width: 200, height: 108))
		#expect(HeaderLayout.arrangement(of: pieces, inWidth: 120).size.width == 200)
	}

}
