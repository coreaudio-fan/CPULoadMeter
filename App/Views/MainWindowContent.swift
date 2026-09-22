import SwiftUI

///	The main window's root view: the one place that reads the monitor, and the place the app's own body must not.
///
///	An `App` body that reads an observed value is re-evaluated whenever that value changes, and re-evaluating the scenes
///	rebuilds the menus with them: with the monitor's state read in the app's body, every sample rebuilt the menu bar and
///	the extra's menu once a second, which changed an open menu's items under the mouse and closed it mid-click (observed
///	2026-09-22; Design.md, D.6). Reading the state here confines each sample's re-evaluation to the window's content,
///	and the values pass down from here as Design.md section 4.2 asks.
struct MainWindowContent: View {

	///	The processor's name, read once at launch; `nil` if the kernel would not say.
	let processorName: String?

	///	The sampler, owned by the app. Bindable, so that the header's control can bind to its period.
	@Bindable var monitor: LoadMonitor

	///	The sampling period in whole seconds, stored again whenever the monitor's changes: the monitor persists nothing.
	@AppStorage(DefaultsKey.samplingPeriodSeconds) private var samplingPeriodSeconds = SamplingPeriod.default.seconds

	var body: some View {
		MainView(processorName: processorName, machineLoad: monitor.state.machineLoad, isLastSampleFailed: monitor.lastError != nil, histories: monitor.state.histories, reportStepCount: monitor.setStepCount, period: $monitor.period)
			.onChange(of: monitor.period) {
				samplingPeriodSeconds = monitor.period.seconds
			}
	}

}
