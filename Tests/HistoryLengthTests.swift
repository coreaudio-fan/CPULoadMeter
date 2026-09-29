@testable import CPULoadMeter
import Testing

struct HistoryLengthTests {

	//	The sample count is the whole periods the length holds: a partial period is dropped, and a length shorter than
	//	the period still gives one sample.
	@Test func theSampleCountIsTheWholePeriodsTheLengthHolds() async throws {
		let sixty = try #require(MenuBarHistoryLength(seconds: 60))
		let thirty = try #require(MenuBarHistoryLength(seconds: 30))
		let seven = try #require(SamplingPeriod(seconds: 7))
		let minute = try #require(SamplingPeriod(seconds: 60))

		#expect(sixty.sampleCount(at: .default) == 60)
		#expect(sixty.sampleCount(at: seven) == 8)
		#expect(thirty.sampleCount(at: minute) == 1)
		#expect(MenuBarHistoryLength.presets.last?.sampleCount(at: .default) == 120)
	}

	@Test func theWindowsHistoryCountsTheSameWayOverItsWiderRange() async throws {
		let hour = try #require(WindowHistoryLength(seconds: 3_600))
		let seven = try #require(SamplingPeriod(seconds: 7))

		#expect(WindowHistoryLength.default.sampleCount(at: .default) == 300)
		#expect(hour.sampleCount(at: .default) == 3_600)
		#expect(hour.sampleCount(at: seven) == 514)
	}

}
