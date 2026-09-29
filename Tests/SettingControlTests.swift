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

	//	The same control under other limits: what the period would accept, the history length rejects, and the reverse.
	@Test func everySettingCommitsByItsOwnRange() async throws {
		let history = try #require(MenuBarHistoryLength(value: 90))
		let width = try #require(GraphWidth(value: 40))

		#expect(SettingControl<MenuBarHistoryLimits>.committedValue(from: "120", current: history).sampleCount == 120)
		for draft in ["29", "121", "5", "abc", ""] {
			#expect(SettingControl<MenuBarHistoryLimits>.committedValue(from: draft, current: history) == history, "\(draft)")
		}
		#expect(SettingControl<WindowHistoryLimits>.committedValue(from: "3600", current: .default).sampleCount == 3_600)
		#expect(SettingControl<WindowHistoryLimits>.committedValue(from: "3601", current: .default) == .default)
		#expect(SettingControl<GraphWidthLimits>.committedValue(from: "10", current: width).value == 10)
		for draft in ["9", "121", "abc", ""] {
			#expect(SettingControl<GraphWidthLimits>.committedValue(from: draft, current: width) == width, "\(draft)")
		}
	}

}
