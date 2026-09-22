@testable import CPULoadMeter
import Testing

struct ProcessorNameReaderTests {

	//	Hosted in the sandboxed app, this re-proves on every run that the sandbox permits the read.
	@Test func readerReportsANonEmptyName() async throws {
		let name = try #require(readProcessorName())

		#expect(!(name.isEmpty))
	}

}
