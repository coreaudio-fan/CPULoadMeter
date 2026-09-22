///	One CPU's retained loads, oldest first: exactly as many as its view has steps, always.
///
///	There is no partially full state. A new history is all zeros; appending drops the oldest load and adds the newest,
///	so the length cannot change; resizing prepends zeros to grow, so that the added steps are the oldest, and keeps the
///	newest loads to shrink. Every operation returns a new value. Design.md, sections 2.10 and 4.1.
struct LoadHistory: Sendable, Equatable {

	///	The loads, oldest first. The last is the newest, which the view draws at its right edge.
	let loads: [CPULoad]

	///	How many loads there are, which is how many steps the view has.
	var stepCount: Int {
		loads.count
	}

	///	A history of zeros, one per step. A negative count is treated as zero.
	init(stepCount: Int) {
		self.init(loads: Array(repeating: .zero, count: max(0, stepCount)))
	}

	///	The loads, unchecked: the three operations above and below make every history.
	private init(loads: [CPULoad]) {
		self.loads = loads
	}

	///	This history one sample later: the oldest load gone, the new one newest. A history of zero steps stays empty.
	func appending(_ load: CPULoad) -> LoadHistory {
		LoadHistory(loads: Array((loads + [load]).suffix(stepCount)))
	}

	///	This history at another step count: zeros added at the oldest end to grow, the oldest loads dropped to shrink,
	///	and the same history at the same count.
	func resized(toStepCount stepCount: Int) -> LoadHistory {
		let newCount = max(0, stepCount)
		let padding = repeatElement(CPULoad.zero, count: max(0, newCount - loads.count))
		return LoadHistory(loads: Array((padding + loads).suffix(newCount)))
	}

}
