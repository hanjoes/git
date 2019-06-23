#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import SwiftPawn

/// Common git functionalities.
public struct SwiftGit {
    
    private static let BufferSize = 4096

    private static var cwd: String {
        var buffer = [Int8](repeating: 0, count: BufferSize)
        return String(cString: getcwd(&buffer, BufferSize))
    }

    // MARK: Probing

    /// Check whether the path is pointing to a git repository.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __yes__ indicates whether there is a repository
    ///     * __err__ contains error message
    public static func repository(at path: String) -> (yes: Bool, err: String) {
        guard isDir(path) else {
            return (false, "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let args = ["git", "status"]
            do {
                let (status, _, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (false, getErrorMessage(args, err))
                }
                return (status == 0, err)
            } catch {
                return (false, getErrorMessage(args, error))
            }
        }
    }

    /// Find all remotes at _path_.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __all__ a list of strings of all remotes
    ///     * __err__ contains error message
    public static func remotes(at path: String) -> (all: [String], err: String) {
        guard isDir(path) else {
            return ([], "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let args = ["git", "remote"]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return ([], getErrorMessage(args, err))
                }
                return (out.split(separator: "\n").filter { !$0.isEmpty }.map { String($0) }, "")
            } catch {
                return ([], getErrorMessage(args, error))
            }
        }
    }

