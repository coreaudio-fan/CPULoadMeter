@testable import CPULoadMeter
import Testing

struct TickDeltaTests {

	private func ticks(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32 = 0) -> CPUTicks {
		CPUTicks(user: user, system: system, idle: idle, nice: nice)
	}

	@Test func ordinaryDeltasAreTheDifferences() async throws {
		let delta = TickDelta(from: ticks(user: 100, system: 50, idle: 800), to: ticks(user: 130, system: 60, idle: 860))

		#expect(delta.user == 30)
		#expect(delta.system == 10)
		#expect(delta.idle == 60)
		#expect(delta.busy == 40)
		#expect(delta.total == 100)
	}

	@Test func niceTicksCountAsUser() async throws {
		let delta = TickDelta(from: ticks(user: 10, system: 0, idle: 0, nice: 5), to: ticks(user: 12, system: 0, idle: 0, nice: 9))

		#expect(delta.user == 6)
	}

	@Test func zeroElapsedTicksGiveAZeroDelta() async throws {
		let sample = ticks(user: 7, system: 8, idle: 9)

		#expect(TickDelta(from: sample, to: sample) == .zero)
		#expect(TickDelta(from: sample, to: sample).total == 0)
	}

	//	A counter that wrapped between the samples: two ticks short of the top, then three past zero.
	@Test func aWrappedCounterYieldsTheElapsedTicks() async throws {
		let delta = TickDelta(from: ticks(user: UInt32.max - 1, system: UInt32.max, idle: 0), to: ticks(user: 3, system: 0, idle: 0))

		#expect(delta.user == 5)
		#expect(delta.system == 1)
		#expect(delta.idle == 0)
	}

	@Test func deltasAddMemberwise() async throws {
		let first = TickDelta(from: ticks(user: 0, system: 0, idle: 0), to: ticks(user: 1, system: 2, idle: 3))
		let second = TickDelta(from: ticks(user: 0, system: 0, idle: 0), to: ticks(user: 10, system: 20, idle: 30))
		let sum = first + second

		#expect(sum.user == 11)
		#expect(sum.system == 22)
		#expect(sum.idle == 33)
		#expect(sum + .zero == sum)
	}

	//	Widening happens after the subtraction, so summed deltas can exceed what one 32-bit counter can hold.
	@Test func sumsAreNotConfinedToThirtyTwoBits() async throws {
		let full = TickDelta(from: ticks(user: 0, system: 0, idle: 0), to: ticks(user: UInt32.max, system: 0, idle: 0))
		let sum = full + full

		#expect(sum.user == (2 * UInt64(UInt32.max)))
	}

}
