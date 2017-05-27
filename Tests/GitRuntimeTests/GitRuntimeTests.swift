import XCTest
@testable import GitRuntime

class GitRuntimeTests: XCTestCase {
    
    private let git = Git()
    
    private let fileManager = FileManager.default
    
    private let testRepo = "https://github.com/hanjoes/git.git"
    
    func testCloneRepo() throws {
        let currentTemp = try makeTempDirectory()
        try git.cloneRepo(from: testRepo, at: currentTemp)
        XCTAssertTrue(git.containsRepo(at: currentTemp))
    }
    
    func testContainsRepo() throws {
        let currentTemp = try makeTempDirectory()
        XCTAssertFalse(git.containsRepo(at: currentTemp))
    }
    
    func testFindRemoteButNoRepo() throws {
        let currentTemp = try makeTempDirectory()
        XCTAssertThrowsError(try git.findRemotes(at: currentTemp))
    }
    
    func testFindRemote() throws {
        let currentTemp = try makeTempDirectory()
        try git.cloneRepo(from: testRepo, at: currentTemp)
        let remotes = try git.findRemotes(at: currentTemp)
        XCTAssertGreaterThanOrEqual(1, remotes.count)
        XCTAssertEqual("origin", remotes.first!)
    }

    private func makeTempDirectory() throws -> String {
        let nano = DispatchTime.now().uptimeNanoseconds
        let tempDirectoryPath = "/tmp/GitRuntimeTests-\(nano)/"
        try fileManager.createDirectory(atPath: tempDirectoryPath, withIntermediateDirectories: false, attributes: nil)
        return tempDirectoryPath
    }
}
