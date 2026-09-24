import SwiftUI

///	The header: the processor's name and the CPU count with the period control beside them, and below, the machine-wide
///	CPU usage in `top`'s wording. Pinned to the top of the window at its natural height. Design.md, sections 2.6 and
///	5.4.
struct HeaderView: View {

	///	The processor's name, or `nil` if the kernel would not say.
	let processorName: String?

	///	How many CPUs the kernel reports, which is also how many graphs there are.
	let cpuCount: Int

	///	The latest machine-wide load, or `nil` before the first.
	let machineLoad: CPULoad?

	///	Whether the last sample failed to read; while samples fail, the usage line says so.
	let isLastSampleFailed: Bool

	///	The sampling period, for the control.
	@Binding var period: SamplingPeriod

	///	Whether the period field has focus. A click on the header's text clears it, which commits the field.
	let isEditingPeriod: FocusState<Bool>.Binding

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				//	Fixed sizes on both ends keep the window at least as wide as the header needs (section 2.5).
				Text("\(processorName ?? "Unknown CPU") · \(cpuCount) cores")
					.fixedSize()
					.onTapGesture {
						isEditingPeriod.wrappedValue = false
					}
				Spacer()
				SecondsControl(prompt: "Update every", unit: "seconds", value: $period, isEditing: isEditingPeriod)
			}
			Text(Self.usageLine(load: machineLoad, isLastSampleFailed: isLastSampleFailed))
				.monospacedDigit()
				.onTapGesture {
					isEditingPeriod.wrappedValue = false
				}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
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
