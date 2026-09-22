@testable import CPULoadMeter
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

}
