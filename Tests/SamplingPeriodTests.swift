@testable import CPULoadMeter
import Testing

struct SamplingPeriodTests {

	@Test func theBoundsAreOneAndSixtyInclusive() async throws {
		#expect(SamplingPeriod(seconds: 0) == nil)
		#expect(SamplingPeriod(seconds: 1)?.seconds == 1)
		#expect(SamplingPeriod(seconds: 60)?.seconds == 60)
		#expect(SamplingPeriod(seconds: 61) == nil)
		#expect(SamplingPeriod(seconds: -5) == nil)
	}

	@Test func textParsesAsAWholeNumberInRange() async throws {
		#expect(SamplingPeriod(text: "5")?.seconds == 5)
		#expect(SamplingPeriod(text: " 30 ")?.seconds == 30)
		#expect(SamplingPeriod(text: "0") == nil)
		#expect(SamplingPeriod(text: "61") == nil)
	}

	@Test func textThatIsNotAWholeNumberIsRejected() async throws {
		for text in ["abc", "2.5", "", " ", "5s", "1e1", "0x10"] {
			#expect(SamplingPeriod(text: text) == nil, "\(text)")
		}
	}

	@Test func thePresetsAndTheDefaultAreAsSpecified() async throws {
		#expect(SamplingPeriod.presets.map(\.seconds) == [1, 2, 5, 10, 30])
		#expect(SamplingPeriod.default.seconds == 1)
		#expect(SamplingPeriod.default == SamplingPeriod.presets[0])
	}

}
