@testable import SwiftGitLib
@testable import SwiftPawn
import XCTest
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

class GitRuntimeTests: XCTestCase {
    private let testRepo = "https://github.com/hanjoes/git.git"

    func testCloneRepo() throws {
        let currentTemp = try makeTempDirectory()
        do {
            try Git.cloneRepo(from: testRepo, at: currentTemp)
        } catch {
            print(error)
        }
        XCTAssertTrue(Git.containsRepo(at: currentTemp))
    }

    func testContainsRepo() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            XCTAssertFalse(Git.containsRepo(at: currentTemp))
        }
    }

    func testFindRemoteButNoRepo() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            XCTAssertThrowsError(try Git.findRemotes(at: currentTemp))
        }
    }

    func testFindRemote() throws {
        let currentTemp = try makeTempDirectory()
        try Git.cloneRepo(from: testRepo, at: currentTemp)
        let remotes = try Git.findRemotes(at: currentTemp)
        XCTAssertGreaterThanOrEqual(1, remotes.count)
        XCTAssertEqual("origin", remotes.first!)
    }
    
    func testInitialize() throws {
        let currentTemp = try makeTempDirectory()
        try Git.initialize(inDir: currentTemp)
    }
    
    func testCommit() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            try Git.initialize(inDir: currentTemp)
            _ = try SwiftPawn.execute(command: "touch", arguments: ["touch", "abc"])
            try Git.add(path: "./abc")
            try Git.commit(withMessage: "test")
        }
    }
    
    func testIsModified() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            try Git.initialize(inDir: currentTemp)
            print(currentTemp)
            _ = try SwiftPawn.execute(command: "touch", arguments: ["touch", "abc"])
            try Git.add(path: "./abc")
            try Git.commit(withMessage: "test")
            let fd = fopen("./abc", "w")
            defer { fclose(fd) }
            fwrite("test", 1, 4, fd)
            fflush(fd)
            XCTAssertTrue(try Git.isModified(currentTemp))
        }
    }

    private func makeTempDirectory() throws -> String {
        var g = SystemRandomNumberGenerator()
        let tempDirectoryPath = "/tmp/GitRuntimeTests-\(g.next())/"
        mkdir(tempDirectoryPath, S_IRWXU)
        return tempDirectoryPath
    }

    private func run(inTmpDir dir: String, f: () throws -> Void) throws {
        var buffer = [Int8](repeating: 0, count: 1024)
        let cwd = String(cString: getcwd(&buffer, 1024))
        chdir(dir)
        try f()
        chdir(cwd)
    }
}
