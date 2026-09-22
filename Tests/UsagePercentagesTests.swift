@testable import CPULoadMeter
import Testing

struct UsagePercentagesTests {

	private func load(user: UInt32, system: UInt32, idle: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: user, system: system, idle: idle, nice: 0)))
	}

	@Test func exactQuartersRoundToThemselves() async throws {
		let percentages = UsagePercentages(load(user: 1, system: 1, idle: 2))

		#expect(percentages.user == 25)
		#expect(percentages.system == 25)
		#expect(percentages.idle == 50)
	}

	//	User 0.5% and system 99.5%: rounded on their own they would be 1 and 100, leaving idle at −1. Cumulatively, busy
	//	is 100, user 1, system 99, idle 0.
	@Test func theHalfPercentCaseStaysNonNegativeAndSumsToOneHundred() async throws {
		let percentages = UsagePercentages(load(user: 1, system: 199, idle: 0))

		#expect(percentages.user == 1)
		#expect(percentages.system == 99)
		#expect(percentages.idle == 0)
	}

	@Test func zeroLoadIsAllIdle() async throws {
		let percentages = UsagePercentages(.zero)

		#expect(percentages.user == 0)
		#expect(percentages.system == 0)
		#expect(percentages.idle == 100)
	}

	@Test func aFullyBusyIntervalLeavesNoIdle() async throws {
		let percentages = UsagePercentages(load(user: 2, system: 1, idle: 0))

		//	2/3 is 66.7%, 1/3 is 33.3%: busy 100, user 67, system 33.
		#expect(percentages.user == 67)
		#expect(percentages.system == 33)
		#expect(percentages.idle == 0)
	}

	@Test func everyResultIsNonNegativeAndSumsToOneHundred() async throws {
		for (user, system, idle) in [(1, 199, 0), (199, 1, 0), (1, 1, 398), (3, 0, 997), (0, 1, 999), (5, 5, 5), (0, 0, 0)] {
			let percentages = UsagePercentages(load(user: UInt32(user), system: UInt32(system), idle: UInt32(idle)))

			#expect(percentages.user >= 0)
			#expect(percentages.system >= 0)
			#expect(percentages.idle >= 0)
			#expect((percentages.user + percentages.system + percentages.idle) == 100)
		}
	}

}
