///	One CPU's retained loads, oldest first: exactly as many samples as its history length says, always.
///
///	There is no partially full state. A new history is all zeros; appending drops the oldest load and adds the newest,
///	so the length cannot change; resizing prepends zeros to grow, so that the added samples are the oldest, and keeps
///	the newest loads to shrink. Every operation returns a new value. How many points wide the history is drawn is not
///	its concern: `steps(count:)` fits whatever samples there are to whatever steps the graph has. Design.md, sections
///	2.8, 2.10, and 4.1.
struct LoadHistory: Sendable, Equatable {

	///	The loads, oldest first. The last is the newest, which the view draws at its right edge.
	let loads: [CPULoad]

	///	How many samples there are.
	var sampleCount: Int {
		loads.count
	}

	///	A history of zeros, one per sample. A negative count is treated as zero.
	init(sampleCount: Int) {
		self.init(loads: Array(repeating: .zero, count: max(0, sampleCount)))
	}

	///	The loads, unchecked: the three operations above and below make every history.
	private init(loads: [CPULoad]) {
		self.loads = loads
	}

	///	This history one sample later: the oldest load gone, the new one newest. A history of no samples stays empty.
	func appending(_ load: CPULoad) -> LoadHistory {
		LoadHistory(loads: Array((loads + [load]).suffix(sampleCount)))
	}

	///	This history at another sample count: zeros added at the oldest end to grow, the oldest loads dropped to shrink,
	///	and the same history at the same count.
	func resized(toSampleCount sampleCount: Int) -> LoadHistory {
		let newCount = max(0, sampleCount)
		let padding = repeatElement(CPULoad.zero, count: max(0, newCount - loads.count))
		return LoadHistory(loads: Array((padding + loads).suffix(newCount)))
	}

	///	The history fitted to `count` steps, newest first: the load each one-point line of the graph draws.
	///
	///	Steps and samples are both counted from the newest. Every sample belongs to exactly one step, the one its center
	///	falls in, and a step draws the peak, by total load, of the samples that belong to it. A step that no sample
	///	belongs to, which happens only where steps outnumber samples, draws the sample its own center falls in. So with
	///	more steps than samples a sample is a block several points wide, its edges on whole points; with more samples
	///	than steps a point shows the highest of the loads it stands for, and no spike is lost; and with as many of one
	///	as of the other each step is its own sample. The arithmetic is in whole numbers, so that no rounding of a
	///	fraction decides where an edge falls. No steps, or no samples, give no loads.
	func steps(count: Int) -> [CPULoad] {
		guard count > 0, !(loads.isEmpty) else {
			return []
		}
		let newestFirst = Array(loads.reversed())
		return (0..<count).map { step in
			let owned = newestFirst[Self.firstSample(ofStep: step, stepCount: count, sampleCount: sampleCount)..<Self.firstSample(ofStep: step + 1, stepCount: count, sampleCount: sampleCount)]
			return owned.max { $0.total < $1.total } ?? newestFirst[Self.sample(atCenterOfStep: step, stepCount: count, sampleCount: sampleCount)]
		}
	}

	///	The first sample whose center falls in `step` or a later one. Sample n's center is at (n + ½) × steps ÷ samples,
	///	so it is the least n with (2n + 1) × steps ≥ 2 × samples × step. For the step after the last, that is the sample
	///	count.
	private static func firstSample(ofStep step: Int, stepCount: Int, sampleCount: Int) -> Int {
		((2 * sampleCount * step) + (stepCount - 1)) / (2 * stepCount)
	}

	///	The sample that the center of `step` falls in: step c's center is at (c + ½) × samples ÷ steps.
	private static func sample(atCenterOfStep step: Int, stepCount: Int, sampleCount: Int) -> Int {
		(((2 * step) + 1) * sampleCount) / (2 * stepCount)
	}

}
