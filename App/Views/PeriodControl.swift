import SwiftUI

///	The update-period control: a narrow text field with a menu of presets beside it, a combo box composed in SwiftUI,
///	which has none. The field shows a draft of the user's typing until it commits, on Return or when the field loses
///	focus; a preset sets the period directly. Design.md, sections 2.11 and 5.9; the reasoning in B.2.
struct PeriodControl: View {

	///	The period in force, owned by whoever owns the monitor.
	@Binding var period: SamplingPeriod

	///	What the field shows: the user's typing until it commits, and the period otherwise.
	@State private var draft = ""

	///	Whether the field has focus. Losing it commits.
	@FocusState private var isEditing: Bool

	var body: some View {
		HStack(spacing: 4) {
			Text("Update every")
				.fixedSize()
			TextField("", text: $draft)
				.textFieldStyle(.roundedBorder)
				.multilineTextAlignment(.trailing)
				.frame(width: 44)
				.focused($isEditing)
				.onSubmit {
					commit()
				}
				.onChange(of: isEditing) {
					if !isEditing {
						commit()
					}
				}

			//	The presets. The menu is borderless and shows only its own chevron, beside the field it fills in.
			Menu {
				ForEach(SamplingPeriod.presets, id: \.seconds) { preset in
					Button(String(preset.seconds)) {
						period = preset
					}
				}
			} label: {
				Image(systemName: "chevron.down")
			}
			.menuStyle(.borderlessButton)
			.menuIndicator(.hidden)
			.fixedSize()
			Text("seconds")
				.fixedSize()
		}
		.onAppear {
			draft = String(period.seconds)
		}
		.onChange(of: period) {
			draft = String(period.seconds)
		}
	}

	///	Commits the draft: a whole number from 1 to 60 becomes the period; anything else is rejected, and the draft
	///	reverts to the period in force. There is no alert and no beep.
	private func commit() {
		period = Self.committedPeriod(from: draft, current: period)
		draft = String(period.seconds)
	}

	///	The reject-and-revert rule in one place: the period `draft` names, or `current` if it names none.
	static func committedPeriod(from draft: String, current: SamplingPeriod) -> SamplingPeriod {
		SamplingPeriod(text: draft) ?? current
	}

}
