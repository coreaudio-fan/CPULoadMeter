///	One CPU's four cumulative tick counters, as the kernel reports them.
///
///	Each is the CPU's time in that state, in ticks of 10 ms, truncated to 32 bits: the counters wrap, so
///	they are only ever compared by subtracting in 32 bits with wrapping arithmetic. `nice` is always zero
///	on this kernel and is folded into `user` wherever a load is formed. Design.md, sections 2.2 and 4.1.
nonisolated struct CPUTicks: Sendable, Equatable {

	///	Ticks spent running user code at normal priority.
	let user: UInt32

	///	Ticks spent in the kernel.
	let system: UInt32

	///	Ticks spent idle.
	let idle: UInt32

	///	Ticks spent running user code at reduced priority. Always zero on this kernel.
	let nice: UInt32

}
