///	What the two whole-second settings share, which is all their control needs: the value in seconds, the presets the
///	pop-up offers, and the parse that decides what typed text commits. A conforming type is made only through failable
///	initializers, so that the parse's `nil` is the reject-and-revert rule. Design.md, sections 2.11, 2.12, and 5.9.
protocol WholeSeconds: Sendable, Equatable {

	///	The values the control offers as presets.
	static var presets: [Self] { get }

	///	The value in whole seconds.
	var seconds: Int { get }

	///	A value parsed from what the user typed, or `nil` for anything that is not a whole number in range.
	init?(text: String)

}
