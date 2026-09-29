import SwiftUI

///	The header: the processor's name and the CPU count with the period control beside them, and below, the machine-wide
///	CPU usage in `top`'s wording with the history control beside it. Pinned to the top of the window at its natural
///	height. Design.md, sections 2.6 and 5.4.
struct HeaderView: View {

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
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				//	Fixed sizes on both ends keep the window at least as wide as the header needs (section 2.5).
				Text("\(processorName ?? "Unknown CPU") · \(cpuCount) cores")
					.fixedSize()
					.onTapGesture {
						endEditing()
					}
				Spacer()
				SettingControl(prompt: "Update every", unit: "seconds", value: $period, isEditing: isEditingPeriod)
			}
			HStack {
				Text(Self.usageLine(load: machineLoad, isLastSampleFailed: isLastSampleFailed))
					.monospacedDigit()
					.fixedSize()
					.onTapGesture {
						endEditing()
					}
				Spacer()
				SettingControl(prompt: "Show the last", unit: "seconds", value: $history, isEditing: isEditingHistory)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
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
