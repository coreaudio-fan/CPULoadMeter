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

}
