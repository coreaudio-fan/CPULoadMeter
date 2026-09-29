@testable import CPULoadMeter
import Testing

struct LoadHistoryTests {

	///	A load whose user fraction is `numerator` sixteenths, distinct and exact, for telling loads apart.
	private func load(_ numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: numerator, system: 0, idle: 16 - numerator, nice: 0)))
	}

	@Test func aNewHistoryIsAllZerosAtTheSampleCount() async throws {
		let history = LoadHistory(sampleCount: 3)

		#expect(history.sampleCount == 3)
		#expect(history.loads == [.zero, .zero, .zero])
	}

	@Test func appendingKeepsTheLengthAndDropsTheOldest() async throws {
		let history = LoadHistory(sampleCount: 3).appending(load(1)).appending(load(2))
		let later = history.appending(load(3)).appending(load(4))

		#expect(history.loads == [.zero, load(1), load(2)])
		#expect(later.sampleCount == 3)
		#expect(later.loads == [load(2), load(3), load(4)])
	}

	@Test func growingAddsZerosAtTheOldestEnd() async throws {
		let history = LoadHistory(sampleCount: 2).appending(load(1)).appending(load(2))
		let wider = history.resized(toSampleCount: 4)

		#expect(wider.sampleCount == 4)
		#expect(wider.loads == [.zero, .zero, load(1), load(2)])
	}

	@Test func shrinkingDropsTheOldestFirst() async throws {
		let history = LoadHistory(sampleCount: 4).appending(load(1)).appending(load(2)).appending(load(3)).appending(load(4))
		let narrower = history.resized(toSampleCount: 2)

		#expect(narrower.sampleCount == 2)
		#expect(narrower.loads == [load(3), load(4)])
	}

	@Test func resizingToTheSameCountIsTheIdentity() async throws {
		let history = LoadHistory(sampleCount: 3).appending(load(5))

		#expect(history.resized(toSampleCount: 3) == history)
	}

	@Test func noSamplesStayEmptyUnderEveryOperation() async throws {
		let empty = LoadHistory(sampleCount: 0)

		#expect(empty.loads.isEmpty)
		#expect(empty.appending(load(1)).loads.isEmpty)
		#expect(empty.resized(toSampleCount: 0).loads.isEmpty)
		#expect(LoadHistory(sampleCount: 3).resized(toSampleCount: 0).loads.isEmpty)
		#expect(empty.resized(toSampleCount: 2).loads == [.zero, .zero])
	}

	@Test func aNegativeSampleCountIsTreatedAsZero() async throws {
		#expect(LoadHistory(sampleCount: -1).loads.isEmpty)
		#expect(LoadHistory(sampleCount: 2).resized(toSampleCount: -1).loads.isEmpty)
	}

}
