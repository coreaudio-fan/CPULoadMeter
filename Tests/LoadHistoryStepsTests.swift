@testable import CPULoadMeter
import Testing

///	The history fitted to a graph's steps: `LoadHistory.steps(count:)`, by the rule of Design.md section 5.5. Loads are
///	named by their sixteenths, and every list here is newest first, as the drawing walks it.
struct LoadHistoryStepsTests {

	///	A load whose user fraction is `numerator` sixteenths, distinct and exact, for telling loads apart.
	private func load(_ numerator: UInt32) -> CPULoad {
		CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: numerator, system: 0, idle: 16 - numerator, nice: 0)))
	}

	///	A history holding `newestFirst` at exactly that many samples.
	private func history(newestFirst: [UInt32]) -> LoadHistory {
		newestFirst.reversed().reduce(LoadHistory(sampleCount: newestFirst.count)) { $0.appending(load($1)) }
	}

	///	The steps of a history of `newestFirst` at `count` steps, as sixteenths.
	private func steps(of newestFirst: [UInt32], count: Int) -> [UInt32] {
		history(newestFirst: newestFirst).steps(count: count).map { UInt32(($0.total * 16).rounded()) }
	}

	@Test func asManyStepsAsSamplesIsEachSampleItsOwnStep() async throws {
		#expect(steps(of: [16, 0, 8, 6, 12], count: 5) == [16, 0, 8, 6, 12])
	}

	@Test func aWholeMultipleOfStepsDrawsEverySampleAsABlockThatWide() async throws {
		#expect(steps(of: [16, 8, 6], count: 6) == [16, 16, 8, 8, 6, 6])
		#expect(steps(of: [4, 12], count: 6) == [4, 4, 4, 12, 12, 12])
	}

	//	The user's own example turned uneven: 15 samples in 100 points. Every sample is a block of 6 or 7 points, the
	//	blocks are in order with the newest first, and they fill the width exactly.
	@Test func anUnevenFitDrawsBlocksOfTwoWidthsThatFillTheWidth() async throws {
		let samples = (1...15).map { UInt32($0) }
		let fitted = steps(of: samples, count: 100)
		let widths = samples.map { sample in fitted.filter { $0 == sample }.count }

		#expect(fitted.count == 100)
		#expect(fitted == fitted.sorted())
		#expect(Set(widths) == [6, 7])
		#expect(widths.reduce(0, +) == 100)
		#expect(fitted.first == 1)
		#expect(fitted.last == 15)
	}

	//	The user's example as given: a width of 90 and a history of 15 is 6 points to the sample.
	@Test func ninetyPointsForFifteenSamplesIsSixPointsEach() async throws {
		let samples = (1...15).map { UInt32($0) }
		let fitted = steps(of: samples, count: 90)

		#expect(samples.allSatisfy { sample in fitted.filter { $0 == sample }.count == 6 })
	}

	@Test func aWholeMultipleOfSamplesDrawsThePeakOfEachGroup() async throws {
		#expect(steps(of: [2, 16, 0, 8, 12, 6, 0, 0], count: 4) == [16, 8, 12, 0])
		#expect(steps(of: [1, 2, 3, 9, 5, 4], count: 2) == [3, 9])
	}

	//	Seven samples in three steps: every sample belongs to exactly one step, so a lone spike shows in one step and
	//	only one, wherever it sits.
	@Test func inAnUnevenFitEverySampleBelongsToExactlyOneStep() async throws {
		for spike in 0..<7 {
			let samples = (0..<7).map { UInt32($0 == spike ? 16 : 0) }
			let fitted = steps(of: samples, count: 3)

			#expect(fitted.filter { $0 == 16 }.count == 1, "spike at sample \(spike)")
			#expect(fitted.filter { $0 == 0 }.count == 2, "spike at sample \(spike)")
		}
		#expect(steps(of: [1, 2, 3, 4, 5, 6, 7], count: 3) == [2, 5, 7])
	}

	@Test func theNewestSampleIsAlwaysInTheFirstStep() async throws {
		#expect(steps(of: [16, 0, 0, 0, 0, 0, 0, 0, 0], count: 2).first == 16)
		#expect(steps(of: [16, 0], count: 9).first == 16)
	}

	@Test func oneSampleFillsEveryStep() async throws {
		#expect(steps(of: [12], count: 5) == [12, 12, 12, 12, 12])
	}

	@Test func noStepsOrNoSamplesGiveNoLoads() async throws {
		#expect(history(newestFirst: [16, 8]).steps(count: 0).isEmpty)
		#expect(history(newestFirst: [16, 8]).steps(count: -3).isEmpty)
		#expect(LoadHistory(sampleCount: 0).steps(count: 8).isEmpty)
	}

	//	The peak is by total load, and the winning sample arrives whole, its user and system fractions with it.
	@Test func thePeakIsByTotalLoadAndKeepsItsFractions() async throws {
		let light = CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: 6, system: 0, idle: 10, nice: 0)))
		let heavy = CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: 2, system: 8, idle: 6, nice: 0)))
		let fitted = LoadHistory(sampleCount: 2).appending(light).appending(heavy).steps(count: 1)

		#expect(fitted == [heavy])
	}

}
