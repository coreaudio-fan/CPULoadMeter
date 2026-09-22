import SwiftUI

///	The LoadViews, one per CPU in CPU ID order from the top, sharing the available height equally with a hairline
///	between neighbours. It measures its own width and reports the step count that width holds, which is the one place
///	the model depends on view geometry, by design. Design.md, sections 2.7, 4.2, and 5.3.
struct LoadStackView: View {

	///	One history per CPU, in CPU ID order.
	let histories: [LoadHistory]

	///	The stroke width every LoadView draws with.
	var lineWidth: CGFloat = 1

	///	Told the step count whenever the width changes: the monitor's `setStepCount`.
	let reportStepCount: @MainActor (Int) -> Void

	///	Whether the stack has appeared. Before it has, SwiftUI lays the window out once at a default size that no one
	///	sees -- 900 points wide here -- and reporting that width would cut a history built while no window was open down
	///	to 900 steps before the placement widened it again with zeros. The report at the placed width arrives after
	///	`onAppear` (observed 2026-09-22; Design.md, D.6), and if one ever did not, nothing would be lost: the monitor's
	///	initial count comes from the same stored width the placement uses.
	@State private var hasAppeared = false

	var body: some View {
		VStack(spacing: 0) {
			ForEach(histories.indices, id: \.self) { cpuIndex in
				if cpuIndex > 0 {
					Hairline()
				}

				//	A canvas is opaque to accessibility, and the index is the one place the CPU's identity survives: the
				//	kernel's array index is its CPU ID.
				LoadView(history: histories[cpuIndex], lineWidth: lineWidth)
					.frame(minHeight: 8, idealHeight: 20, maxHeight: .infinity)
					.accessibilityLabel("CPU \(cpuIndex)")
					.accessibilityValue("\(Self.wholePercent(of: histories[cpuIndex])) percent")
			}
		}
		.onGeometryChange(for: Int.self) { proxy in
			LoadGraph.stepCount(forWidth: proxy.size.width)
		} action: { stepCount in
			if hasAppeared {
				reportStepCount(stepCount)
			}
		}
		.onAppear {
			hasAppeared = true
		}
	}

	///	A history's latest load as a whole percent, for the accessibility value.
	private static func wholePercent(of history: LoadHistory) -> Int {
		Int(((history.loads.last?.total ?? 0) * 100).rounded())
	}

}
