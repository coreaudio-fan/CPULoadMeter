import SwiftUI

///	The control for one setting: a narrow text field with a menu of presets beside it, a combo box composed in SwiftUI,
///	which has none. The field shows a draft of the user's typing until it commits, on Return or when the field loses
///	focus; a preset sets the value directly. Switching to another window or app is not a focus loss, here as in every
///	Mac app: the draft waits. One control serves every setting in the app, which differ only in their limits. Design.md,
///	sections 2.11, 2.12, and 5.9; the reasoning in B.2.
struct SettingControl<Limits: SettingLimits>: View {

	///	The words before the field: "Sample every".
	let prompt: String

	///	The words after it: "seconds".
	let unit: String

	///	The value in force, owned by whoever owns what it configures.
	@Binding var value: BoundedSetting<Limits>

	///	Whether the field has focus. Losing it commits. The state is owned above, by the view that holds the control,
	///	because nothing else around it can take focus: a click elsewhere clears it from there, which is the only way a
	///	click elsewhere ends editing.
	let isEditing: FocusState<Bool>.Binding

	///	What the field shows: the user's typing until it commits, and the value otherwise.
	@State private var draft = ""

	var body: some View {
		HStack(spacing: 4) {
			Text(prompt)
				.fixedSize()
			TextField("", text: $draft)
				.textFieldStyle(.roundedBorder)
				.multilineTextAlignment(.trailing)
				.frame(width: 44)

				//	The field's leading edge is the control's `settingField` guide, so that a stack of these controls
				//	aligned on that guide puts their fields in one column, whatever their prompts' widths.
				.alignmentGuide(.settingField) { dimensions in
					dimensions[.leading]
				}
				.focused(isEditing)
				.onSubmit {
					commit()
				}
				.onChange(of: isEditing.wrappedValue) {
					if !(isEditing.wrappedValue) {
						commit()
					}
				}

			//	The presets. The menu is borderless and shows only its own chevron, beside the field it fills in.
			Menu {
				ForEach(BoundedSetting<Limits>.presets, id: \.value) { preset in
					Button(String(preset.value)) {
						value = preset
					}
				}
			} label: {
				Image(systemName: "chevron.down")
			}
			.menuStyle(.borderlessButton)
			.menuIndicator(.hidden)
			.fixedSize()
			Text(unit)
				.fixedSize()
		}
		.onAppear {
			draft = String(value.value)
		}
		.onChange(of: value) {
			draft = String(value.value)
		}

		//	The window closing hides the control rather than destroying it, and a field that was editing would stay the
		//	window's first responder while hidden, to be editing still when the window reopened; and a focus given up
		//	then is not noticed until the control is next updated, which is on reopening (observed 2026-10-02). So the
		//	control commits its draft itself as it goes, and gives the focus up with it.
		.onDisappear {
			if isEditing.wrappedValue {
				commit()
				isEditing.wrappedValue = false
			}
		}
	}

	///	Commits the draft: a whole number in the setting's range becomes the value; anything else is rejected, and the
	///	draft reverts to the value in force. There is no alert and no beep.
	private func commit() {
		value = Self.committedValue(from: draft, current: value)
		draft = String(value.value)
	}

	///	The reject-and-revert rule in one place: the value `draft` names, or `current` if it names none.
	static func committedValue(from draft: String, current: BoundedSetting<Limits>) -> BoundedSetting<Limits> {
		BoundedSetting(text: draft) ?? current
	}

}

extension HorizontalAlignment {

	///	The leading edge of a `SettingControl`'s text field. A stack of controls aligned on it lines their fields up in
	///	a column and lets their prompts, of whatever widths, end at that column; any view that sets no such guide aligns
	///	by its leading edge. Design.md, section 5.10.
	static let settingField = HorizontalAlignment(SettingFieldAlignment.self)

	///	The identifier behind `settingField`.
	private enum SettingFieldAlignment: AlignmentID {
		static func defaultValue(in context: ViewDimensions) -> CGFloat {
			context[.leading]
		}
	}

}
