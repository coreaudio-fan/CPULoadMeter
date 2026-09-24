@testable import CPULoadMeter
import CoreGraphics
import SwiftUI
import Testing

@MainActor
struct LoadStackViewRenderingTests {

	///	A load of `numerator` sixteenths, exact in binary: the loads used here, 100, 0, 50, 37.5, and 75 percent, are
	///	all whole sixteenths, and in an 8 pt row every one of them is a whole number of points tall.
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

	///	Renders a stack of `histories`, each row 8 points tall, at `width` points, or fails the test.
	private func grid(_ histories: [LoadHistory], lineWidth: CGFloat, width: CGFloat = 8, scale: CGFloat) throws -> PixelGrid {
		let stack = LoadStackView(histories: histories, lineWidth: lineWidth, reportStepCount: { _ in })
		return try #require(PixelGrid(of: stack, width: width, height: 8 * CGFloat(histories.count), scale: scale))
	}

	///	Whether pixel (`column`, `row`) is inside some step's line of one 8 pt row whose top is `rowTop` in points, by
	///	the rules of section 5.5: step k's line covers the points from `width - k - lineWidth` to `width - k`, from the
	///	row's bottom edge up by `load` of its height.
	private func isLit(column: Int, row: Int, rowTop: CGFloat, newestFirst: [UInt32], lineWidth: CGFloat, width: CGFloat, scale: CGFloat) -> Bool {
		let x = (CGFloat(column) + 0.5) / scale
		let y = (CGFloat(row) + 0.5) / scale
		return newestFirst.enumerated().contains { step, sixteenths in
			let right = width - CGFloat(step)
			let top = rowTop + 8 - (8 * (CGFloat(sixteenths) / 16))
			return x > (right - lineWidth) && x < right && y > top && y < (rowTop + 8)
		}
	}

	///	Checks every pixel of one row of `grid` against the rule: lit pixels carry the reference alpha, the rest none.
	///	The row's top pixel row is skipped for every row but the first, because the hairline is drawn there.
	private func expectRow(_ grid: PixelGrid, rowIndex: Int, newestFirst: [UInt32], lineWidth: CGFloat, width: CGFloat, scale: CGFloat, reference: UInt8, name: String) throws {
		let png = try #require(grid.png)
		Attachment.record(png, named: name)
		let rowTop = 8 * CGFloat(rowIndex)
		let firstPixelRow = Int(rowTop * scale) + (rowIndex > 0 ? 1 : 0)
		for row in firstPixelRow..<Int((rowTop + 8) * scale) {
			for column in 0..<grid.width {
				let expected: UInt8 = isLit(column: column, row: row, rowTop: rowTop, newestFirst: newestFirst, lineWidth: lineWidth, width: width, scale: scale) ? reference : 0
				let actual = grid.alpha(column: column, row: row)
				#expect(abs(Int(actual) - Int(expected)) <= 2, "pixel (\(column), \(row)) at \(scale)x, \(lineWidth) pt, row \(rowIndex)")
			}
		}
	}

	///	The alpha of a pixel inside the first row's newest, full-height line: the reference every lit pixel is compared
	///	against.
	private func referenceAlpha(of grid: PixelGrid) throws -> UInt8 {
		let reference = grid.alpha(column: grid.width - 1, row: 4)
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
		let grid = try grid([history(newestFirst: newestFirst)], lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectRow(grid, rowIndex: 0, newestFirst: newestFirst, lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadstack-1pt-1x.png")
	}

	@Test func aOnePointLineAtTwoXCoversTwoByTwoBlocks() async throws {
		let grid = try grid([history(newestFirst: newestFirst)], lineWidth: 1, scale: 2)
		let reference = try referenceAlpha(of: grid)

		try expectRow(grid, rowIndex: 0, newestFirst: newestFirst, lineWidth: 1, width: 8, scale: 2, reference: reference, name: "loadstack-1pt-2x.png")
	}

	@Test func aHalfPointLineAtTwoXLightsTheRightPixelOfEachPair() async throws {
		let grid = try grid([history(newestFirst: newestFirst)], lineWidth: 0.5, scale: 2)
		let reference = try referenceAlpha(of: grid)

		try expectRow(grid, rowIndex: 0, newestFirst: newestFirst, lineWidth: 0.5, width: 8, scale: 2, reference: reference, name: "loadstack-halfpt-2x.png")
		#expect(grid.alpha(column: 15, row: 0) == reference)
		#expect(grid.alpha(column: 14, row: 0) == 0)
	}

	//	A fractional width: the lines are anchored to the right edge, so at 8.5 points a 1 pt line at 2x covers pixel
	//	columns 15 and 16 of 17; anchored to the left it would cover 0 and 1.
	@Test func theNewestLineIsAnchoredToTheRightEdge() async throws {
		let grid = try grid([history(newestFirst: [16])], lineWidth: 1, width: 8.5, scale: 2)
		let reference = try referenceAlpha(of: grid)

		#expect(grid.width == 17)
		try expectRow(grid, rowIndex: 0, newestFirst: [16], lineWidth: 1, width: 8.5, scale: 2, reference: reference, name: "loadstack-right-anchored.png")
		#expect(grid.alpha(column: 0, row: 4) == 0)
		#expect(grid.alpha(column: 14, row: 4) == 0)
	}

	@Test func aHistoryLongerThanTheViewDrawsItsNewestSteps() async throws {
		let longer = history(newestFirst: [16, 16, 16, 16, 16, 16, 16, 16, 0, 0, 0, 0])
		let grid = try grid([longer], lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectRow(grid, rowIndex: 0, newestFirst: Array(repeating: 16, count: 8), lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadstack-longer.png")
	}

	@Test func aHistoryShorterThanTheViewLeavesTheLeftBlank() async throws {
		let grid = try grid([history(newestFirst: [16, 16, 16])], lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		try expectRow(grid, rowIndex: 0, newestFirst: [16, 16, 16], lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadstack-shorter.png")
		#expect(grid.alpha(column: 4, row: 7) == 0)
	}

	@Test func zeroHistoriesDrawNothing() async throws {
		let grid = try grid([LoadHistory(stepCount: 8), LoadHistory(stepCount: 8)], lineWidth: 1, scale: 1)

		for row in 0..<grid.height where row != 8 {
			for column in 0..<grid.width {
				#expect(grid.alpha(column: column, row: row) == 0, "pixel (\(column), \(row))")
			}
		}
	}

	//	Three rows: each CPU's history in its own row, top to bottom in order, with a hairline on each boundary.
	@Test func eachRowDrawsItsOwnHistoryWithAHairlineBetween() async throws {
		let rows: [[UInt32]] = [newestFirst, [16, 16, 16], [12, 12, 12, 12, 12, 12, 12, 12]]
		let grid = try grid(rows.map { history(newestFirst: $0) }, lineWidth: 1, scale: 1)
		let reference = try referenceAlpha(of: grid)

		#expect(grid.height == 24)
		for (rowIndex, loads) in rows.enumerated() {
			try expectRow(grid, rowIndex: rowIndex, newestFirst: loads, lineWidth: 1, width: 8, scale: 1, reference: reference, name: "loadstack-three-rows.png")
		}
		//	The hairlines: every pixel of rows 8 and 16 is drawn, in a color that is not the plot's.
		for column in 0..<grid.width {
			#expect(grid.alpha(column: column, row: 8) > 0)
			#expect(grid.alpha(column: column, row: 16) > 0)
		}
		#expect(grid.alpha(column: 0, row: 8) != reference)
	}

}
