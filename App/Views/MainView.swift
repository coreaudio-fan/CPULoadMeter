import SwiftUI

///	The main window's content: the header above a hairline above the stack of LoadViews, which fills the rest.
///	Design.md, section 5.3.
struct MainView: View {

	///	The width the window opens at on first launch (Design.md, section 2.5): wide enough for the header's two-line
	///	layout, with room to spare, so that a first launch does not come up in the column.
	static let idealWidth: CGFloat = 600

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	The latest machine-wide load, or `nil` before the first.
	let machineLoad: CPULoad?

	///	Whether the last sample failed to read.
	let isLastSampleFailed: Bool

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	The sampling period, for the header's control.
	@Binding var period: SamplingPeriod

	///	The history length, for the header's control.
	@Binding var history: WindowHistoryLength

	///	Whether the header's period field has focus. Owned here so that a click on the graphs can clear it: nothing else
	///	in the window can take focus, so without this a click elsewhere would leave the field editing.
	@FocusState private var isEditingPeriod: Bool

	///	Whether the header's history field has focus, likewise.
	@FocusState private var isEditingHistory: Bool

	var body: some View {
		VStack(spacing: 0) {
			HeaderView(processorName: processorName, cpuCount: histories.count, machineLoad: machineLoad, isLastSampleFailed: isLastSampleFailed, period: $period, history: $history, isEditingPeriod: $isEditingPeriod, isEditingHistory: $isEditingHistory)
				.frame(maxWidth: .infinity)
				.fixedSize(horizontal: false, vertical: true)

			Hairline()

			LoadStackView(histories: histories)
				.contentShape(Rectangle())
				.onTapGesture {
					isEditingPeriod = false
					isEditingHistory = false
				}
		}
		.frame(idealWidth: Self.idealWidth)
	}

}
