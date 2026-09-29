import Foundation

///	What one setting allows: the whole numbers it may be, the ones its control offers as presets, and the one it is
///	before the user has chosen. A type conforming to this is never instantiated; it is a name for a set of limits, and
///	the compiler keeps a value made under one from being used where another is expected.
protocol SettingLimits: Sendable {

	///	The whole numbers the setting may be.
	static var range: ClosedRange<Int> { get }

	///	The values the control's pop-up offers, in the order it lists them.
	static var presetValues: [Int] { get }

	///	The value before the user has chosen one.
	static var defaultValue: Int { get }

}

///	A setting held within its limits: a whole number that `Limits.range` contains, always.
///
///	The only ways to make one are the two failable initializers, so an out-of-range setting cannot be constructed, and
///	the control's reject-and-revert rule is their `nil`. Every setting in the app is one of these under its own limits:
///	the sampling periods, the history lengths, and the menu bar graph's width. They share the mechanics and differ only
///	in the numbers, and a period cannot be passed where a width is wanted because the two are different types.
///	Design.md, sections 2.11, 2.12, and 4.1.
struct BoundedSetting<Limits: SettingLimits>: Sendable, Equatable {

	///	The values the control offers as presets. A preset outside the range would be dropped here; the tests hold every
	///	set of limits to presets within its range.
	static var presets: [BoundedSetting] {
		Limits.presetValues.compactMap { BoundedSetting(value: $0) }
	}

	///	The value before the user has chosen one. Were a default ever declared outside its own range, this would be the
	///	range's lower bound, not a trap; the tests hold every default within its range.
	static var `default`: BoundedSetting {
		BoundedSetting(value: Limits.defaultValue) ?? BoundedSetting(checkedValue: Limits.range.lowerBound)
	}

	///	The whole number the setting is.
	let value: Int

	///	A setting of `value`, or `nil` if that is outside the range.
	init?(value: Int) {
		guard Limits.range.contains(value) else {
			return nil
		}
		self.init(checkedValue: value)
	}

	///	A setting parsed from what the user typed: a whole number in the range, with surrounding whitespace allowed, or
	///	`nil` for anything else, including a fraction.
	init?(text: String) {
		guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}
		self.init(value: value)
	}

	///	The value, already known to be in range: the failable initializer's last step, and the default's fallback.
	private init(checkedValue: Int) {
		value = checkedValue
	}

}

///	Limits of a setting measured in whole seconds.
protocol SecondsLimits: SettingLimits {
}

extension BoundedSetting where Limits: SecondsLimits {

	///	The setting in whole seconds.
	var seconds: Int {
		value
	}

	///	A setting of `seconds`, or `nil` if that is outside the range.
	init?(seconds: Int) {
		self.init(value: seconds)
	}

}
