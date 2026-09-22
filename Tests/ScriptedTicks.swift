@testable import CPULoadMeter
import Foundation

///	A reader the test scripts: each call returns the next result, and once the script is used up, the last result again,
///	so that a loop still running at the end of a test reads a sample of zero elapsed ticks rather than trapping.
@MainActor final class ScriptedTicks {

	///	The results still to be returned; the last one repeats.
	private var results: [Result<[CPUTicks], MachError>]

	///	How many times the monitor has read.
	private(set) var readCount = 0

	///	A reader that returns `results` in order.
	init(_ results: [Result<[CPUTicks], MachError>]) {
		self.results = results
	}

	///	The monitor's reader.
	func read() throws(MachError) -> [CPUTicks] {
		readCount += 1
		let result = results.count > 1 ? results.removeFirst() : results[0]
		return try result.get()
	}

}
