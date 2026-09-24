import Foundation
import Observation

///	The sampler: one task that sleeps until a deadline, samples, and advances the deadline. It owns the period, the
///	current state, and the last error, and it persists nothing. There are two: the window's, which samples while the
///	window is shown, and the menu bar's, which samples for the life of the process. Design.md, sections 4.2, 5.8, and
///	5.12.
///
///	Its two collaborators are passed in, so that what it does with a failed read, a changed CPU count, and a new period
///	can be exercised with scripted ticks and a scripted sleep, deterministically and without a real clock. Both are
///	called on the main actor, which their types say; the defaults are the real reader and the continuous clock.
@Observable @MainActor final class LoadMonitor {

	///	Reads every CPU's ticks, or throws.
	typealias TickReader = @MainActor () throws(MachError) -> [CPUTicks]

	///	Sleeps until an instant on the continuous clock, or throws once the sleeping task is cancelled.
	typealias Sleep = @MainActor (ContinuousClock.Instant) async throws -> Void

	///	What this monitor samples for, in the diagnostics: "window" or "menu bar".
	let name: String

	///	The sampling period. Setting it while sampling restarts the loop: the next sample is one new period away.
	var period: SamplingPeriod {
		didSet {
			if isSampling {
				restart()
			}
		}
	}

	///	Whether the loop is running. The view that shows the graph resumes the monitor when it appears and suspends it
	///	when it disappears, and a suspended monitor holds no history.
	private(set) var isSampling = false

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

	///	Makes a monitor that is not yet sampling: no history, no baseline, no loop until `resume()`.
	init(name: String, period: SamplingPeriod, stepCount: Int, readTicks: @escaping TickReader = readProcessorTicks, sleep: @escaping Sleep = { try await Task.sleep(until: $0, clock: .continuous) }) {
		self.name = name
		self.period = period
		self.readTicks = readTicks
		self.sleep = sleep
		state = MonitorState(stepCount: stepCount)
	}

	///	Starts sampling as the app starts: the history zeroed at the current step count, a baseline sample taken at
	///	once, synchronously, and the loop started so that the first load is one period away. Resuming while sampling
	///	starts over the same way.
	func resume() {
		state = MonitorState(stepCount: state.stepCount)
		lastError = nil
		sample()
		isSampling = true
		restart()
		Diagnostics.logSampling(monitor: name, isStarting: true, cpuCount: state.histories.count, stepCount: state.stepCount)
	}

	///	Stops sampling and drops the history: with no window to show it there is nothing to keep, and the next
	///	`resume()` starts fresh. The step count is kept, since it is the window's width. Suspending while suspended does
	///	nothing.
	func suspend() {
		if isSampling {
			loop?.cancel()
			loop = nil
			isSampling = false
			state = MonitorState(stepCount: state.stepCount)
			lastError = nil
			Diagnostics.logSampling(monitor: name, isStarting: false, cpuCount: 0, stepCount: state.stepCount)
		}
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
			Diagnostics.logStepCount(monitor: name, stepCount)
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
				//	A cancellation can land after the sleep has ended and before this iteration runs, since both queue
				//	on the main actor; without this check a suspended monitor would take one more sample.
				guard let self, !Task.isCancelled else {
					break
				}
				let woke = ContinuousClock.now
				let duration = ContinuousClock().measure {
					self.sample()
				}
				self.sampleIndex += 1
				Diagnostics.logSample(monitor: self.name, index: self.sampleIndex, lateness: woke - deadline, duration: duration, cpuCount: self.state.histories.count, delta: self.state.machineDelta)
				deadline = nextDeadline(after: deadline, period: period, now: ContinuousClock.now)
			}
		}
	}

}
