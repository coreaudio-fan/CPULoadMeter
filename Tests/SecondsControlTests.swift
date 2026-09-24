@testable import CPULoadMeter
import Testing

@MainActor
struct SecondsControlTests {

	@Test func aWholeNumberInRangeBecomesThePeriod() async throws {
		let committed = SecondsControl<SamplingPeriod>.committedValue(from: "30", current: .default)

		#expect(committed.seconds == 30)
	}

	@Test func anythingElseIsRejectedAndThePeriodStands() async throws {
		let current = try #require(SamplingPeriod(seconds: 5))

		for draft in ["0", "61", "abc", "2.5", ""] {
			#expect(SecondsControl<SamplingPeriod>.committedValue(from: draft, current: current) == current, "\(draft)")
		}
	}

	//	The same control, the history length's range: what the period would accept, the length rejects, and the reverse.
	@Test func theHistoryLengthCommitsByItsOwnRange() async throws {
		let current = try #require(HistoryLength(seconds: 90))

		#expect(SecondsControl<HistoryLength>.committedValue(from: "120", current: current).seconds == 120)
		for draft in ["29", "121", "5", "abc", ""] {
			#expect(SecondsControl<HistoryLength>.committedValue(from: draft, current: current) == current, "\(draft)")
		}
	}

}
