//	These tests establish where the test bundle runs: loaded into the app's own process, inside the app's sandbox
//	container. Everything else in this suite leans on that. It is what makes the reader tests a standing proof that the
//	sandbox permits the kernel calls, and what lets @testable import reach the app.
//
//	This project's tests use @testable import, where the sibling projects forbid it. That is a decision, not an
//	oversight: nothing here is published from a module, so the app's own code -- which sees internal declarations -- is
//	the only client there is, and @testable import gives a test exactly that view. See Design.md, B.10.
@testable import CPULoadMeter
import Foundation
import Testing

struct HostingTests {

	@Test func testsRunInsideTheAppsProcess() async throws {
		#expect(Bundle.main.bundleIdentifier == "coreaudio-fan.CPULoadMeter")
	}

	@Test func testsRunInsideTheAppsSandboxContainer() async throws {
		#expect(NSHomeDirectory().hasSuffix("/Library/Containers/coreaudio-fan.CPULoadMeter/Data"))
	}

	//	CPULoadMeterApp is main-actor-isolated through SwiftUI's App protocol, so a test that touches it says so.
	@Test @MainActor func appsInternalDeclarationsAreReachable() async throws {
		#expect(CPULoadMeterApp.mainWindowID == "main")
	}

}
