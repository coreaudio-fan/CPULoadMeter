@testable import CPULoadMeter
import Testing

struct SamplingDeadlineTests {

	private let now = ContinuousClock.now

	@Test func aDeadlineStillAheadAdvancesByThePeriod() async throws {
		let deadline = now - .seconds(1)
		let next = nextDeadline(after: deadline, period: .seconds(5), now: now)

		#expect(next == (deadline + .seconds(5)))
	}

	@Test func aDeadlineExactlyNowIsAlreadyPast() async throws {
		let deadline = now - .seconds(5)
		let next = nextDeadline(after: deadline, period: .seconds(5), now: now)

		#expect(next == (now + .seconds(5)))
	}

	@Test func missedDeadlinesCollapseIntoOnePeriodFromNow() async throws {
		let deadline = now - .seconds(3_600)
		let next = nextDeadline(after: deadline, period: .seconds(2), now: now)

		#expect(next == (now + .seconds(2)))
	}

	@Test func theRuleIsPureInItsInputs() async throws {
		let deadline = now + .milliseconds(10)

		for period in [Duration.seconds(1), .seconds(30), .seconds(60)] {
			#expect(nextDeadline(after: deadline, period: period, now: now) == (deadline + period))
		}
	}

}
