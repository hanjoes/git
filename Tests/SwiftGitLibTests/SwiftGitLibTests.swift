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
        XCTAssertTrue(Git.isRepo(at: currentTemp))
    }

    func testisRepo() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            XCTAssertFalse(Git.isRepo(at: currentTemp))
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
    
    func testCompare() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            try Git.cloneRepo(from: testRepo, at: currentTemp)
            XCTAssertEqual(-4, try Git.compare("50685d9342139e", "8925e720d508cca3"))
            XCTAssertEqual(1, try Git.compare("ef0421b", "f1749a1"))
            XCTAssertEqual(3, try Git.compare("origin/noremove", "b589c3d"))
        }
    }
    
    
    func testBranchName() throws {
        let currentTemp = try makeTempDirectory()
        try run(inTmpDir: currentTemp) {
            try Git.initialize(inDir: currentTemp)
            _ = try SwiftPawn.execute(command: "touch", arguments: ["touch", "abc"])
            let name = try Git.branchName()
            XCTAssertEqual("master", name!)
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
