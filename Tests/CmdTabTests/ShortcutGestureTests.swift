import XCTest
@testable import CmdTab

final class ShortcutGestureTests: XCTestCase {
    func testCommandReleaseWithoutTabDoesNotRequestSwitch() {
        var gesture = ShortcutGesture()

        XCTAssertFalse(gesture.commandReleased())
    }

    func testCommandTabReleaseRequestsSwitchOnlyOnce() {
        var gesture = ShortcutGesture()
        gesture.tabPressed(commandHeld: true)

        XCTAssertTrue(gesture.commandReleased())
        XCTAssertFalse(gesture.commandReleased())
    }

    func testTabWithoutCommandDoesNotRequestSwitch() {
        var gesture = ShortcutGesture()
        gesture.tabPressed(commandHeld: false)

        XCTAssertFalse(gesture.commandReleased())
    }
}
