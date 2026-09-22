///	One CPU's load over an interval, or the machine's: the fractions of the elapsed ticks spent in user code and in the
///	kernel. This is what `top` reports as CPU usage.
///
///	Each fraction is in 0…1 and their sum is at most 1, by construction: apart from `zero`, the only way to make one is
///	from a `TickDelta`, whose busy ticks never exceed its total. Design.md, sections 2.9, 4.1, and 5.7.
nonisolated struct CPULoad: Sendable, Equatable {

	///	No load: the history's initial value, and the load over an interval in which no ticks elapsed.
	static let zero = CPULoad(user: 0, system: 0)

	///	The fraction of the interval spent running user code.
	let user: Double

	///	The fraction of the interval spent in the kernel.
	let system: Double

	///	The fraction of the interval spent busy: user and system.
	var total: Double {
		user + system
	}

	///	The load over the interval a delta covers. Zero elapsed ticks yield `zero`.
	init(_ delta: TickDelta) {
		if delta.total == 0 {
			self = .zero
		} else {
			self.init(user: Double(delta.user) / Double(delta.total), system: Double(delta.system) / Double(delta.total))
		}
	}

	///	The members, unchecked: only `zero` and the delta initializer above make one.
	private init(user: Double, system: Double) {
		self.user = user
		self.system = system
	}

}
