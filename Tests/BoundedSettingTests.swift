@testable import CPULoadMeter
import Testing

///	Every setting's limits, held to what `BoundedSetting` assumes of them, and the mechanics they share.
struct BoundedSettingTests {

	///	What holds of any limits: the default is in range and is what `default` returns, and the presets are all in
	///	range, in ascending order, with none dropped.
	private func expectSoundLimits<Limits: SettingLimits>(_ limits: Limits.Type) {
		#expect(Limits.range.contains(Limits.defaultValue), "\(limits)")
		#expect(BoundedSetting<Limits>.default.value == Limits.defaultValue, "\(limits)")
		#expect(BoundedSetting<Limits>.presets.map(\.value) == Limits.presetValues, "\(limits)")
		#expect(Limits.presetValues == Limits.presetValues.sorted(), "\(limits)")
	}

	///	What holds of any setting at its bounds: both ends are values, and one past either end is not.
	private func expectBounds<Limits: SettingLimits>(_ limits: Limits.Type) {
		#expect(BoundedSetting<Limits>(value: Limits.range.lowerBound)?.value == Limits.range.lowerBound, "\(limits)")
		#expect(BoundedSetting<Limits>(value: Limits.range.upperBound)?.value == Limits.range.upperBound, "\(limits)")
		#expect(BoundedSetting<Limits>(value: Limits.range.lowerBound - 1) == nil, "\(limits)")
		#expect(BoundedSetting<Limits>(value: Limits.range.upperBound + 1) == nil, "\(limits)")
		#expect(BoundedSetting<Limits>(text: " \(Limits.range.upperBound) ")?.value == Limits.range.upperBound, "\(limits)")
		for text in ["abc", "2.5", "", " ", "5s", "1e1", "0x10"] {
			#expect(BoundedSetting<Limits>(text: text) == nil, "\(limits) \(text)")
		}
	}

	@Test func everySettingsLimitsAreSound() async throws {
		expectSoundLimits(SamplingPeriodLimits.self)
		expectSoundLimits(WindowHistoryLimits.self)
		expectSoundLimits(MenuBarHistoryLimits.self)
		expectSoundLimits(GraphWidthLimits.self)
	}

	@Test func everySettingHoldsItsBounds() async throws {
		expectBounds(SamplingPeriodLimits.self)
		expectBounds(WindowHistoryLimits.self)
		expectBounds(MenuBarHistoryLimits.self)
		expectBounds(GraphWidthLimits.self)
	}

	@Test func theLimitsAreAsSpecified() async throws {
		#expect(SamplingPeriodLimits.range == 1...60)
		#expect(WindowHistoryLimits.range == 30...3_600)
		#expect(WindowHistoryLimits.presetValues == [60, 300, 900, 3_600])
		#expect(WindowHistoryLength.default.seconds == 300)
		#expect(MenuBarHistoryLimits.range == 30...120)
		#expect(MenuBarHistoryLimits.presetValues == [30, 60, 90, 120])
		#expect(MenuBarHistoryLength.default.seconds == 60)
		#expect(GraphWidthLimits.range == 10...120)
		#expect(GraphWidthLimits.presetValues == [20, 30, 40, 60])
		#expect(GraphWidth.default.value == 30)
	}

}
