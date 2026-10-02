import SwiftUI

///	The settings window's content: the launch checkbox, a rule, and below it the menu bar graph's section, a header over
///	its period and width.
///
///	Laid out by hand rather than as a `Form`: the form's default style on macOS puts labels in a trailing-aligned column
///	beside a column of controls, which indented the checkbox and the section's title where both are wanted at the left
///	edge, and gave the two sections nothing to tell them apart but a title. Here everything starts at the leading edge,
///	the rule divides the sections, and the title is a headline. Design.md, sections 2.12 and 5.10, and D44.
struct SettingsView: View {

	///	Whether the main window opens at launch. The app reads the same key to choose its launch behavior.
	@AppStorage(DefaultsKey.isMainWindowOpenedAtLaunch) private var isMainWindowOpenedAtLaunch = true

	///	The menu bar graph's period in whole seconds. The extra's label reads the same key and applies it.
	@AppStorage(DefaultsKey.menuBarPeriodSeconds) private var menuBarPeriodSeconds = SamplingPeriod.default.seconds

	///	The width of one CPU's graph in the menu bar in whole points, likewise.
	@AppStorage(DefaultsKey.menuBarGraphWidth) private var menuBarGraphWidth = GraphWidth.default.value

	///	Whether the period field has focus. Owned here, as the main view owns its fields', so that a click elsewhere in
	///	the window can clear it, which commits the field.
	@FocusState private var isEditingPeriod: Bool

	///	Whether the width field has focus, likewise.
	@FocusState private var isEditingWidth: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Toggle("Open main window at launch", isOn: $isMainWindowOpenedAtLaunch)
			Divider()
				.padding(.vertical, 4)
			Text("Menu bar graph")
				.font(.headline)

			//	The two controls' fields in one column: the stack aligns them on the fields' leading edges, so the
			//	control with the shorter prompt sits further right, and the one with the longer stays at the leading
			//	edge.
			VStack(alignment: .settingField, spacing: 12) {
				SettingControl(prompt: "Sample every", unit: "seconds", value: menuBarPeriod, isEditing: $isEditingPeriod)
				SettingControl(prompt: "Draw each core", unit: "points wide", value: graphWidth, isEditing: $isEditingWidth)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
		.onTapGesture {
			isEditingPeriod = false
			isEditingWidth = false
		}
		.padding(20)
		.frame(width: 360)
	}

	///	The stored period as the control's type: an invalid stored value reads as the default, and a commit stores the
	///	seconds.
	private var menuBarPeriod: Binding<SamplingPeriod> {
		Binding {
			SamplingPeriod(seconds: menuBarPeriodSeconds) ?? .default
		} set: { period in
			menuBarPeriodSeconds = period.seconds
		}
	}

	///	The stored graph width as the control's type, likewise.
	private var graphWidth: Binding<GraphWidth> {
		Binding {
			GraphWidth(value: menuBarGraphWidth) ?? .default
		} set: { width in
			menuBarGraphWidth = width.value
		}
	}

}
