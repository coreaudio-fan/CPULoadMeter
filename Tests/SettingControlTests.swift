@testable import CPULoadMeter
import Testing

@MainActor
struct SettingControlTests {

	@Test func aWholeNumberInRangeBecomesThePeriod() async throws {
		let committed = SettingControl<SamplingPeriodLimits>.committedValue(from: "30", current: .default)

		#expect(committed.seconds == 30)
	}

	@Test func anythingElseIsRejectedAndThePeriodStands() async throws {
		let current = try #require(SamplingPeriod(seconds: 5))

		for draft in ["0", "61", "abc", "2.5", ""] {
			#expect(SettingControl<SamplingPeriodLimits>.committedValue(from: draft, current: current) == current, "\(draft)")
		}
	}

	//	The same control under other limits: what the period would accept, the history length and the width reject, and
	//	the reverse.
	@Test func everySettingCommitsByItsOwnRange() async throws {
		let width = try #require(GraphWidth(value: 45))

		#expect(SettingControl<WindowHistoryLimits>.committedValue(from: "600", current: .default).sampleCount == 600)
		for draft in ["14", "601", "5", "abc", ""] {
			#expect(SettingControl<WindowHistoryLimits>.committedValue(from: draft, current: .default) == .default, "\(draft)")
		}
		#expect(SettingControl<GraphWidthLimits>.committedValue(from: "15", current: width).value == 15)
		#expect(SettingControl<GraphWidthLimits>.committedValue(from: "60", current: width).value == 60)
		for draft in ["14", "61", "abc", ""] {
			#expect(SettingControl<GraphWidthLimits>.committedValue(from: draft, current: width) == width, "\(draft)")
		}
	}

}
