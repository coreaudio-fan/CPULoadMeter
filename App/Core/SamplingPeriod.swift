import Foundation

///	The limits of a sampling period: 1 to 60 seconds, 1 by default, which is also `top`'s default interval.
enum SamplingPeriodLimits: SecondsLimits {
	static let range = 1...60
	static let presetValues = [1, 2, 5, 10, 30]
	static let defaultValue = 1
}

///	A sampling period: a whole number of seconds from 1 to 60. The window's monitor and the menu bar's each have one.
///	Design.md, sections 2.11 and 4.1.
typealias SamplingPeriod = BoundedSetting<SamplingPeriodLimits>

extension BoundedSetting where Limits == SamplingPeriodLimits {

	///	The period as the clock measures it.
	var duration: Duration {
		.seconds(value)
	}

}
