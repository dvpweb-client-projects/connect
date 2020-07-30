import Foundation

public class ProcessLauncher {
    public init() {}
    public func runShellScript(script: URL, in folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-o", "errexit", script.path]
        process.currentDirectoryURL = folder
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != kOSReturnSuccess {
            var message: String?
            if let data = try errorPipe.fileHandleForReading.readToEnd() {
                message = String(data: data, encoding: .utf8)
            }
            throw PresentableError.installation(status: process.terminationStatus, message: message)
        }
    }
}
