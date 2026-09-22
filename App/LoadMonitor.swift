import Foundation
import Observation

///	The sampler: one task that sleeps until a deadline, samples, and advances the deadline, for the life of the process.
///	It owns the period, the current state, and the last error, and it persists nothing. Design.md, sections 4.2, 5.8,
///	and 5.12.
///
///	Its two collaborators are passed in, so that what it does with a failed read, a changed CPU count, and a new period
///	can be exercised with scripted ticks and a scripted sleep, deterministically and without a real clock. Both are
///	called on the main actor, which their types say; the defaults are the real reader and the continuous clock.
@Observable @MainActor final class LoadMonitor {

	///	Reads every CPU's ticks, or throws.
	typealias TickReader = @MainActor () throws(MachError) -> [CPUTicks]

	///	Sleeps until an instant on the continuous clock, or throws once the sleeping task is cancelled.
	typealias Sleep = @MainActor (ContinuousClock.Instant) async throws -> Void

	///	The sampling period. Setting it restarts the loop: the next sample is one new period away.
	var period: SamplingPeriod {
		didSet {
			restart()
		}
	}

	///	Everything sampled so far.
	private(set) var state: MonitorState

	///	The error from the last read, or `nil` if it succeeded. A failed read leaves `state` as it was.
	private(set) var lastError: MachError?

	///	The reader, called once per sample.
	private let readTicks: TickReader

	///	The sleep, called once per loop iteration.
	private let sleep: Sleep

	///	The loop. Replaced on a period change, and cancelled when the monitor goes away.
	private var loop: Task<Void, Never>?

	///	How many samples the loop has taken; the baseline is not counted.
	private var sampleIndex = 0

	///	Takes the baseline sample at once, synchronously, and starts the loop.
	init(period: SamplingPeriod, stepCount: Int, readTicks: @escaping TickReader = readProcessorTicks, sleep: @escaping Sleep = { try await Task.sleep(until: $0, clock: .continuous) }) {
		self.period = period
		self.readTicks = readTicks
		self.sleep = sleep
		state = MonitorState(stepCount: stepCount)
		sample()
		restart()
	}

	///	Ends the loop with the monitor. The deinit is isolated because `loop` is; the app never destroys its monitor,
	///	but the tests destroy one per test.
	isolated deinit {
		loop?.cancel()
	}

	///	Resizes every history. The step count flows up from the view (Design.md, section 4.2).
	func setStepCount(_ stepCount: Int) {
		if stepCount != state.stepCount {
			state = state.resized(toStepCount: stepCount)
			Diagnostics.logStepCount(stepCount)
		}
	}

	///	Reads once and advances the state. On failure it records the error and leaves the state as it was, so that the
	///	last good sample stays the baseline and the next success averages over the longer interval.
	private func sample() {
		do {
			state = state.advanced(with: try readTicks())
			lastError = nil
		} catch {
			lastError = error
		}
	}

	///	Cancels the loop, if any, and starts one that sleeps until a deadline, samples, and moves the deadline on by the
	///	rule in `nextDeadline`, beginning one period from now. The loop holds the monitor weakly: it ends when the
	///	monitor goes away, or when the sleep throws because its task was cancelled.
	private func restart() {
		loop?.cancel()
		let period = period.duration
		loop = Task { [weak self] in
			var deadline = ContinuousClock.now + period
			while true {
				do {
					try await self?.sleep(deadline)
				} catch {
					break
				}
				guard let self else {
					break
				}
				let woke = ContinuousClock.now
				let duration = ContinuousClock().measure {
					self.sample()
				}
				self.sampleIndex += 1
				Diagnostics.logSample(index: self.sampleIndex, lateness: woke - deadline, duration: duration, cpuCount: self.state.histories.count, delta: self.state.machineDelta)
				deadline = nextDeadline(after: deadline, period: period, now: ContinuousClock.now)
			}
		}
	}

}
