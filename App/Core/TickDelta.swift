///	The ticks that elapsed between two samples: user, system, and idle. One CPU's, or the sum of several.
///
///	Constructing one from two `CPUTicks` is the wrapping subtraction the counters need, done in 32 bits and only then
///	widened, so a counter that wrapped between the samples yields a small positive delta like any other. Nice ticks are
///	folded into user. Deltas add in 64 bits, which is how the machine-wide figure is formed: the per-CPU deltas summed,
///	never a difference of sums. Design.md, sections 4.1 and 5.7.
struct TickDelta: Sendable, Equatable {

	///	No ticks at all; the identity for summing.
	static let zero = TickDelta(user: 0, system: 0, idle: 0)

	///	Ticks spent running user code, at any priority.
	let user: UInt64

	///	Ticks spent in the kernel.
	let system: UInt64

	///	Ticks spent idle.
	let idle: UInt64

	///	The busy ticks: user and system.
	var busy: UInt64 {
		user + system
	}

	///	Every tick that elapsed: busy and idle.
	var total: UInt64 {
		busy + idle
	}

	///	The difference between two samples of one CPU, `current` taken after `previous`.
	init(from previous: CPUTicks, to current: CPUTicks) {
		//	Each difference is taken in 32 bits, where a wrapped counter still yields the elapsed ticks, and widened
		//	only afterwards for the sum.
		let userDelta = current.user &- previous.user
		let niceDelta = current.nice &- previous.nice
		let systemDelta = current.system &- previous.system
		let idleDelta = current.idle &- previous.idle
		self.init(user: UInt64(userDelta) + UInt64(niceDelta), system: UInt64(systemDelta), idle: UInt64(idleDelta))
	}

	///	The members, unchecked: only `zero` and the subtraction above make one.
	private init(user: UInt64, system: UInt64, idle: UInt64) {
		self.user = user
		self.system = system
		self.idle = idle
	}

	///	The sum of two deltas, which is how several CPUs' elapsed ticks become the machine's.
	static func + (lhs: TickDelta, rhs: TickDelta) -> TickDelta {
		TickDelta(user: lhs.user + rhs.user, system: lhs.system + rhs.system, idle: lhs.idle + rhs.idle)
	}

}
