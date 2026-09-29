@testable import CPULoadMeter
import Testing

struct HistoryLengthTests {

	//	A history length is a count of samples, and the sample count is the setting itself: no period divides it, so no
	//	period can change how finely a graph is drawn.
	@Test func theSampleCountIsTheSettingItself() async throws {
		let ninety = try #require(MenuBarHistoryLength(value: 90))
		let hour = try #require(WindowHistoryLength(value: 3_600))

		#expect(ninety.sampleCount == 90)
		#expect(hour.sampleCount == 3_600)
		#expect(MenuBarHistoryLength.default.sampleCount == 60)
		#expect(WindowHistoryLength.default.sampleCount == 300)
		#expect(MenuBarHistoryLength.presets.map(\.sampleCount) == [30, 60, 90, 120])
	}

}
