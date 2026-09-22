import SwiftUI

///	A separator one device pixel tall, in the separator color: the least vertical space that still tells twenty-four
///	unlabelled graphs apart. Design.md, sections 2.7 and 2.13, and B.14.
struct Hairline: View {

	///	The size of one device pixel in points: 1 at 1x, 0.5 at 2x.
	@Environment(\.pixelLength) private var pixelLength

	var body: some View {
		Rectangle()
			.fill(.separator)
			.frame(height: pixelLength)
	}

}
