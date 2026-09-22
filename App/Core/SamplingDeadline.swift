///	The deadline that follows `deadline`: one period later, unless that has already passed, in which case one period
///	from now. Missed deadlines therefore collapse into one late sample rather than a burst, and the loop needs no branch
///	of its own. Design.md, sections 4.1 and 5.8.
func nextDeadline(after deadline: ContinuousClock.Instant, period: Duration, now: ContinuousClock.Instant) -> ContinuousClock.Instant {
	let scheduled = deadline + period
	return scheduled > now ? scheduled : now + period
}
