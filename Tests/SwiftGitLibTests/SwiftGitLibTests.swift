@testable import SwiftGitLib
@testable import SwiftPawn
import XCTest
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

private struct TC {
    static let TestRepo = "https://github.com/hanjoes/swift-git.git"
}

class SwiftGitLibTests: XCTestCase {
    func testCloneAndCheck() {
        let currentTemp = makeTempDirectory()
        SwiftGit.clone(from: TC.TestRepo, into: currentTemp)
        XCTAssertTrue(SwiftGit.repository(at: currentTemp).yes)
    }

    func testFindRemoteButNoRepo() {
        let currentTemp = makeTempDirectory()
        XCTAssertEqual(0, SwiftGit.remotes(at: currentTemp).all.count)
    }

    func testFindRemote() {
        let currentTemp = makeTempDirectory()
        SwiftGit.clone(from: TC.TestRepo, into: currentTemp)
        let (remotes, _) = SwiftGit.remotes(at: currentTemp)
        XCTAssertGreaterThanOrEqual(1, remotes.count)
        XCTAssertEqual("origin", remotes.first!)
    }

    func testInitialize() {
        let currentTemp = makeTempDirectory()
        SwiftGit.initialize(at: currentTemp)
        XCTAssertTrue(SwiftGit.repository(at: currentTemp).yes)
    }

    func testCommit() {
        let currentTemp = makeTempDirectory()
        SwiftGit.initialize(at: currentTemp)
        chdir(currentTemp)
        _ = try! SwiftPawn.execute(command: "touch", arguments: ["touch", "abc"])
        SwiftGit.add(path: "./abc")
        SwiftGit.commit(at: currentTemp, message: "test")
    }

    func testModified() {
        let currentTemp = makeTempDirectory()
        SwiftGit.initialize(at: currentTemp)
        chdir(currentTemp)
        _ = try! SwiftPawn.execute(command: "touch", arguments: ["touch", "abc"])
        SwiftGit.add(path: "./abc")
        SwiftGit.commit(at: currentTemp, message: "test")
        let fd = fopen("./abc", "w")
        defer { fclose(fd) }
        fwrite("test", 1, 4, fd)
        fflush(fd)
        XCTAssertTrue(SwiftGit.modified(at: currentTemp).yes)
    }

    func testCompare() {
        let currentTemp = makeTempDirectory()
        SwiftGit.clone(from: TC.TestRepo, into: currentTemp)
        XCTAssertEqual(-4, SwiftGit.compare("50685d9342139e", "8925e720d508cca3", at: currentTemp).offset)
        XCTAssertEqual(1, SwiftGit.compare("ef0421b", "f1749a1", at: currentTemp).offset)
        XCTAssertEqual(2, SwiftGit.compare("origin/noremove", "b589c3d", at: currentTemp).offset)
    }

    func testGetBranchName() {
        let currentTemp = makeTempDirectory()
        SwiftGit.initialize(at: currentTemp)
        let name = SwiftGit.branch(at: currentTemp).name
        XCTAssertEqual("master", name!)
    }

    func testFindTracked() {
        let currentTemp = makeTempDirectory()
        SwiftGit.clone(from: TC.TestRepo, into: currentTemp)
        let track = SwiftGit.tracked(at: currentTemp, branch: "master").remote
        XCTAssertTrue(track!.contains("/master"))
        let untracked = SwiftGit.tracked(at: currentTemp, branch: "dev").remote
        XCTAssertNil(untracked)
    }

    private func makeTempDirectory() -> String {
        var g = SystemRandomNumberGenerator()
        let tempDirectoryPath = "/tmp/SwiftGitLibTests-\(g.next())/"
        mkdir(tempDirectoryPath, S_IRWXU)
        return tempDirectoryPath
    }

    static var allTests = [
        // ("testCloneAndCheck", testCloneAndCheck),
        ("testFindRemoteButNoRepo", testFindRemoteButNoRepo),
        ("testFindRemote", testFindRemote),
        ("testInitialize", testInitialize),
        ("testCommit", testCommit),
        ("testModified", testModified),
        ("testCompare", testCompare),
        ("testGetBranchName", testGetBranchName),
        ("testFindTracked", testFindTracked),
    ]
}
