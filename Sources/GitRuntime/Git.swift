import Foundation

/// Simple Git functionalities.
public struct Git {
    
    private static let GIT = "/usr/bin/git"
    
    private let fileManager = FileManager.default
    
    public init() {
    }
    
    /// Synchronize the repository.
    ///
    /// - Parameters:
    ///   - repo: path to the repository
    ///   - localFolder: local folder
    /// - Throws: error
    public func sync(from repo: String, to localFolder: String, withBranch branch: String = "master") throws {
        if containsRepo(at: repo) {
            try updateRepo(at: repo, withBranch: branch)
        }
        else {
            try cloneRepo(from: repo, at: localFolder, withBranch: branch)
        }
    }
    
    /// Check whether the specified path contains a git repo.
    ///
    /// - Parameter path: the path to check
    /// - Returns: boolean indicating whether a repo exists
    public func containsRepo(at path: String) -> Bool {
        let (status, _, _) = execute(command: Git.GIT, withArguments: ["status"], at: path)
        return status == 0
    }
    
    /// Update the git repo at path.
    /// This will update the first found remote.
    ///
    /// - Parameters:
    ///   - path: path to the repo we want to update
    ///   - branch: branch name
    /// - Throws: error
    public func updateRepo(at path: String, withBranch branch: String = "master") throws {
        guard containsRepo(at: path) else {
            throw GitError.noRepo("Cannot find repository at: \(path) for branch: \(branch)")
        }
        
        // update the specified branch
        let remotes = try findRemotes(at: path)
        guard remotes.count > 0 else {
            throw GitError.noRemote("0 remote found at path: \(path)")
        }
        
        try fastFailingExecute(command: Git.GIT, withArguments: ["pull", remotes[0], branch])
    }
    
    /// Clones a user specified repository to folder
    ///
    /// - Parameters:
    ///   - repo: url to repository
    ///   - path: local folder to hold the repository
    ///   - branch: branch to checkout, default to master
    /// - Throws: error
    public func cloneRepo(from repo: String, at path: String, withBranch branch: String = "master") throws {
        try fastFailingExecute(command: Git.GIT, withArguments: ["clone", repo, path], at: path)
    }

    /// Find all remotes in the repository
    ///
    /// - Parameter path: path where repository resides
    /// - Returns: a list of remote names
    /// - Throws: error
    public func findRemotes(at path: String) throws -> [String] {
        guard containsRepo(at: path) else {
            throw GitError.noRepo("Cannot find repository at: \(path)")
        }
        
        let (out, _) = try fastFailingExecute(command: Git.GIT, withArguments: ["remote"], at: path)
        return out.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
