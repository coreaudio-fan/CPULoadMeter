import Foundation

///	The host port, obtained once. Every `mach_host_self()` call hands back a fresh send right that the caller is
///	expected to release, so asking on every sample would leak port rights; libtop asks once, and so does this.
nonisolated private let hostPort = mach_host_self()

///	Reads every CPU's cumulative tick counters from the kernel, in CPU ID order.
///
///	The kernel allocates the reply in this task's address space on every call, and nothing frees it but the caller:
///	2,000 calls without the `vm_deallocate` were seen to cost 2,000 distinct pages. So the buffer is freed here,
///	unconditionally, before the function returns, and what it returns is a Swift array: no pointer, and no obligation,
///	escapes. The buffer cannot be allocated once and reused, because it is not the caller's to allocate. Design.md,
///	section 5.6 and B.12.
nonisolated func readProcessorTicks() throws(MachError) -> [CPUTicks] {
	var cpuCount: natural_t = 0
	var reply: processor_info_array_t? = nil
	var replyCount: mach_msg_type_number_t = 0
	let status = host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &reply, &replyCount)
	guard status == KERN_SUCCESS, let reply else {
		throw MachError(MachErrorCode(rawValue: status) ?? .failure)
	}
	defer {
		vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: reply)), vm_size_t(replyCount) * vm_size_t(MemoryLayout<integer_t>.stride))
	}
	return reply.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(cpuCount)) { loads in
		UnsafeBufferPointer(start: loads, count: Int(cpuCount)).map(CPUTicks.init)
	}
}

nonisolated private extension CPUTicks {

	///	The kernel's tuple, given names. The order is the kernel's: user, system, idle, nice.
	init(_ load: processor_cpu_load_info) {
		self.init(user: load.cpu_ticks.0, system: load.cpu_ticks.1, idle: load.cpu_ticks.2, nice: load.cpu_ticks.3)
	}

}
