import SwiftUI

///	The main window's content. A placeholder until the header and the graphs arrive: the processor's name, the CPU
///	count, and the machine-wide usage line the header will show, live.
struct MainView: View {

	///	The width the window opens at on first launch (Design.md, section 2.5), and the step count the monitor starts
	///	from when no width has ever been stored (section 2.10).
	static let idealWidth: CGFloat = 480

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	How many CPUs the kernel reports.
	let cpuCount: Int

	///	The latest machine-wide load, or `nil` before the first.
	let machineLoad: CPULoad?

	var body: some View {
		VStack(spacing: 8) {
			Text("\(processorName ?? "Processor") · \(cpuCount) CPUs")
			Text(usageLine)
				.monospacedDigit()
		}
		.frame(minWidth: Self.idealWidth, minHeight: 240)
	}

	///	The header's line in `top`'s wording, or a dash before the first load.
	private var usageLine: String {
		if let machineLoad {
			let percentages = UsagePercentages(machineLoad)
			return "CPU usage: \(percentages.user)% user, \(percentages.system)% system, \(percentages.idle)% idle"
		} else {
			return "CPU usage: —"
		}
	}

}
