@testable import CPULoadMeter
import Testing

struct CPULoadTests {

	private func delta(user: UInt32, system: UInt32, idle: UInt32) -> TickDelta {
		TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: user, system: system, idle: idle, nice: 0))
	}

	//	1 + 1 busy of 4 elapsed: exact binary fractions, so the comparisons are exact.
	@Test func fractionsAreTheShareOfElapsedTicks() async throws {
		let load = CPULoad(delta(user: 1, system: 1, idle: 2))

		#expect(load.user == 0.25)
		#expect(load.system == 0.25)
		#expect(load.total == 0.5)
	}

	@Test func zeroElapsedTicksGiveZeroLoad() async throws {
		#expect(CPULoad(delta(user: 0, system: 0, idle: 0)) == .zero)
		#expect(CPULoad.zero.total == 0)
	}

	@Test func aFullyBusyIntervalIsOne() async throws {
		let load = CPULoad(delta(user: 3, system: 1, idle: 0))

		#expect(load.user == 0.75)
		#expect(load.system == 0.25)
		#expect(load.total == 1)
	}

	@Test func anIdleIntervalIsZeroButNotZeroTicks() async throws {
		let load = CPULoad(delta(user: 0, system: 0, idle: 100))

		#expect(load == .zero)
	}

	//	The machine-wide figure is the deltas summed and divided once. Two CPUs with unequal totals: one 50% busy over 2
	//	ticks, one 100% busy over 6. Summed, 7 busy of 8 is 0.875; the mean of the percentages would be 0.75.
	@Test func summedDeltasAreNotTheMeanOfPercentages() async throws {
		let lightlyUsed = delta(user: 1, system: 0, idle: 1)
		let saturated = delta(user: 6, system: 0, idle: 0)
		let machine = CPULoad(lightlyUsed + saturated)

		#expect(machine.user == 0.875)
		#expect(((CPULoad(lightlyUsed).user + CPULoad(saturated).user) / 2) == 0.75)
	}

}
