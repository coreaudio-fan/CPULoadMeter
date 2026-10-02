import SwiftUI

///	The main window's content: the header above a hairline above the stack of LoadViews, which fills the rest.
///	Design.md, section 5.3.
struct MainView: View {

	///	The least height one CPU's graph is given: what the window's minimum height allows each of them, which is also
	///	what it opens with on first launch, the window's first size being its minimum (Design.md, section 2.5 and D43).
	static let minimumGraphHeight: CGFloat = 24

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

			//	The stack's height is the window's to decide: at least the minimum for every graph, and as much more as
			//	the window has. The window's first size is its minimum, which the app's placement asks the content for.
			LoadStackView(histories: histories)
				.frame(minHeight: Self.minimumGraphHeight * CGFloat(histories.count), maxHeight: .infinity)
				.contentShape(Rectangle())
				.onTapGesture {
					isEditingPeriod = false
					isEditingHistory = false
				}
		}
	}

}
