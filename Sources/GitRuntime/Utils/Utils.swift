import Foundation

/// Simple execution of command
///
/// - Parameters:
///   - command: command to execute
///   - arguments: arguments passed in
///   - dir: working directory
/// - Returns: stdout and stderr
func execute(command: String, withArguments arguments: [String], at dir: String = ".") -> (out: String, err: String) {
    let task = Process()
    task.currentDirectoryPath = dir
    task.launchPath = command
    task.arguments = arguments
    let errPipe = Pipe()
    let outPipe = Pipe()
    task.standardError = errPipe
    task.standardOutput = outPipe
    task.launch()
    
    let err = errPipe.fileHandleForReading.readDataToEndOfFile()
    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
    
    task.waitUntilExit()
    
    let outStr = String(data: out, encoding: .utf8) ?? ""
    let errStr = String(data: err, encoding: .utf8) ?? ""
    return (outStr, errStr)
}

/// Fail fast execution of command
///
/// - Parameters:
///   - command: command to execute
///   - arguments: arguments
///   - dir: working directory
/// - Returns: stdout
/// - Throws: opFailed when stderr is not empty
@discardableResult
func fastFailingExecute(command: String, withArguments arguments: [String], at dir: String = ".") throws -> String {
    let (out, err) = execute(command: command, withArguments: arguments, at: dir)
    if !err.isEmpty {
        fputs(err.cString(using: .utf8), stderr)
        throw GitError.opFailed(err)
    }
    return out
}
