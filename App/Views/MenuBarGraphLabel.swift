import SwiftUI

///	The menu bar extra's label, and the one place the menu bar's monitor is read: the graph, rendered to an image on
///	every sample and shown as a template image.
///
///	An image rather than the `Canvas` itself because a `MenuBarExtra`'s label is realized as the status item's button
///	image: a `Canvas` given as the label drew nothing and left the item 16 pt wide with no image at all, while an
///	`Image` becomes the button's image and is replaced whenever this body is re-evaluated (observed 2026-09-24;
///	Design.md, D24 and D.6). Template rendering hands the system an image of black and clear to color for the menu bar,
///	as Apple's guidelines ask, so Light, Dark, and the selected item need no code here. The image is decorative: the
///	graph carries no accessibility, as the window's does not. Design.md, sections 2.4, 5.2, and 5.13.
struct MenuBarGraphLabel: View {

	///	The menu bar's own sampler, owned by the app.
	let monitor: LoadMonitor

	///	The menu bar graph's period, as the settings window stores it; the monitor persists nothing.
	@AppStorage(DefaultsKey.menuBarPeriodSeconds) private var periodSeconds = SamplingPeriod.default.seconds

	///	The menu bar graph's history length in samples, likewise.
	@AppStorage(DefaultsKey.menuBarHistorySamples) private var historySamples = MenuBarHistoryLength.default.value

	///	The width of one CPU's graph, likewise. It bears on the drawing alone; the monitor never hears of it.
	@AppStorage(DefaultsKey.menuBarGraphWidth) private var graphWidthPoints = GraphWidth.default.value

	///	The display's scale, so that the rendered image has a pixel per device pixel.
	@Environment(\.displayScale) private var displayScale

	var body: some View {
		let graphWidth = GraphWidth(value: graphWidthPoints) ?? .default
		let renderer = ImageRenderer(content: MenuBarGraph(histories: monitor.state.histories, graphWidth: graphWidth.points))
		renderer.scale = displayScale
		return Group {
			if let image = renderer.cgImage {
				Image(decorative: image, scale: displayScale)
					.renderingMode(.template)
			} else {
				//	Nothing to render: the renderer declined. The item keeps its symbol rather than vanishing.
				Image(systemName: "cpu")
			}
		}

		//	Sampling for the menu bar runs from the label's first appearance for the life of the process (Design.md,
		//	D25): the extra is always inserted, and the app quits if the user removes it with no window showing.
		.onAppear {
			monitor.resume()
		}

		//	A settings change reaches the monitor from here, the way the window's reach its monitor from the window's
		//	root view. The two are independent: the period is the rate the samples arrive at, and the history length is
		//	how many of them the graph holds (Design.md, D32).
		.onChange(of: periodSeconds) {
			applyPeriod()
		}
		.onChange(of: historySamples) {
			monitor.setSampleCount((MenuBarHistoryLength(value: historySamples) ?? .default).sampleCount)
		}
	}

	///	Gives the monitor the stored period, if it differs. Setting an equal period would still restart the loop, so it
	///	is compared first.
	private func applyPeriod() {
		let period = SamplingPeriod(seconds: periodSeconds) ?? .default
		if monitor.period != period {
			monitor.period = period
		}
	}

}
