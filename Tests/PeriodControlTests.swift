@testable import CPULoadMeter
import Testing

@MainActor
struct PeriodControlTests {

	@Test func aWholeNumberInRangeBecomesThePeriod() async throws {
		let committed = PeriodControl.committedPeriod(from: "30", current: .default)

		#expect(committed.seconds == 30)
	}

	@Test func anythingElseIsRejectedAndThePeriodStands() async throws {
		let current = try #require(SamplingPeriod(seconds: 5))

		for draft in ["0", "61", "abc", "2.5", ""] {
			#expect(PeriodControl.committedPeriod(from: draft, current: current) == current, "\(draft)")
		}
	}

}
