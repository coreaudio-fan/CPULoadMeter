@testable import CPULoadMeter
import CoreGraphics
import SwiftUI
import Testing

@MainActor
struct MenuBarGraphRenderingTests {

	///	A load of `numerator` sixteenths, exact in binary: the graph is 16 pt tall, so at 1x a load of n sixteenths is a
	///	line exactly n pixels tall.
	private func load(sixteenths numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: numerator, system: 0, idle: 16 - numerator, nice: 0)))
	}

	///	A history holding `newestFirst`, given newest first as the drawing walks it, at exactly that many steps.
	private func history(newestFirst: [UInt32]) -> LoadHistory {
		newestFirst.reversed().reduce(LoadHistory(stepCount: newestFirst.count)) { $0.appending(load(sixteenths: $1)) }
	}

	///	Renders `graphs`, each `stepCount` steps wide, at the graph's own size at 1x, or fails the test.
	private func grid(_ graphs: [[UInt32]]) throws -> PixelGrid {
		let stepCount = graphs.first?.count ?? 0
		let width = MenuBarGraph.width(cpuCount: graphs.count, stepCount: stepCount)
		let graph = MenuBarGraph(histories: graphs.map { history(newestFirst: $0) })
		return try #require(PixelGrid(of: graph, width: width, height: MenuBarGraph.height, scale: 1))
	}

	///	What pixel (`column`, `row`) of a grid of `graphs` should be: lit by a line, covered by a divider, or clear.
	private enum Expectation {
		case line
		case divider
		case clear
	}

	private func expectation(column: Int, row: Int, graphs: [[UInt32]]) -> Expectation {
		let stepCount = graphs[0].count
		let stride = stepCount + Int(MenuBarGraph.dividerWidth)
		let graphIndex = column / stride
		let offset = column % stride
		let result: Expectation
		if offset == stepCount {
			result = .divider
		} else {
			let step = stepCount - 1 - offset
			let lineHeight = Int(graphs[graphIndex][step])
			result = row >= (Int(MenuBarGraph.height) - lineHeight) ? .line : .clear
		}
		return result
	}

	//	Two CPUs, four steps each: CPU 0's graph in columns 0 to 3, the divider in column 4, CPU 1's in 5 to 8. The
	//	loads are asymmetric so that a mirrored layout, or the CPUs swapped, cannot match; every line is three pixels or
	//	taller, which the renderer draws faithfully.
	@Test func theGraphsSitSideBySideFirstCPULeftmostWithADividerBetween() async throws {
		let graphs: [[UInt32]] = [[16, 8, 6, 12], [12, 16, 0, 8]]
		let grid = try grid(graphs)
		let plot = grid.alpha(column: 3, row: 8)
		let divider = grid.alpha(column: 4, row: 8)
		try #require(plot > 0, "the full-height line drew nothing")
		Attachment.record(try #require(grid.png), named: "menubar-two-cpus.png")

		#expect(grid.width == 9)
		#expect(grid.height == 16)
		#expect(divider > 0 && divider < plot, "the divider is fainter than the plot")
		for row in 0..<grid.height {
			for column in 0..<grid.width {
				let actual = grid.alpha(column: column, row: row)
				switch expectation(column: column, row: row, graphs: graphs) {
					case .line: #expect(abs(Int(actual) - Int(plot)) <= 2, "pixel (\(column), \(row)) should be plot")
					case .divider: #expect(abs(Int(actual) - Int(divider)) <= 2, "pixel (\(column), \(row)) should be divider")
					case .clear: #expect(actual == 0, "pixel (\(column), \(row)) should be clear")
				}
			}
		}
	}

	@Test func oneCPUHasNoDivider() async throws {
		let grid = try grid([[16, 16, 16]])

		#expect(grid.width == 3)
		for column in 0..<grid.width {
			#expect(grid.alpha(column: column, row: 0) == grid.alpha(column: 0, row: 0))
		}
	}

	@Test func theWidthIsEveryStepAndADividerBetweenNeighbors() async throws {
		#expect(MenuBarGraph.width(cpuCount: 24, stepCount: 60) == 1_463)
		#expect(MenuBarGraph.width(cpuCount: 1, stepCount: 60) == 60)
		#expect(MenuBarGraph.width(cpuCount: 0, stepCount: 60) == 0)
	}

}
