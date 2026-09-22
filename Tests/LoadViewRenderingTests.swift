@testable import CPULoadMeter
import CoreGraphics
import SwiftUI
import Testing

@MainActor
struct LoadViewRenderingTests {

	///	A load of `numerator` sixteenths, exact in binary: the loads used here, 100, 0, 50, 37.5, and 75 percent, are
	///	all whole sixteenths, and in an 8 pt view every one of them is a whole number of points tall.
	private func load(sixteenths numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: numerator, system: 0, idle: 16 - numerator, nice: 0)))
	}

	///	A history holding `newestFirst`, given newest first as the drawing walks it, at exactly that many steps.
	private func history(newestFirst: [UInt32]) -> LoadHistory {
		newestFirst.reversed().reduce(LoadHistory(stepCount: newestFirst.count)) { $0.appending(load(sixteenths: $1)) }
	}

	///	The five loads every case draws: 100, 0, 50, 37.5, and 75 percent, newest first, asymmetric on purpose so that a
	///	flipped axis or a left-anchored walk cannot match. Every line is three device pixels or taller at 1x: the
	///	renderer draws lines of one or two pixels one pixel taller than the geometry says, an observed behavior with no
	///	documentation (Design.md, D.6), so the tests stay on the lines it draws faithfully.
	private let newestFirst: [UInt32] = [16, 0, 8, 6, 12]

	///	Renders a LoadView of `history` at `width` by 8 points, or fails the test.
	private func grid(_ history: LoadHistory, lineWidth: CGFloat, width: CGFloat = 8, scale: CGFloat) throws -> PixelGrid {
		try #require(PixelGrid(of: LoadView(history: history, lineWidth: lineWidth), width: width, height: 8, scale: scale))
	}

	///	Whether pixel (`column`, `row`) is inside some step's line, by the rules of section 5.5: step k's line covers
	///	the points from `width - k - lineWidth` to `width - k`, from the bottom edge up to `load` of the height.
	private func isLit(column: Int, row: Int, newestFirst: [UInt32], lineWidth: CGFloat, width: CGFloat, scale: CGFloat) -> Bool {
		let x = (CGFloat(column) + 0.5) / scale
		let y = (CGFloat(row) + 0.5) / scale
		return newestFirst.enumerated().contains { step, sixteenths in
			let right = width - CGFloat(step)
			let top = 8 - (8 * (CGFloat(sixteenths) / 16))
			return x > (right - lineWidth) && x < right && y > top && y < 8
		}
	}

	///	Checks every pixel of `grid` against the rule: lit pixels carry the reference alpha, the rest none.
	private func expectPattern(_ grid: PixelGrid, newestFirst: [UInt32], lineWidth: CGFloat, width: CGFloat, scale: CGFloat, reference: UInt8, name: String) throws {
		let png = try #require(grid.png)
		Attachment.record(png, named: name)
		for row in 0..<grid.height {
			for column in 0..<grid.width {
				let expected: UInt8 = isLit(column: column, row: row, newestFirst: newestFirst, lineWidth: lineWidth, width: width, scale: scale) ? reference : 0
				let actual = grid.alpha(column: column, row: row)
				#expect(abs(Int(actual) - Int(expected)) <= 2, "pixel (\(column), \(row)) at \(scale)x, \(lineWidth) pt")
			}
		}
	}

	///	The alpha of a pixel inside the newest, full-height line: the reference every lit pixel is compared against.
	private func referenceAlpha(of grid: PixelGrid) throws -> UInt8 {
		let reference = grid.alpha(column: grid.width - 1, row: grid.height / 2)
		try #require(reference > 0, "the full-height line drew nothing")
		return reference
	}

	//	The helper's orientation is checked on a plain stack, so that a flipped helper cannot cancel a flipped view.
	@Test func theTopRowOfTheGridIsTheTopOfTheView() async throws {
		let stack = VStack(spacing: 0) {
			Color.black
			Color.clear
		}
		let grid = try #require(PixelGrid(of: stack, width: 8, height: 8, scale: 1))

		#expect(grid.alpha(column: 3, row: 0) == 255)
		#expect(grid.alpha(column: 3, row: 3) == 255)
		#expect(grid.alpha(column: 3, row: 4) == 0)
		#expect(grid.alpha(column: 3, row: 7) == 0)
	}

	@Test func aOnePointLineAtOneXCoversItsStepExactly() async throws {
		let grid = try grid(history(newestFirst: newestFirst), lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectPattern(grid, newestFirst: newestFirst, lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadview-1pt-1x.png")
	}

	@Test func aOnePointLineAtTwoXCoversTwoByTwoBlocks() async throws {
		let grid = try grid(history(newestFirst: newestFirst), lineWidth: 1, scale: 2)
		let reference = try referenceAlpha(of: grid)

		try expectPattern(grid, newestFirst: newestFirst, lineWidth: 1, width: 8, scale: 2, reference: reference, name: "loadview-1pt-2x.png")
	}

	@Test func aHalfPointLineAtTwoXLightsTheRightPixelOfEachPair() async throws {
		let grid = try grid(history(newestFirst: newestFirst), lineWidth: 0.5, scale: 2)
		let reference = try referenceAlpha(of: grid)

		try expectPattern(grid, newestFirst: newestFirst, lineWidth: 0.5, width: 8, scale: 2, reference: reference, name: "loadview-halfpt-2x.png")
		//	Spelled out for the newest step: pixel column 15 lit, column 14 dark, the whole height.
		#expect(grid.alpha(column: 15, row: 0) == reference)
		#expect(grid.alpha(column: 14, row: 0) == 0)
	}

	//	A fractional width: the lines are anchored to the right edge, so at 8.5 points a 1 pt line at 2x covers pixel
	//	columns 15 and 16 of 17; anchored to the left it would cover 0 and 1.
	@Test func theNewestLineIsAnchoredToTheRightEdge() async throws {
		let grid = try grid(history(newestFirst: [16]), lineWidth: 1, width: 8.5, scale: 2)
		let reference = try referenceAlpha(of: grid)

		#expect(grid.width == 17)
		try expectPattern(grid, newestFirst: [16], lineWidth: 1, width: 8.5, scale: 2, reference: reference, name: "loadview-right-anchored.png")
		#expect(grid.alpha(column: 0, row: 4) == 0)
		#expect(grid.alpha(column: 14, row: 4) == 0)
	}

	@Test func aHistoryLongerThanTheViewDrawsItsNewestSteps() async throws {
		let longer = history(newestFirst: [16, 16, 16, 16, 16, 16, 16, 16, 0, 0, 0, 0])
		let grid = try grid(longer, lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectPattern(grid, newestFirst: Array(repeating: 16, count: 8), lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadview-longer.png")
	}

	@Test func aHistoryShorterThanTheViewLeavesTheLeftBlank() async throws {
		let grid = try grid(history(newestFirst: [16, 16, 16]), lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectPattern(grid, newestFirst: [16, 16, 16], lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadview-shorter.png")
		#expect(grid.alpha(column: 4, row: 7) == 0)
	}

	@Test func aZeroHistoryDrawsNothing() async throws {
		let grid = try grid(LoadHistory(stepCount: 8), lineWidth: 1, scale: 1)

		for row in 0..<grid.height {
			for column in 0..<grid.width {
				#expect(grid.alpha(column: column, row: row) == 0)
			}
		}
	}

}
