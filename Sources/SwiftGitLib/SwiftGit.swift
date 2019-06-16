#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

import SwiftPawn

/// Simple Git functionalities.
public struct SwiftGit {
  private static let BufferSize = 4096

  private static var cwd: String {
    var buffer = [Int8](repeating: 0, count: BufferSize)
    return String(cString: getcwd(&buffer, BufferSize))
  }

  public init() {}

  /// Check whether the specified path is a git repository.
  ///
  /// - Parameter path: the path to check
  /// - Returns: boolean indicating whether a repo exists
  public static func isRepo(at path: String) -> Bool {
    return run(inDir: path) {
      guard let (status, _, _) = try? SwiftPawn.execute(command: "git", arguments: ["git", "status"]) else {
        return false
      }
      return (status == 0)
    }
  }

  /// Update the git repo at path.
  /// This will update the first found remote.
  ///
  /// - Parameters:
  ///   - path: path to the repo we want to update
  ///   - branch: branch name
  /// - Throws: error
  public static func updateRepo(at path: String, withBranch branch: String = "master") throws {
    // update the specified branch
    let remotes = try findRemotes(at: path)
    guard remotes.count > 0 else {
      throw SwiftGitError.noRemote("0 remote found at path: \(path)")
    }

    let (status, _, err) = try SwiftPawn.execute(command: "git",
                                                 arguments: ["git", "-C", path, "pull", remotes[0], branch])
    if status != 0 {
      throw SwiftGitError.opFailed("Commit failed with message: \n\(err)")
    }
  }

  public static func fetchRepo(at path: String) throws {
    try run(inDir: path) {
      let (status, _, err) = try SwiftPawn.execute(command: "git",
                                                   arguments: ["git", "fetch", "--all"])
      if status != 0 {
        throw SwiftGitError.opFailed("Fetch failed with message: \n\(err)")
      }
    }
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
    return try run(inDir: path) {
      let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "remote"])
      if status != 0 {
        throw SwiftGitError.opFailed("Commit failed with message: \n\(err)")
      }
      return out.split(separator: "\n").filter { !$0.isEmpty }.map { String($0) }
    }
  }

  public static func initialize(inDir dir: String) throws {
    _ = try SwiftPawn.execute(command: "git", arguments: ["git", "init", dir])
  }

  public static func commit(at path: String, withMessage msg: String) throws {
    try run(inDir: path) {
      let (status, _, err) = try SwiftPawn.execute(command: "git",
                                                   arguments: ["git", "commit", "-m", "\"\(msg)\""])
      if status != 0 {
        throw SwiftGitError.opFailed("Commit failed with message: \n\(err)")
      }
    }
  }

  public static func add(_: String, at path: String) throws {
    try run(inDir: path) {
      let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "add", path])
      if status != 0 {
        throw SwiftGitError.opFailed("Staging \(path) failed with message: \n\(err)")
      }
    }
  }

  public static func isModified(at path: String) throws -> Bool {
    return try run(inDir: path) {
      let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "status", "--porcelain"])
      if status != 0 {
        throw SwiftGitError.opFailed("Staging \(path) failed with message: \n\(err)")
      }
      return out.split(separator: "\n").filter { $0.split(separator: " ")[0].contains("M") }.count > 0
    }
  }

  public static func branchName(at path: String) throws -> String? {
    // TODO: support detached?
    return try run(inDir: path) {
      let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "symbolic-ref", "HEAD"])
      if status != 0 {
        throw SwiftGitError.opFailed("Staging \(path) failed with message: \n\(err)")
      }

      guard out.starts(with: "refs/heads") else {
        return nil
      }

      let elements = out.trimmed().split(separator: "/")
      guard elements.count == 3 else {
        return nil
      }

      return String(elements[2])
    }
  }

  /// Compare two commits and find out the difference.
  ///
  /// When comparing labels, only local branch name is supported.
  ///
  /// - Parameters:
  ///   - lhs: the label/hash indicating one commit that's ahead
  ///   - rhs: the label/hash indicating one commit that's behind
  ///   - path: directory where should be a git repository
  /// - Returns: value indicate how many conmmits _lhs_ is ahead of _rhs_ (can be negative).
  /// - Throws: execution error, or either of the parameter is not a valid commit
  public static func compare(_ lhs: String, _ rhs: String, at path: String) throws -> Int {
    return try run(inDir: path) {
      var (status, out, err) = try SwiftPawn.execute(command: "git",
                                                     arguments: ["git", "rev-list", "\(rhs)..\(lhs)"])
      guard status == 0 else {
        throw SwiftGitError.opFailed("git rev-list \(rhs)..\(lhs) failed due to: \(err)")
      }

      let l2r = out.trimmed().split(separator: "\n").count
      if l2r > 0 {
        return l2r
      }

      (status, out, err) = try SwiftPawn.execute(command: "git",
                                                 arguments: ["git", "rev-list", "\(lhs)..\(rhs)"])
      guard status == 0 else {
        throw SwiftGitError.opFailed("git rev-list \(lhs)..\(rhs) failed due to: \(err)")
      }

      let r2l = out.trimmed().split(separator: "\n").count
      if r2l > 0 {
        return -r2l
      }
      return r2l
    }
  }

  private static func run<R>(inDir dir: String, f: () throws -> R) rethrows -> R {
    var buffer = [Int8](repeating: 0, count: BufferSize)
    let cwd = String(cString: getcwd(&buffer, BufferSize))
    chdir(dir)
    defer { chdir(cwd) }
    return try f()
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
