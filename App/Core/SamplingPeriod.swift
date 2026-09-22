import Foundation

///	The sampling period: a whole number of seconds from 1 to 60.
///
///	The only ways to make one are the two failable initializers, so an out-of-range period cannot be constructed; the
///	control's reject-and-revert rule is their `nil`. Design.md, sections 2.11 and 4.1.
struct SamplingPeriod: Sendable, Equatable {

	///	The periods the control offers as presets.
	static let presets = [1, 2, 5, 10, 30].compactMap { SamplingPeriod(seconds: $0) }

	///	The period before the user has chosen one: one second.
	static let `default` = SamplingPeriod(checkedSeconds: 1)

	///	The whole seconds a period may be.
	static let range = 1...60

	///	The period in whole seconds.
	let seconds: Int

	///	A period of `seconds`, or `nil` if that is outside the range.
	init?(seconds: Int) {
		guard Self.range.contains(seconds) else {
			return nil
		}
		self.init(checkedSeconds: seconds)
	}

	///	A period parsed from what the user typed: a whole number in the range, with surrounding whitespace allowed, or
	///	`nil` for anything else, including a fraction.
	init?(text: String) {
		guard let seconds = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
			return nil
		}
		self.init(seconds: seconds)
	}

	///	The seconds, already known to be in range: the failable initializer's last step, and the default's literal.
	private init(checkedSeconds: Int) {
		seconds = checkedSeconds
	}

}
