///	A sleep the test controls. Each call records the deadline it was asked for and waits until the test releases it, or
///	until the sleeping task is cancelled, which is what a period change does to the old loop and what the clock's own
///	sleep would throw for.
@MainActor final class ScriptedSleep {

	///	Every deadline the monitor has asked to sleep until, oldest first.
	private(set) var deadlines: [ContinuousClock.Instant] = []

	///	The sleeps not yet released, oldest first.
	private var waiting: [CheckedContinuation<Void, any Error>] = []

	///	The monitor's sleep.
	func sleep(until deadline: ContinuousClock.Instant) async throws {
		deadlines.append(deadline)
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				waiting.append(continuation)
			}
		} onCancel: {
			Task { @MainActor in
				self.cancelAll()
			}
		}
	}

	///	Ends the oldest sleep, letting the loop take its next sample.
	func release() {
		if !(waiting.isEmpty) {
			waiting.removeFirst().resume()
		}
	}

	///	Yields to the loop until it has asked for `count` deadlines in all. A test's time limit bounds the wait.
	func awaitDeadlines(_ count: Int) async {
		while deadlines.count < count {
			await Task.yield()
		}
	}

	///	Ends every pending sleep by throwing cancellation, as the clock's sleep does when its task is cancelled.
	private func cancelAll() {
		let cancelled = waiting
		waiting = []
		for continuation in cancelled {
			continuation.resume(throwing: CancellationError())
		}
	}

}
