@testable import CPULoadMeter
import Foundation
import Testing

@MainActor
struct LoadMonitorTests {

	private func ticks(user: UInt32, idle: UInt32) -> CPUTicks {
		CPUTicks(user: user, system: 0, idle: idle, nice: 0)
	}

	///	A load of `numerator` sixteenths user, the rest idle.
	private func load(_ numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: ticks(user: 0, idle: 0), to: ticks(user: numerator, idle: 16 - numerator)))
	}

	@Test(.timeLimit(.minutes(1))) func theBaselineIsTakenAtOnceAndTheFirstSleepIsOnePeriodAway() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)])])
		let before = ContinuousClock.now
		let monitor = LoadMonitor(period: .default, stepCount: 3, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()

		#expect(reader.readCount == 1)
		#expect(monitor.state.previousTicks.count == 2)
		#expect(monitor.state.histories == [LoadHistory(stepCount: 3), LoadHistory(stepCount: 3)])
		#expect(monitor.state.machineLoad == nil)
		#expect(monitor.lastError == nil)
		await sleeper.awaitDeadlines(1)
		#expect((sleeper.deadlines[0] - before) >= .seconds(1))
		#expect((sleeper.deadlines[0] - before) < .seconds(2))
	}

	//	The baseline, then 4 of 16 user ticks; then a failed read, which changes nothing; then a read whose delta is
	//	taken against the last good sample: 12 user and 4 idle since it.
	@Test(.timeLimit(.minutes(1))) func aFailedReadKeepsTheLastGoodSampleAsTheBaseline() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([
			.success([ticks(user: 0, idle: 0)]),
			.success([ticks(user: 4, idle: 12)]),
			.failure(MachError(.failure)),
			.success([ticks(user: 16, idle: 16)]),
		])
		let monitor = LoadMonitor(period: .default, stepCount: 2, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		await sleeper.awaitDeadlines(1)
		sleeper.release()
		await sleeper.awaitDeadlines(2)
		let afterTheSecondSample = monitor.state

		#expect(afterTheSecondSample.histories.map(\.loads) == [[.zero, load(4)]])
		#expect(monitor.lastError == nil)

		sleeper.release()
		await sleeper.awaitDeadlines(3)

		#expect(monitor.lastError == MachError(.failure))
		#expect(monitor.state == afterTheSecondSample)

		sleeper.release()
		await sleeper.awaitDeadlines(4)

		#expect(monitor.lastError == nil)
		#expect(monitor.state.histories.map(\.loads) == [[load(4), load(12)]])
		#expect(reader.readCount == 4)
	}

	@Test(.timeLimit(.minutes(1))) func aChangedCPUCountResetsTheBaselineAndTheHistories() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([
			.success([ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)]),
			.success([ticks(user: 8, idle: 8), ticks(user: 8, idle: 8)]),
			.success([ticks(user: 0, idle: 0), ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)]),
			.success([ticks(user: 4, idle: 12), ticks(user: 4, idle: 12), ticks(user: 4, idle: 12)]),
		])
		let monitor = LoadMonitor(period: .default, stepCount: 2, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		await sleeper.awaitDeadlines(1)
		sleeper.release()
		await sleeper.awaitDeadlines(2)

		#expect(monitor.state.machineLoad == load(8))

		sleeper.release()
		await sleeper.awaitDeadlines(3)

		#expect(monitor.state.histories == [LoadHistory(stepCount: 2), LoadHistory(stepCount: 2), LoadHistory(stepCount: 2)])
		#expect(monitor.state.machineLoad == nil)

		sleeper.release()
		await sleeper.awaitDeadlines(4)

		#expect(monitor.state.histories.map(\.loads) == [[.zero, load(4)], [.zero, load(4)], [.zero, load(4)]])
		#expect(monitor.state.machineLoad == load(4))
	}

	@Test(.timeLimit(.minutes(1))) func aNewPeriodRestartsTheLoopOneNewPeriodAway() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0)])])
		let monitor = LoadMonitor(period: .default, stepCount: 1, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		await sleeper.awaitDeadlines(1)
		let changed = ContinuousClock.now
		monitor.period = try #require(SamplingPeriod(seconds: 5))
		await sleeper.awaitDeadlines(2)

		#expect(monitor.period.seconds == 5)
		#expect((sleeper.deadlines[1] - changed) >= .seconds(5))
		#expect((sleeper.deadlines[1] - changed) < .seconds(6))
		#expect(reader.readCount == 1)
	}

	@Test func aMonitorDoesNotSampleUntilResumed() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0)])])
		let monitor = LoadMonitor(period: .default, stepCount: 3, readTicks: reader.read, sleep: sleeper.sleep)
		await Task.yield()

		#expect(!(monitor.isSampling))
		#expect(reader.readCount == 0)
		#expect(monitor.state.histories.isEmpty)
		#expect(sleeper.deadlines.isEmpty)
	}

	@Test(.timeLimit(.minutes(1))) func suspendingStopsTheLoopAndDropsTheHistory() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0)]), .success([ticks(user: 4, idle: 12)])])
		let monitor = LoadMonitor(period: .default, stepCount: 2, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		await sleeper.awaitDeadlines(1)
		sleeper.release()
		await sleeper.awaitDeadlines(2)
		let readsBefore = reader.readCount
		monitor.suspend()
		sleeper.release()
		await Task.yield()
		await Task.yield()

		#expect(!(monitor.isSampling))
		#expect(monitor.state.histories.isEmpty)
		#expect(monitor.state.machineLoad == nil)
		#expect(monitor.state.stepCount == 2)
		#expect(reader.readCount == readsBefore)
		#expect(sleeper.deadlines.count == 2)
	}

	@Test(.timeLimit(.minutes(1))) func resumingStartsOverFromAFreshBaseline() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0)]), .success([ticks(user: 4, idle: 12)]), .success([ticks(user: 100, idle: 100)])])
		let monitor = LoadMonitor(period: .default, stepCount: 2, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		await sleeper.awaitDeadlines(1)
		sleeper.release()
		await sleeper.awaitDeadlines(2)
		monitor.suspend()
		monitor.resume()
		await sleeper.awaitDeadlines(3)

		#expect(monitor.isSampling)
		#expect(reader.readCount == 3)
		#expect(monitor.state.histories == [LoadHistory(stepCount: 2)])
		#expect(monitor.state.machineLoad == nil)
	}

	@Test func aNewPeriodWhileSuspendedDoesNotStartTheLoop() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0)])])
		let monitor = LoadMonitor(period: .default, stepCount: 1, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.period = try #require(SamplingPeriod(seconds: 5))
		await Task.yield()
		await Task.yield()

		#expect(!(monitor.isSampling))
		#expect(sleeper.deadlines.isEmpty)
		#expect(monitor.period.seconds == 5)
	}

	@Test func settingTheStepCountResizesEveryHistoryAndIgnoresTheSameCount() async throws {
		let sleeper = ScriptedSleep()
		let reader = ScriptedTicks([.success([ticks(user: 0, idle: 0), ticks(user: 0, idle: 0)])])
		let monitor = LoadMonitor(period: .default, stepCount: 2, readTicks: reader.read, sleep: sleeper.sleep)
		monitor.resume()
		monitor.setStepCount(4)
		let resized = monitor.state
		monitor.setStepCount(4)

		#expect(resized.stepCount == 4)
		#expect(resized.histories == [LoadHistory(stepCount: 4), LoadHistory(stepCount: 4)])
		#expect(monitor.state == resized)
	}

}
