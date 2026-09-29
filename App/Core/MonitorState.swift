///	Everything the monitor knows: the previous sample, one load history per CPU, and the latest machine-wide load.
///
///	`advanced(with:)` is the entire per-sample logic as one pure function. A sample whose CPU count differs from the
///	previous one's is a baseline only: it resets the ticks, replaces the histories with zeros at the current sample
///	count, and clears the machine-wide load. The first sample is that same rule, going from no CPUs to N. Any other
///	sample yields one load per CPU, appended to its history, and the machine-wide load from the deltas summed and
///	divided once. Design.md, sections 2.9, 2.10, 4.1, and 5.7.
struct MonitorState: Sendable, Equatable {

	///	The ticks of the last sample, one per CPU in CPU ID order; empty before the first.
	let previousTicks: [CPUTicks]

	///	One history per CPU, in CPU ID order, each at `sampleCount` samples.
	let histories: [LoadHistory]

	///	The ticks that elapsed machine-wide over the last interval, summed across the CPUs, or `nil` until two samples
	///	with the same CPU count have been taken.
	let machineDelta: TickDelta?

	///	The machine-wide load over the last interval, or `nil` until two samples with the same CPU count have been
	///	taken.
	var machineLoad: CPULoad? {
		machineDelta.map(CPULoad.init)
	}

	///	How many loads every history holds.
	let sampleCount: Int

	///	The state before any sample, with histories to be created at `sampleCount` samples.
	init(sampleCount: Int) {
		self.init(previousTicks: [], histories: [], machineDelta: nil, sampleCount: max(0, sampleCount))
	}

	///	The members, unchecked: the two operations below make every state.
	private init(previousTicks: [CPUTicks], histories: [LoadHistory], machineDelta: TickDelta?, sampleCount: Int) {
		self.previousTicks = previousTicks
		self.histories = histories
		self.machineDelta = machineDelta
		self.sampleCount = sampleCount
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
				machineDelta: deltas.reduce(.zero, +),
				sampleCount: sampleCount)
		} else {
			result = MonitorState(
				previousTicks: ticks,
				histories: Array(repeating: LoadHistory(sampleCount: sampleCount), count: ticks.count),
				machineDelta: nil,
				sampleCount: sampleCount)
		}
		return result
	}

	///	This state with every history at another sample count.
	func resized(toSampleCount sampleCount: Int) -> MonitorState {
		let newCount = max(0, sampleCount)
		return MonitorState(
			previousTicks: previousTicks,
			histories: histories.map { $0.resized(toSampleCount: newCount) },
			machineDelta: machineDelta,
			sampleCount: newCount)
	}

}
