///	The header's three whole percentages: user, system, and idle. Each is in 0…100 and the three sum to exactly 100.
///
///	The rounding is cumulative, which is what makes that hold: busy is user plus system rounded to the nearest whole
///	percent; user is user rounded; system is busy less user; idle is 100 less busy. Rounding user and system each on
///	their own could give 1 and 100 for 0.5% and 99.5%, and an idle of −1. Design.md, sections 4.1 and 5.4.
nonisolated struct UsagePercentages: Sendable, Equatable {

	///	The whole percent spent running user code.
	let user: Int

	///	The whole percent spent in the kernel.
	let system: Int

	///	The whole percent spent idle.
	let idle: Int

	///	The percentages of a load, rounded cumulatively.
	init(_ load: CPULoad) {
		let busy = Self.wholePercent(of: load.total)
		let user = Self.wholePercent(of: load.user)
		self.user = user
		self.system = busy - user
		self.idle = 100 - busy
	}

	///	A fraction as the nearest whole percent, halves rounded away from zero.
	private static func wholePercent(of fraction: Double) -> Int {
		Int((fraction * 100).rounded())
	}

}
