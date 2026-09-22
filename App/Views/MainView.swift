import SwiftUI

///	The main window's content. A placeholder until the header and the graphs arrive: the processor's name
///	and the CPU count, which is what the header will lead with.
struct MainView: View {

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	How many CPUs the kernel reports.
	let cpuCount: Int

	var body: some View {
		Text("\(processorName ?? "Processor") · \(cpuCount) CPUs")
			.frame(minWidth: 480, minHeight: 240)
	}

}
