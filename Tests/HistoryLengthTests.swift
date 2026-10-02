@testable import CPULoadMeter
import Testing

struct HistoryLengthTests {

	//	The window's history length is a count of samples, and the sample count is the setting itself: no period divides
	//	it, so no period can change how finely a graph is drawn.
	@Test func theWindowsSampleCountIsTheSettingItself() async throws {
		let tenMinutes = try #require(WindowHistoryLength(value: 600))

		#expect(tenMinutes.sampleCount == 600)
		#expect(WindowHistoryLength.default.sampleCount == 300)
		#expect(WindowHistoryLength.presets.map(\.sampleCount) == [15, 30, 45, 60, 90, 120, 150, 180, 300, 600])
	}

	//	The menu bar graph has no history setting: it holds one sample for every point of its width.
	@Test func theMenuBarGraphHoldsOneSampleForEveryPointOfItsWidth() async throws {
		let wide = try #require(GraphWidth(value: 45))

		#expect(wide.sampleCount == 45)
		#expect(GraphWidth.default.sampleCount == 15)
		#expect(GraphWidth.presets.map(\.sampleCount) == [15, 20, 25, 30, 45, 60])
	}

}
