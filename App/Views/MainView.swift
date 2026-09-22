import SwiftUI

///	The main window's content: the header above a hairline above the stack of LoadViews, which fills the rest.
///	Design.md, section 5.3.
struct MainView: View {

	///	The width the window opens at on first launch (Design.md, section 2.5), and the step count the monitor starts
	///	from when no width has ever been stored (section 2.10).
	static let idealWidth: CGFloat = 480

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	The latest machine-wide load, or `nil` before the first.
	let machineLoad: CPULoad?

	///	Whether the last sample failed to read.
	let isLastSampleFailed: Bool

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	Told the step count whenever the stack's width changes.
	let reportStepCount: @MainActor (Int) -> Void

	///	The sampling period, for the header's control.
	@Binding var period: SamplingPeriod

	///	Whether the header's period field has focus. Owned here so that a click on the graphs can clear it: nothing else
	///	in the window can take focus, so without this a click elsewhere would leave the field editing.
	@FocusState private var isEditingPeriod: Bool

	var body: some View {
		VStack(spacing: 0) {
			HeaderView(processorName: processorName, cpuCount: histories.count, machineLoad: machineLoad, isLastSampleFailed: isLastSampleFailed, period: $period, isEditingPeriod: $isEditingPeriod)
				.frame(maxWidth: .infinity)
				.fixedSize(horizontal: false, vertical: true)

			Hairline()

			LoadStackView(histories: histories, reportStepCount: reportStepCount)
				.contentShape(Rectangle())
				.onTapGesture {
					isEditingPeriod = false
				}
		}
		.frame(idealWidth: Self.idealWidth)
	}

}
