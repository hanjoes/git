import SwiftPawn
import Darwin

/// Simple Git functionalities.
public struct Git {
    
    private static let BufferSize = 4096
    
    private static var cwd: String {
        var buffer = [Int8](repeating: 0, count: BufferSize)
        return String(cString: getcwd(&buffer, BufferSize))
    }

    public init() {}

    /// Synchronize the repository.
    ///
    /// - Parameters:
    ///   - repo: path to the repository
    ///   - localFolder: local folder
    /// - Throws: error
    public static func sync(from repo: String, to localFolder: String, withBranch branch: String = "master") throws {
        if isRepo(at: localFolder) {
            try updateRepo(at: localFolder, withBranch: branch)
        } else {
            try cloneRepo(from: repo, at: localFolder, withBranch: branch)
        }
    }

    /// Check whether the specified path is a git repository.
    ///
    /// - Parameter path: the path to check
    /// - Returns: boolean indicating whether a repo exists
    public static func isRepo(at _: String) -> Bool {
        guard let (status, _, _) = try? SwiftPawn.execute(command: "git", arguments: ["git", "status"]) else {
            return false
        }
        return status == 0
    }

    /// Update the git repo at path.
    /// This will update the first found remote.
    ///
    /// - Parameters:
    ///   - path: path to the repo we want to update
    ///   - branch: branch name
    /// - Throws: error
    public static func updateRepo(at path: String, withBranch branch: String = "master") throws {
        guard isRepo(at: path) else {
            throw GitError.noRepo("Cannot find repository at: \(path) for branch: \(branch)")
        }

        // update the specified branch
        let remotes = try findRemotes(at: path)
        guard remotes.count > 0 else {
            throw GitError.noRemote("0 remote found at path: \(path)")
        }

        _ = try SwiftPawn.execute(command: "git", arguments: ["git", "-C", path, "pull", remotes[0], branch])
    }

    /// Clones a user specified repository to folder
    ///
    /// - Parameters:
    ///   - repo: url to repository
    ///   - path: local folder to hold the repository
    ///   - branch: branch to checkout, default to master
    /// - Throws: error
    public static func cloneRepo(from repo: String, at path: String, withBranch _: String = "master") throws {
        _ = try SwiftPawn.execute(command: "git", arguments: ["git", "clone", repo, path])
    }

    /// Find all remotes in the repository
    ///
    /// - Parameter path: path where repository resides
    /// - Returns: a list of remote names
    /// - Throws: error
    public static func findRemotes(at path: String) throws -> [String] {
        guard isRepo(at: path) else {
            throw GitError.noRepo("Cannot find repository at: \(path)")
        }

        let (_, out, _) = try SwiftPawn.execute(command: "git", arguments: ["git", "remote"])
        return out.split(separator: "\n").filter { !$0.isEmpty }.map { String($0) }
    }
    
    public static func initialize(inDir dir: String) throws {
        _ = try SwiftPawn.execute(command: "git", arguments: ["git", "init", dir])
    }
    
    public static func commit(withMessage msg: String) throws {
        guard isRepo(at: cwd) else {
            throw GitError.noRepo("Cannot find repository at: \(cwd)")
        }
        
        let (status, _, err) = try SwiftPawn.execute(command: "git",
                                                     arguments: ["git", "commit", "-m", "\"\(msg)\""])
        if status != 0 {
            throw GitError.opFailed("Commit failed with message: \n\(err)")
        }
    }
    
    public static func add(path: String) throws {
        let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "add", path])
        if status != 0 {
            throw GitError.opFailed("Staging \(path) failed with message: \n\(err)")
        }
    }
    
    public static func isModified(_ path: String) throws -> Bool {
        guard isRepo(at: path) else {
            throw GitError.noRepo("Cannot find repository at: \(path)")
        }
        
        let (_, out, _) = try SwiftPawn.execute(command: "git", arguments: ["git", "status", "--porcelain"])
        return out.split(separator: "\n").filter { $0.split(separator: " ")[0].contains("M") }.count > 0
    }
    
    public static func branchName() throws -> String? {
        guard isRepo(at: cwd) else {
            return nil
        }
        
        let (_, out, _) = try SwiftPawn.execute(command: "git", arguments: ["git", "symbolic-ref", "HEAD"])
        guard out.starts(with: "refs/heads") else {
            return nil
        }
        
        let elements = out.trimmed().split(separator: "/")
        guard elements.count == 3 else {
            return nil
        }
        
        return String(elements[2])
    }

    /// Compare two commits and find out the difference.
    ///
    /// When comparing labels, only local branch name is supported.
    ///
    /// - Parameters:
    ///   - lhs: the label/hash indicating one commit that's ahead
    ///   - rhs: the label/hash indicating one commit that's behind
    /// - Returns: value indicate how many conmmits _lhs_ is ahead of _rhs_ (can be negative).
    /// - Throws: execution error, or either of the parameter is not a valid commit
    public static func compare(_ lhs: String, _ rhs: String) throws -> Int {
        var (status, out, err) = try SwiftPawn.execute(command: "git",
                                                       arguments: ["git", "rev-list", "\(rhs)..\(lhs)"])
        guard status == 0 else {
            throw GitError.opFailed("git rev-list \(rhs)..\(lhs) failed due to: \(err)")
        }
        
        let l2r = out.trimmed().split(separator: "\n").count
        if l2r > 0 {
            return l2r
        }
        
        (status, out, err) = try SwiftPawn.execute(command: "git",
                                                   arguments: ["git", "rev-list", "\(lhs)..\(rhs)"])
        guard status == 0 else {
            throw GitError.opFailed("git rev-list \(lhs)..\(rhs) failed due to: \(err)")
        }
        
        let r2l = out.trimmed().split(separator: "\n").count
        if r2l > 0 {
            return -r2l
        }
        return r2l
    }
}

// MARK: -

private extension String {
    func trimmed() -> String {
        var result = self
        while result.last?.isWhitespace == true {
            result = String(result.dropLast())
        }
        
        while result.first?.isWhitespace == true {
            result = String(result.dropFirst())
        }
        
        return result
    }
}
