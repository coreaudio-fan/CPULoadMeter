@testable import CPULoadMeter
import SwiftUI
import Testing

@MainActor
struct HeaderViewTests {

	private func load(user: UInt32, system: UInt32, idle: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: user, system: system, idle: idle, nice: 0)))
	}

	@Test func theUsageLineUsesTopsWordingAndOrder() async throws {
		#expect(HeaderView.usageLine(load: load(user: 2, system: 1, idle: 22), isLastSampleFailed: false) == "CPU usage: 8% user, 4% system, 88% idle")
	}

	@Test func theUsageLineIsADashBeforeTheFirstLoad() async throws {
		#expect(HeaderView.usageLine(load: nil, isLastSampleFailed: false) == "CPU usage: —")
	}

	@Test func theUsageLineSaysSoWhileSamplesFail() async throws {
		#expect(HeaderView.usageLine(load: load(user: 1, system: 1, idle: 2), isLastSampleFailed: true) == "CPU usage unavailable")
		#expect(HeaderView.usageLine(load: nil, isLastSampleFailed: true) == "CPU usage unavailable")
	}

	//	Two digits in each figure is the most a sum of 100 allows, so this is the widest the line gets.
	@Test func theWidestUsageLineHasTwoDigitsInEveryFigure() async throws {
		#expect(HeaderView.widestUsageLine == "CPU usage: 33% user, 33% system, 34% idle")
	}

	///	The header's size when it is offered `width`, or its ideal size when offered none: what `ImageRenderer` draws it
	///	at, at one pixel to the point.
	private func size(of header: HeaderHost, atWidth width: CGFloat?) throws -> CGSize {
		let renderer = ImageRenderer(content: header)
		renderer.proposedSize = ProposedViewSize(width: width, height: nil)
		renderer.scale = 1
		let image = try #require(renderer.cgImage)
		return CGSize(width: image.width, height: image.height)
	}

	//	Offered its ideal width or more, the header is its two lines; offered a point less, it is the column, which is
	//	taller and can be much narrower; and it is never narrower than the column, whatever it is offered.
	@Test func theHeaderIsTwoLinesWhereTheyFitAndAColumnWhereTheyDoNot() async throws {
		let header = HeaderHost(machineLoad: nil, isLastSampleFailed: false)
		let wide = try size(of: header, atWidth: nil)
		let column = try size(of: header, atWidth: 0)

		#expect(column.width < wide.width)
		#expect(column.height > wide.height)
		#expect(try size(of: header, atWidth: wide.width) == wide)
		#expect(try size(of: header, atWidth: wide.width + 200) == CGSize(width: wide.width + 200, height: wide.height))
		#expect(try size(of: header, atWidth: wide.width - 1) == CGSize(width: wide.width - 1, height: column.height))
		#expect(try size(of: header, atWidth: column.width) == column)
	}

	//	The usage line reserves the width of the widest it can be, so neither layout's width moves as the figures do: no
	//	load yet, a failed sample, five digits, and six all measure the same.
	@Test func neitherLayoutsWidthMovesWithTheUsageFigures() async throws {
		let reference = HeaderHost(machineLoad: nil, isLastSampleFailed: false)
		let wide = try size(of: reference, atWidth: nil)
		let column = try size(of: reference, atWidth: 0)
		let headers = [
			HeaderHost(machineLoad: nil, isLastSampleFailed: true),
			HeaderHost(machineLoad: load(user: 100, system: 0, idle: 0), isLastSampleFailed: false),
			HeaderHost(machineLoad: load(user: 33, system: 33, idle: 34), isLastSampleFailed: false),
			HeaderHost(machineLoad: load(user: 1, system: 1, idle: 98), isLastSampleFailed: false),
		]

		for header in headers {
			#expect(try size(of: header, atWidth: nil) == wide)
			#expect(try size(of: header, atWidth: 0) == column)
		}
	}

}

///	A header with the focus states it needs, which only a view can own.
private struct HeaderHost: View {

	let machineLoad: CPULoad?

	let isLastSampleFailed: Bool

	@FocusState private var isEditingPeriod: Bool

	@FocusState private var isEditingHistory: Bool

	var body: some View {
		HeaderView(processorName: "Test CPU", cpuCount: 8, machineLoad: machineLoad, isLastSampleFailed: isLastSampleFailed, period: .constant(.default), history: .constant(.default), isEditingPeriod: $isEditingPeriod, isEditingHistory: $isEditingHistory)
	}

}
