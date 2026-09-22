import SwiftUI

///	The main window's content: the header above a hairline above the stack of LoadViews, which fills the rest. The
///	header is a placeholder until its own view arrives: the processor's name, the CPU count, and the machine-wide usage
///	line, live. Design.md, section 5.3.
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

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	Told the step count whenever the stack's width changes.
	let reportStepCount: @MainActor (Int) -> Void

	var body: some View {
		VStack(spacing: 0) {
			VStack(spacing: 2) {
				Text("\(processorName ?? "Processor") · \(cpuCount) CPUs")
				Text(usageLine)
					.monospacedDigit()
			}
			.padding(8)
			.frame(maxWidth: .infinity)
			.fixedSize(horizontal: false, vertical: true)

			Hairline()

			LoadStackView(histories: histories, reportStepCount: reportStepCount)
		}
		.frame(idealWidth: Self.idealWidth)
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