    /// Check if a directory pointed by _path_ is a modified git repository.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __yes__ indicates whether the path points to a modified git repository
    ///     * __err__ contains error message
    public static func modified(at path: String) -> (yes: Bool, err: String) {
        guard isDir(path) else {
            return (false, "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let args = ["git", "status", "--porcelain"]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (false, err)
                }
                return (out.split(separator: "\n").filter { $0.split(separator: " ")[0].contains("M") }.count > 0, err)
            } catch {
                return (false, getErrorMessage(args, error))
            }
        }
    }

    /// Compare two (commits, branches, etc.) to see how many the left left-hand-side is ahead of the right-hand-side.
    ///
    /// - Parameters:
    ///   - lhs: left-hand-side commit, branch
    ///   - rhs: right-hand-side commit, branch
    ///   - path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __ret__ return status, non-zero indicates error
    ///     * __offset__ an integer indicating the difference, positive means lhs is ahead of rhs and vice versa.
    ///     * __err__ contains error message
    public static func compare(_ lhs: String, _ rhs: String, at path: String) -> (ret: Int, offset: Int, err: String) {
        guard isDir(path) else {
            return (-1, 0, "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            var args = [String]()
            do {
                args = ["git", "rev-list", "\(rhs)..\(lhs)"]
                var (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (-1, 0, getErrorMessage(args, err))
                }

                let l2r = out.trimmed().split(separator: "\n").count
                if l2r > 0 {
                    return (0, l2r, err)
                }

                args = ["git", "rev-list", "\(lhs)..\(rhs)"]
                (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (-1, 0, getErrorMessage(args, err))
                }

                let r2l = out.trimmed().split(separator: "\n").count
                if r2l > 0 {
                    return (0, -r2l, err)
                }
                return (0, 0, err)
            } catch {
                return (-1, 0, getErrorMessage(args, error))
            }
        }
    }

    /// Get the branch name of a git repository pointed to by _path_.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __name__ an optional of string indicating the branch name.
    ///     * __err__ contains error message
    public static func branch(at path: String) -> (name: String?, err: String) {
        guard isDir(path) else {
            return (nil, "Error: \(path) is not a directory")
        }
        // TODO: support detached?
        return run(inDir: path) {
            let args = ["git", "symbolic-ref", "HEAD"]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (nil, err)
                }

                guard out.starts(with: "refs/heads") else {
                    return (nil, "Error: output \(out) does not start with refs/heads.")
                }

                let elements = out.trimmed().split(separator: "/")
                guard elements.count == 3 else {
                    return (nil, "Error: erraneous output \(out)")
                }

                return (String(elements[2]), err)
            } catch {
                return (nil, getErrorMessage(args, error))
            }
        }
    }

    /// Find the remote branch name tracked by _branch_ at _path_.
    ///
    /// - Parameters:
    ///   - path: "/" separated string to a location in file system
    ///   - branch: local branch name
    /// - Returns: a tuple
    ///     * __remote__ an optional of string indicating the remote branch name
    ///     * __err__ contains error message
    public static func tracked(at path: String, branch: String) -> (remote: String?, err: String) {
        guard isDir(path) else {
            return (nil, "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let ret = repository(at: path)
            guard ret.yes else {
                return (nil, ret.err)
            }

            let args = ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "\(branch)@{u}"]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (nil, getErrorMessage(args, err))
                }

                let remote = out.trimmed()
                return (remote, err)
            } catch {
                return (nil, getErrorMessage(args, error))
            }
        }
    }

    // MARK: Side-effect

    /// Pull the latest changes for a remote branch tracked by _branch_ for repository at _path_.
    ///
    /// - Parameters:
    ///   - path: "/" separated string to a location in file system
    ///   - branch: a branch name that has a tracked remote branch
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func pull(at path: String, branch: String) -> (ret: Int, out: String, err: String) {
        guard isDir(path) else {
            return (-1, "", "Error: \(path) is not a directory")
        }
        let (_tracked, err) = tracked(at: path, branch: branch)
        guard let trackedRemote = _tracked else {
            return (-1, "", "Error: could not find tracked remote, \(err)")
        }

        guard trackedRemote.contains("/") else {
            return (-1, "", "Error: erroneous remote format \(trackedRemote)")
        }

        let elements = trackedRemote.split(separator: "/").map { String($0) }
        let numElements = elements.count
        guard numElements == 2 else {
            return (-1, "", "Error: expect 2 elements after splitting, got \(elements)")
        }

        let args = ["git", "-C", path, "pull", elements[0], branch]
        do {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
            guard status != 0 else {
                return (-1, out, getErrorMessage(args, err))
            }
            return (0, out, err)
        } catch {
            return (-1, "", getErrorMessage(args, error))
        }
    }

    /// Download objects and refs from all remotes tracked at _path_.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func fetch(at path: String) -> (ret: Int, out: String, err: String) {
        guard isDir(path) else {
            return (-1, "", "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let args = ["git", "fetch", "--all"]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (-1, out, getErrorMessage(args, err))
                }
                return (0, out, err)
            } catch {
                return (-1, "", getErrorMessage(args, error))
            }
        }
    }

    /// Clone a repository into _path_ and checkout _branch_.
    ///
    /// - Parameters:
    ///   - url: url pointing to a git repository
    ///   - path: "/" separated string to a location in file system
    ///   - branch: the branch we want to check out
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func clone(from url: String, into path: String, branch _: String = "master") -> (ret: Int, out: String, err: String) {
        guard isDir(path) else {
            return (-1, "", "Error: \(path) is not a directory")
        }
        let args = ["git", "clone", url, path]
        do {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
            guard status == 0 else {
                return (-1, out, getErrorMessage(args, err))
            }
            return (0, out, err)
        } catch {
            return (-1, "", getErrorMessage(args, error))
        }
    }

    /// Initialize a git repository at _path_.
    ///
    /// - Parameter path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func initialize(at path: String) -> (ret: Int, out: String, err: String) {
        guard isDir(path) else {
            return (-1, "", "Error: \(path) is not a directory")
        }
        let args = ["git", "init", path]
        do {
            let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
            guard status == 0 else {
                return (-1, out, getErrorMessage(args, err))
            }
            return (0, out, err)
        } catch {
            return (-1, "", getErrorMessage(args, error))
        }
    }

    /// Commit staged changes in the git repository at _path_ with _message_.
    ///
    /// - Parameters:
    ///   - path: "/" separated string to a location in file system
    ///   - msg: commit message
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func commit(at path: String, message msg: String) -> (ret: Int, out: String, err: String) {
        guard isDir(path) else {
            return (-1, "", "Error: \(path) is not a directory")
        }
        return run(inDir: path) {
            let args = ["git", "commit", "-m", "\"\(msg)\""]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (-1, out, getErrorMessage(args, err))
                }
                return (0, out, err)
            } catch {
                return (-1, "", getErrorMessage(args, error))
            }
        }
    }

    /// Stage a specified file/directory at _path_.
    ///
    /// - Parameters:
    ///   - path: "/" separated string to a location in file system
    /// - Returns: a tuple
    ///     * __ret__: returns status, non-zero indicates error
    ///     * __out__: contains output message
    ///     * __err__: contains error message
    @discardableResult
    public static func add(path: String) -> (ret: Int, out: String, err: String) {
        return run(inDir: path) {
            let args = ["git", "add", path]
            do {
                let (status, out, err) = try SwiftPawn.execute(command: "git", arguments: args)
                guard status == 0 else {
                    return (-1, out, getErrorMessage(args, err))
                }
                return (0, out, err)
            } catch {
                return (-1, "", getErrorMessage(args, error))
            }
        }
    }
}

// MARK: - Helpers

extension SwiftGit {
    private static func isDir(_ path: String) -> Bool {
        let size = MemoryLayout<stat>.size
        let pathStat = UnsafeMutablePointer<stat>.allocate(capacity: size)
        defer {
            pathStat.deinitialize(count: size)
            pathStat.deallocate()
        }
        let ret = stat(path, pathStat)
        guard ret == 0 else {
            return false
        }
        return (pathStat.pointee.st_mode & S_IFDIR) != 0
    }

    private static func run<R>(inDir dir: String, f: () throws -> R) rethrows -> R {
        var buffer = [Int8](repeating: 0, count: BufferSize)
        let cwd = String(cString: getcwd(&buffer, BufferSize))
        chdir(dir)
        defer { chdir(cwd) }
        return try f()
    }

    private static func getErrorMessage(_ args: [String], _ err: String) -> String {
        return "Error: Execution of \(args.joined(separator: " ")) failed with message \(err)"
    }

    private static func getErrorMessage(_ args: [String], _ error: Error) -> String {
        return "Error: Execution of \(args.joined(separator: " ")) failed with error \(error)"
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
