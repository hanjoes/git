import XCTest
@testable import GitRuntime

class UtilsTests: XCTestCase {
    
    func testExecEcho() {
        let (reason, out, err) = execute(command: "/bin/echo", withArguments: ["Hello!"])
        XCTAssertEqual(reason, 0)
        XCTAssertEqual("Hello!\n", out)
        XCTAssertTrue(err.isEmpty)
    }
}
