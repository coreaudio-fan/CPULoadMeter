///	Everything the monitor knows: the previous sample, one load history per CPU, and the latest machine-wide load.
///
///	`advanced(with:)` is the entire per-sample logic as one pure function. A sample whose CPU count differs from the
///	previous one's is a baseline only: it resets the ticks, replaces the histories with zeros at the current step count,
///	and clears the machine-wide load. The first sample is that same rule, going from no CPUs to N. Any other sample
///	yields one load per CPU, appended to its history, and the machine-wide load from the deltas summed and divided once.
///	Design.md, sections 2.9, 2.10, 4.1, and 5.7.
nonisolated struct MonitorState: Sendable, Equatable {

	///	The ticks of the last sample, one per CPU in CPU ID order; empty before the first.
	let previousTicks: [CPUTicks]

	///	One history per CPU, in CPU ID order, each at `stepCount` steps.
	let histories: [LoadHistory]

	///	The machine-wide load over the last interval, or `nil` until two samples with the same CPU count have been
	///	taken.
	let machineLoad: CPULoad?

	///	How many loads every history holds.
	let stepCount: Int

	///	The state before any sample, with histories to be created at `stepCount` steps.
	init(stepCount: Int) {
		self.init(previousTicks: [], histories: [], machineLoad: nil, stepCount: max(0, stepCount))
	}

	///	The members, unchecked: the two operations below make every state.
	private init(previousTicks: [CPUTicks], histories: [LoadHistory], machineLoad: CPULoad?, stepCount: Int) {
		self.previousTicks = previousTicks
		self.histories = histories
		self.machineLoad = machineLoad
		self.stepCount = stepCount
	}

	///	This state one sample later.
	func advanced(with ticks: [CPUTicks]) -> MonitorState {
		let result: MonitorState
		if ticks.count == previousTicks.count {
			let deltas = zip(previousTicks, ticks).map { TickDelta(from: $0, to: $1) }
			let loads = deltas.map(CPULoad.init)
			result = MonitorState(
				previousTicks: ticks,
				histories: zip(histories, loads).map { $0.appending($1) },
				machineLoad: CPULoad(deltas.reduce(.zero, +)),
				stepCount: stepCount)
		} else {
			result = MonitorState(
				previousTicks: ticks,
				histories: Array(repeating: LoadHistory(stepCount: stepCount), count: ticks.count),
				machineLoad: nil,
				stepCount: stepCount)
		}
		return result
	}

	///	This state with every history at another step count.
	func resized(toStepCount stepCount: Int) -> MonitorState {
		let newCount = max(0, stepCount)
		return MonitorState(
			previousTicks: previousTicks,
			histories: histories.map { $0.resized(toStepCount: newCount) },
			machineLoad: machineLoad,
			stepCount: newCount)
	}

}
