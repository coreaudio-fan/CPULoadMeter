@testable import CPULoadMeter
import Testing

struct MonitorStateTests {

	private func ticks(user: UInt32, idle: UInt32) -> CPUTicks {
		CPUTicks(user: user, system: 0, idle: idle, nice: 0)
	}

	///	A load of `numerator` sixteenths user, the rest idle.
	private func load(_ numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: ticks(user: 0, idle: 0), to: ticks(user: numerator, idle: 16 - numerator)))
	}

	@Test func theInitialStateHasNoCPUs() async throws {
		let state = MonitorState(stepCount: 4)

		#expect(state.previousTicks.isEmpty)
		#expect(state.histories.isEmpty)
		#expect(state.machineLoad == nil)
		#expect(state.stepCount == 4)
	}

	@Test func theFirstSampleIsABaselineOnly() async throws {
		let state = MonitorState(stepCount: 3).advanced(with: [ticks(user: 100, idle: 900), ticks(user: 200, idle: 800)])

		#expect(state.previousTicks == [ticks(user: 100, idle: 900), ticks(user: 200, idle: 800)])
		#expect(state.histories == [LoadHistory(stepCount: 3), LoadHistory(stepCount: 3)])
		#expect(state.machineLoad == nil)
	}

	//	CPU 0 accrues 4 user of 16 ticks, CPU 1 accrues 12 of 16: loads of 0.25 and 0.75, and 16 busy of 32
	//	machine-wide.
	@Test func aSteadyStateSampleAppendsOneLoadPerCPUAndSumsTheDeltas() async throws {
		let baseline = MonitorState(stepCount: 2).advanced(with: [ticks(user: 100, idle: 900), ticks(user: 200, idle: 800)])
		let state = baseline.advanced(with: [ticks(user: 104, idle: 912), ticks(user: 212, idle: 804)])

		#expect(state.histories.map(\.loads) == [[.zero, load(4)], [.zero, load(12)]])
		#expect(state.machineLoad == load(8))
		#expect(state.previousTicks == [ticks(user: 104, idle: 912), ticks(user: 212, idle: 804)])
		#expect(state.stepCount == 2)
	}

	//	Unequal totals: CPU 0 accrues 2 ticks at 50% busy, CPU 1 accrues 6 at 100%. Summed, 7 busy of 8 is 0.875; the
	//	mean of the two percentages would be 0.75.
	@Test func theMachineWideLoadIsNotTheMeanOfThePerCPULoads() async throws {
		let baseline = MonitorState(stepCount: 1).advanced(with: [ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)])
		let state = baseline.advanced(with: [ticks(user: 1, idle: 1), ticks(user: 6, idle: 0)])

		#expect(state.machineLoad?.user == 0.875)
		#expect(state.histories.map(\.loads) == [[load(8)], [load(16)]])
	}

	@Test func aChangedCPUCountResetsTheBaselineAndTheHistories() async throws {
		let running = MonitorState(stepCount: 2)
			.advanced(with: [ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)])
			.advanced(with: [ticks(user: 8, idle: 8), ticks(user: 8, idle: 8)])
		let state = running.advanced(with: [ticks(user: 50, idle: 50), ticks(user: 50, idle: 50), ticks(user: 50, idle: 50)])

		#expect(running.machineLoad == load(8))
		#expect(state.previousTicks.count == 3)
		#expect(state.histories == [LoadHistory(stepCount: 2), LoadHistory(stepCount: 2), LoadHistory(stepCount: 2)])
		#expect(state.machineLoad == nil)
	}

	@Test func resizingResizesEveryHistoryAndKeepsTheRest() async throws {
		let state = MonitorState(stepCount: 2)
			.advanced(with: [ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)])
			.advanced(with: [ticks(user: 4, idle: 12), ticks(user: 12, idle: 4)])
		let wider = state.resized(toStepCount: 3)
		let narrower = state.resized(toStepCount: 1)

		#expect(wider.stepCount == 3)
		#expect(wider.histories.map(\.loads) == [[.zero, .zero, load(4)], [.zero, .zero, load(12)]])
		#expect(narrower.histories.map(\.loads) == [[load(4)], [load(12)]])
		#expect(wider.previousTicks == state.previousTicks)
		#expect(wider.machineLoad == state.machineLoad)
	}

	@Test func aNewStepCountAppliesToHistoriesCreatedLater() async throws {
		let state = MonitorState(stepCount: 1).resized(toStepCount: 3).advanced(with: [ticks(user: 0, idle: 0)])

		#expect(state.histories == [LoadHistory(stepCount: 3)])
	}

}
