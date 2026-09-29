import SwiftUI

///	The settings window's content: the launch checkbox, and below it the menu bar graph's period, history length, and
///	width. Design.md, section 2.12.
struct SettingsView: View {

	///	Whether the main window opens at launch. The app reads the same key to choose its launch behavior.
	@AppStorage(DefaultsKey.isMainWindowOpenedAtLaunch) private var isMainWindowOpenedAtLaunch = true

	///	The menu bar graph's period in whole seconds. The extra's label reads the same key and applies it.
	@AppStorage(DefaultsKey.menuBarPeriodSeconds) private var menuBarPeriodSeconds = SamplingPeriod.default.seconds

	///	The menu bar graph's history length in samples, likewise.
	@AppStorage(DefaultsKey.menuBarHistorySamples) private var menuBarHistorySamples = MenuBarHistoryLength.default.value

	///	The width of one CPU's graph in the menu bar in whole points, likewise.
	@AppStorage(DefaultsKey.menuBarGraphWidth) private var menuBarGraphWidth = GraphWidth.default.value

	///	Whether the period field has focus. Owned here, as the main view owns its fields', so that a click elsewhere in
	///	the window can clear it, which commits the field.
	@FocusState private var isEditingPeriod: Bool

	///	Whether the history field has focus, likewise.
	@FocusState private var isEditingHistory: Bool

	///	Whether the width field has focus, likewise.
	@FocusState private var isEditingWidth: Bool

	var body: some View {
		Form {
			Toggle("Open main window at launch", isOn: $isMainWindowOpenedAtLaunch)
			Section("Menu bar graph") {
				SettingControl(prompt: "Update every", unit: "seconds", value: menuBarPeriod, isEditing: $isEditingPeriod)
				SettingControl(prompt: "Keep", unit: "samples of history", value: menuBarHistory, isEditing: $isEditingHistory)
				SettingControl(prompt: "Draw each core", unit: "points wide", value: graphWidth, isEditing: $isEditingWidth)
			}
		}
		.contentShape(Rectangle())
		.onTapGesture {
			isEditingPeriod = false
			isEditingHistory = false
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

	///	The stored history length as the control's type, likewise.
	private var menuBarHistory: Binding<MenuBarHistoryLength> {
		Binding {
			MenuBarHistoryLength(value: menuBarHistorySamples) ?? .default
		} set: { history in
			menuBarHistorySamples = history.value
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
