@testable import CPULoadMeter
import Testing

struct HistoryLengthTests {

	@Test func theBoundsAreThirtyAndOneHundredTwentyInclusive() async throws {
		#expect(HistoryLength(seconds: 29) == nil)
		#expect(HistoryLength(seconds: 30)?.seconds == 30)
		#expect(HistoryLength(seconds: 120)?.seconds == 120)
		#expect(HistoryLength(seconds: 121) == nil)
		#expect(HistoryLength(seconds: 0) == nil)
	}

	@Test func textParsesAsAWholeNumberInRange() async throws {
		#expect(HistoryLength(text: "45")?.seconds == 45)
		#expect(HistoryLength(text: " 120 ")?.seconds == 120)
		#expect(HistoryLength(text: "29") == nil)
		#expect(HistoryLength(text: "121") == nil)
	}

	@Test func textThatIsNotAWholeNumberIsRejected() async throws {
		for text in ["abc", "60.5", "", " ", "60s", "6e1", "0x3c"] {
			#expect(HistoryLength(text: text) == nil, "\(text)")
		}
	}

	@Test func thePresetsAndTheDefaultAreAsSpecified() async throws {
		#expect(HistoryLength.presets.map(\.seconds) == [30, 60, 90, 120])
		#expect(HistoryLength.default.seconds == 60)
		#expect(HistoryLength.default == HistoryLength.presets[1])
	}

	//	The step count is the whole periods the length holds: a partial period is dropped, and a length shorter than the
	//	period still gives one step.
	@Test func theStepCountIsTheWholePeriodsTheLengthHolds() async throws {
		let sixty = try #require(HistoryLength(seconds: 60))
		let thirty = try #require(HistoryLength(seconds: 30))
		let seven = try #require(SamplingPeriod(seconds: 7))
		let minute = try #require(SamplingPeriod(seconds: 60))

		#expect(sixty.stepCount(at: .default) == 60)
		#expect(sixty.stepCount(at: seven) == 8)
		#expect(thirty.stepCount(at: minute) == 1)
		#expect(HistoryLength.presets.last?.stepCount(at: .default) == 120)
	}

}
