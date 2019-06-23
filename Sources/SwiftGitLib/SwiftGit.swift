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

    public static func isRepo(at path: String) -> (confirmed: Bool, err: String) {
        return run(inDir: path) {
            let args = ["git", "status"]
            guard let (status, _, _) = try? SwiftPawn.execute(command: "git", arguments: args) else {
                return (false, "Error: execution of \(args) failed.")
            }
            return (status == 0, "")
        }
    }

    public static func updateRepo(at path: String, branch: String) -> (ret: Int, out: String, err: String) {
        let (remotes, _) = findRemotes(at: path)
        guard remotes.count > 0 else {
            return (-1, "", "Error: no remote found at path: \(path), branch: \(branch)")
        }

        let args = ["git", "-C", path, "pull", remotes[0], branch]
        do {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
            if status != 0 {
                return (-1, out, "Error: execution of \(args) failed with message: \(err)")
            }
            return (0, out, err)
        } catch {
            return (-1, "", "Error: execution of \(args) failed \(error)")
        }
    }

    public static func findTrackingRemote(at path: String, branch: String) -> String? {
        return run(inDir: path) {
            guard isRepo(at: path).confirmed else {
                return nil
            }

            do {
                let (status, out, _)
                    = try SwiftPawn.execute(command: "git", arguments: ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "\(branch)@{u}"])
                if status != 0 {
                    return nil
                }

                let remote = out.trimmed()
                return remote
            } catch {
                return nil
            }
        }
    }

    public static func fetchRepo(at path: String) throws {
        try run(inDir: path) {
            let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "fetch", "--all"])
            if status != 0 {
                throw SwiftGitError.opFailed("Fetch failed with message: \n\(err)")
            }
        }
    }

    public static func cloneRepo(from repo: String, at path: String, withBranch _: String = "master") throws {
        _ = try SwiftPawn.execute(command: "git", arguments: ["git", "clone", repo, path])
    }

    public static func findRemotes(at path: String) -> (remotes: [String], err: String) {
        return try! run(inDir: path) {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "remote"])
            if status != 0 {
                throw SwiftGitError.opFailed("Commit failed with message: \n\(err)")
            }
            return (out.split(separator: "\n").filter { !$0.isEmpty }.map { String($0) }, "")
        }
    }

    public static func initialize(inDir dir: String) throws {
        _ = try SwiftPawn.execute(command: "git", arguments: ["git", "init", dir])
    }

    public static func commit(at path: String, withMessage msg: String) throws {
        try run(inDir: path) {
            let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "commit", "-m", "\"\(msg)\""])
            if status != 0 {
                throw SwiftGitError.opFailed("Commit failed with message: \n\(err)")
            }
        }
    }

    public static func add(_: String, at path: String) throws {
        try run(inDir: path) {
            let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "add", path])
            if status != 0 {
                throw SwiftGitError
                    .opFailed("Staging \(path) failed with message: \n\(err)")
            }
        }
    }

    public static func isModified(at path: String) throws -> Bool {
        return try run(inDir: path) {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "status", "--porcelain"])
            if status != 0 {
                throw SwiftGitError
                    .opFailed("Staging \(path) failed with message: \n\(err)")
            }
            return out
                .split(separator: "\n")
                .filter { $0.split(separator: " ")[0].contains("M") }.count > 0
        }
    }

    public static func branchName(at path: String) throws -> String? {
        // TODO: support detached?
        return try run(inDir: path) {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "symbolic-ref", "HEAD"])
            if status != 0 {
                throw SwiftGitError
                    .opFailed("Staging \(path) failed with message: \n\(err)")
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

    public static func compare(_ lhs: String, _ rhs: String,
                               at path: String) throws -> Int {
        return try run(inDir: path) {
            var (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "rev-list", "\(rhs)..\(lhs)"])
            guard status == 0 else {
                throw SwiftGitError
                    .opFailed("git rev-list \(rhs)..\(lhs) failed due to: \(err)")
            }

            let l2r = out.trimmed().split(separator: "\n").count
            if l2r > 0 {
                return l2r
            }

            (status, out, err) = try SwiftPawn.execute(command: "git", arguments: ["git", "rev-list", "\(lhs)..\(rhs)"])
            guard status == 0 else {
                throw SwiftGitError
                    .opFailed("git rev-list \(lhs)..\(rhs) failed due to: \(err)")
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
