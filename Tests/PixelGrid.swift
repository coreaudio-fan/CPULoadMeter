import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

///	A view rendered to pixels. `ImageRenderer` renders it at a fixed size and scale; the result is redrawn into a
///	cleared RGBA8 premultiplied sRGB context of this type's own, so that the memory layout is known rather than assumed,
///	and only the alpha channel is exposed, with row 0 at the top. The reference alpha of a lit pixel is measured, never
///	assumed, because the label color's alpha is not documented.
@MainActor struct PixelGrid {

	///	The width in pixels.
	let width: Int

	///	The height in pixels.
	let height: Int

	///	The rendered image, for attaching.
	let image: CGImage

	///	Every pixel's alpha, row-major, row 0 at the top.
	private let alphas: [UInt8]

	///	Renders `content` at `width` by `height` points at `scale`, or fails if the renderer or the context does.
	init?<Content: View>(of content: Content, width: CGFloat, height: CGFloat, scale: CGFloat) {
		let renderer = ImageRenderer(content: content.frame(width: width, height: height))
		renderer.scale = scale
		let pixelWidth = Int((width * scale).rounded())
		let pixelHeight = Int((height * scale).rounded())
		guard let rendered = renderer.cgImage, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
			return nil
		}
		let bounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
		context.clear(bounds)
		context.draw(rendered, in: bounds)
		guard let data = context.data, let image = context.makeImage() else {
			return nil
		}
		let bytes = data.bindMemory(to: UInt8.self, capacity: pixelWidth * pixelHeight * 4)
		self.width = pixelWidth
		self.height = pixelHeight
		self.image = image
		alphas = (0..<(pixelWidth * pixelHeight)).map { bytes[($0 * 4) + 3] }
	}

	///	The alpha of one pixel; row 0 is the top row.
	func alpha(column: Int, row: Int) -> UInt8 {
		alphas[(row * width) + column]
	}

	///	The image as PNG data, for attaching to the test's results.
	var png: Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, image, nil)
		return CGImageDestinationFinalize(destination) ? (data as Data) : nil
	}

}
