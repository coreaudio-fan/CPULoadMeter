import Foundation
import os

///	The app's diagnostics: debug-level messages, under the bundle identifier.
///
///	A shell reads them with `log stream --debug --predicate 'subsystem == "coreaudio-fan.CPULoadMeter"'`.
///
///	They are how the cadence, the cost, and the agreement with `top` are observed without eyes, and they are present in
///	every build: a debug-level message is not persisted and costs almost nothing when no one is listening. Design.md,
///	section 5.8 and B.17.
enum Diagnostics {

	///	The one logger. The subsystem is the bundle identifier, as the spec requires.
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CPULoadMeter", category: "monitor")

	///	Written once, at launch: the processor's name and how many CPUs the kernel reports.
	static func logLaunch(processorName: String?, cpuCount: Int) {
		logger.debug("Launched on \(processorName ?? "an unnamed processor", privacy: .public) with \(cpuCount) CPUs")
	}

	///	Written once per sample, with numbers only after the monitor's name: the sample's index; how late it was and how
	///	long it took, in milliseconds; the CPU count; and the machine-wide user, system, and idle tick deltas, which are
	///	what `top` is checked against. A sample that was a baseline only, the CPU count having changed, has no deltas
	///	and says so. The name in brackets tells the two monitors' samples apart.
	static func logSample(monitor: String, index: Int, lateness: Duration, duration: Duration, cpuCount: Int, delta: TickDelta?) {
		let late = milliseconds(lateness)
		let took = milliseconds(duration)
		if let delta {
			logger.debug("[\(monitor, privacy: .public)] Sample \(index): late \(late, format: .fixed(precision: 1)) ms, took \(took, format: .fixed(precision: 3)) ms, \(cpuCount) CPUs, ticks user \(delta.user) system \(delta.system) idle \(delta.idle)")
		} else {
			logger.debug("[\(monitor, privacy: .public)] Sample \(index): late \(late, format: .fixed(precision: 1)) ms, took \(took, format: .fixed(precision: 3)) ms, \(cpuCount) CPUs, baseline")
		}
	}

	///	Written whenever a monitor's step count changes.
	static func logStepCount(monitor: String, _ stepCount: Int) {
		logger.debug("[\(monitor, privacy: .public)] Step count \(stepCount)")
	}

	///	Written when a monitor's sampling starts, with the CPU count and the step count, and when it stops.
	static func logSampling(monitor: String, isStarting: Bool, cpuCount: Int, stepCount: Int) {
		if isStarting {
			logger.debug("[\(monitor, privacy: .public)] Sampling started: \(cpuCount) CPUs, step count \(stepCount)")
		} else {
			logger.debug("[\(monitor, privacy: .public)] Sampling stopped; history dropped at step count \(stepCount)")
		}
	}

	///	A duration in milliseconds, for the log.
	private static func milliseconds(_ duration: Duration) -> Double {
		let components = duration.components
		return (Double(components.seconds) * 1_000) + (Double(components.attoseconds) / 1e15)
	}

}
