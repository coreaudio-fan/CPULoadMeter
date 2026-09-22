import Foundation

///	Reads the processor's name, which is what System Information and `sysctl` report for it.
///
///	The read is `machdep.cpu.brand_string`, in two calls: one for the length, one for the bytes. It returns `nil` if
///	either fails, which no supported Mac is known to do; the option is there so that the header can still be drawn
///	without a name. Design.md, section 5.6.
nonisolated func readProcessorName() -> String? {
	let key = "machdep.cpu.brand_string"
	var length = 0
	guard sysctlbyname(key, nil, &length, nil, 0) == 0, length > 0 else {
		return nil
	}
	var bytes = [UInt8](repeating: 0, count: length)
	let status = sysctlbyname(key, &bytes, &length, nil, 0)
	return status == 0 ? String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self) : nil
}
