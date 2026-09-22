@testable import CPULoadMeter
import Foundation
import Testing

struct ProcessorTicksReaderTests {

	///	The process's physical footprint in bytes, as `task_info` reports it, or `nil` if the call fails.
	private func physicalFootprintBytes() -> UInt64? {
		var vmInfo = task_vm_info_data_t()
		var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride)
		let status = withUnsafeMutablePointer(to: &vmInfo) { pointer in
			pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
		}
		return status == KERN_SUCCESS ? vmInfo.phys_footprint : nil
	}

	//	Hosted in the sandboxed app, this re-proves on every run that the sandbox permits the call.
	@Test func readerReportsAtLeastOneCPU() async throws {
		let ticks = try readProcessorTicks()

		#expect(!(ticks.isEmpty))
	}

	//	"Every reply buffer is freed" is not expressible in the type system, so this runtime check stands in for it. The
	//	kernel maps a fresh 16 KB page per call, so leaking would cost about 64 MB over these calls; the bound is a
	//	quarter of that, leaving room for whatever else the host process does meanwhile. Signed arithmetic, because the
	//	footprint can shrink. Design.md, section 6 and D.4.
	@Test func readerFreesEveryReplyBuffer() async throws {
		let callCount = 4_000
		let leakBoundBytes: Int64 = 16 * 1_024 * 1_024
		let before = try #require(physicalFootprintBytes())
		for _ in 0..<callCount {
			_ = try readProcessorTicks()
		}
		let after = try #require(physicalFootprintBytes())

		#expect((Int64(after) - Int64(before)) < leakBoundBytes)
	}

}
