import SwiftUI

///	The header: the processor's name and the CPU count, the machine-wide CPU usage in `top`'s wording, and the two
///	controls, pinned to the top of the window at its natural height.
///
///	It has two arrangements, which `HeaderLayout` chooses between by the width it is given. Where there is room, two
///	rows, each with its text at the left and a control at the right. Where there is not, one column: the two texts, then
///	the two controls below them. The texts are in the same place in both, and the controls are the same size in both;
///	only the controls' places change. The window can therefore be as narrow as the widest single piece. Design.md,
///	sections 2.5, 2.6, and 5.4.
struct HeaderView: View {

	///	The widest the usage line gets: two digits in each of its three figures, which is the most a sum of 100 allows,
	///	and with monospaced digits any such line is as wide as any other. The line reserves this width whatever it
	///	reads, so that neither the width at which the layout changes nor the window's minimum width moves as the figures
	///	do.
	static let widestUsageLine = usageLine(load: CPULoad(TickDelta(from: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), to: CPUTicks(user: 33, system: 33, idle: 34, nice: 0))), isLastSampleFailed: false)

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	How many CPUs the kernel reports, which is also how many graphs there are.
	let cpuCount: Int

	///	The latest machine-wide load, or `nil` before the first.
	let machineLoad: CPULoad?

	///	Whether the last sample failed to read; while samples fail, the usage line says so.
	let isLastSampleFailed: Bool

	///	The sampling period, for its control.
	@Binding var period: SamplingPeriod

	///	The history length, for its control.
	@Binding var history: WindowHistoryLength

	///	Whether the period field has focus.
	let isEditingPeriod: FocusState<Bool>.Binding

	///	Whether the history field has focus.
	let isEditingHistory: FocusState<Bool>.Binding

	var body: some View {
		//	The four pieces, in the order the layout expects them.
		HeaderLayout {
			nameText
			usageText
			periodControl
			historyControl
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	///	The processor's name and the CPU count. A click on it ends editing.
	private var nameText: some View {
		Text("\(processorName ?? "Unknown CPU") · \(cpuCount) cores")
			.fixedSize()
			.onTapGesture {
				endEditing()
			}
	}

	///	The usage line, at the width of the widest it can be. The widest line is laid out and hidden, and the line as it
	///	reads now is drawn over its leading edge.
	private var usageText: some View {
		Text(Self.widestUsageLine)
			.monospacedDigit()
			.fixedSize()
			.hidden()
			.overlay(alignment: .leading) {
				Text(Self.usageLine(load: machineLoad, isLastSampleFailed: isLastSampleFailed))
					.monospacedDigit()
					.fixedSize()
			}
			.contentShape(Rectangle())
			.onTapGesture {
				endEditing()
			}
	}

	///	The period's control.
	private var periodControl: some View {
		SettingControl(prompt: "Sample every", unit: "seconds", value: $period, isEditing: isEditingPeriod)
	}

	///	The history length's control.
	private var historyControl: some View {
		SettingControl(prompt: "Show the last", unit: "samples", value: $history, isEditing: isEditingHistory)
	}

	///	Takes focus from both fields, which commits whichever was editing: what a click on the header's text does.
	private func endEditing() {
		isEditingPeriod.wrappedValue = false
		isEditingHistory.wrappedValue = false
	}

	///	The usage line: `top`'s wording with whole percentages that sum to 100; a dash before the first load; and a
	///	plain statement while samples are failing (section 2.15).
	static func usageLine(load: CPULoad?, isLastSampleFailed: Bool) -> String {
		let line: String
		if isLastSampleFailed {
			line = "CPU usage unavailable"
		} else if let load {
			let percentages = UsagePercentages(load)
			line = "CPU usage: \(percentages.user)% user, \(percentages.system)% system, \(percentages.idle)% idle"
		} else {
			line = "CPU usage: —"
		}
		return line
	}

}
