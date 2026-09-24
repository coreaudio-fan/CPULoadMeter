import Foundation

///	The menu bar graph's history length: a whole number of seconds from 30 to 120.
///
///	As with `SamplingPeriod`, the only ways to make one are the two failable initializers, so an out-of-range length
///	cannot be constructed. What the length decides is the width of each CPU's graph: the whole periods it holds, which
///	is its step count. Design.md, sections 2.4, 2.12, and 4.1.
struct HistoryLength: WholeSeconds {

	///	The lengths the control offers as presets.
	static let presets = [30, 60, 90, 120].compactMap { HistoryLength(seconds: $0) }

	///	The length before the user has chosen one: a minute.
	static let `default` = HistoryLength(checkedSeconds: 60)

	///	The whole seconds a length may be.
	static let range = 30...120

	///	The length in whole seconds.
	let seconds: Int

	///	A length of `seconds`, or `nil` if that is outside the range.
	init?(seconds: Int) {
		guard Self.range.contains(seconds) else {
			return nil
		}
		self.init(checkedSeconds: seconds)
	}

	///	A length parsed from what the user typed: a whole number in the range, with surrounding whitespace allowed, or
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

	///	The steps a graph of this length holds at `period`: the whole periods that fit, a partial one dropped, and never
	///	fewer than one, so that a length shorter than the period still leaves a graph to see.
	func stepCount(at period: SamplingPeriod) -> Int {
		max(1, seconds / period.seconds)
	}

}
