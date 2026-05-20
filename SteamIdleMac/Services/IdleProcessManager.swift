import Foundation

enum IdleProcessError: LocalizedError {
    case helperNotFound
    case steamNotRunning
    case maxSessionsReached
    case alreadyIdling
    case failedToStart(String)

    var errorDescription: String? {
        switch self {
        case .helperNotFound:
            return "idle-helper binary not found. Rebuild the app."
        case .steamNotRunning:
            return "Steam must be running and you must be signed in."
        case .maxSessionsReached:
            return "Steam allows at most 32 games idling at once."
        case .alreadyIdling:
            return "This game is already idling."
        case .failedToStart(let message):
            return message
        }
    }
}

@MainActor
final class IdleProcessManager: ObservableObject {
    static let maxConcurrent = 32

    @Published private(set) var activeSessions: [ActiveIdleSession] = []

    private var runningProcesses: [UInt64: Process] = [:]
    private let steamRunning = SteamRunningService()
    private let pathService = SteamPathService()

    var activeAppIDs: Set<UInt64> {
        Set(activeSessions.map(\.appid))
    }

    func helperURL() -> URL? {
        if let bundled = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("idle-helper"),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        if let aux = Bundle.main.url(forAuxiliaryExecutable: "idle-helper"),
           FileManager.default.isExecutableFile(atPath: aux.path) {
            return aux
        }

        let devPath = URL(fileURLWithPath: "/Users/george/Documents/SteamIdleMac/idle-helper/target/release/idle-helper")
        if FileManager.default.isExecutableFile(atPath: devPath.path) {
            return devPath
        }
        return nil
    }

    func startIdle(game: Game) throws {
        if !steamRunning.isSteamRunning() {
            throw IdleProcessError.steamNotRunning
        }

        if activeSessions.contains(where: { $0.appid == game.appid }) {
            throw IdleProcessError.alreadyIdling
        }

        if activeSessions.count >= Self.maxConcurrent {
            throw IdleProcessError.maxSessionsReached
        }

        guard let helper = helperURL() else {
            throw IdleProcessError.helperNotFound
        }

        let workDir = helper.deletingLastPathComponent()
        try prepareHelperRuntime(in: workDir, appid: game.appid)

        let process = Process()
        process.executableURL = helper
        process.arguments = ["idle", String(game.appid), game.name]
        process.currentDirectoryURL = workDir
        process.environment = try helperEnvironment(helperDirectory: workDir)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        Thread.sleep(forTimeInterval: 1.0)

        if !process.isRunning {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw IdleProcessError.failedToStart(parseHelperError(output))
        }

        runningProcesses[game.appid] = process
        activeSessions.append(ActiveIdleSession(appid: game.appid, name: game.name, pid: process.processIdentifier))
    }

    func stopIdle(appid: UInt64) {
        if let process = runningProcesses[appid], process.isRunning {
            process.terminate()
        } else if let session = activeSessions.first(where: { $0.appid == appid }) {
            kill(session.pid, SIGTERM)
        }
        runningProcesses.removeValue(forKey: appid)
        activeSessions.removeAll { $0.appid == appid }
    }

    func stopAll() {
        for (_, process) in runningProcesses where process.isRunning {
            process.terminate()
        }
        runningProcesses.removeAll()
        activeSessions.removeAll()
    }

    func cleanupOnQuit() {
        stopAll()
    }

    private func prepareHelperRuntime(in directory: URL, appid: UInt64) throws {
        let fm = FileManager.default
        let appidFile = directory.appendingPathComponent("steam_appid.txt")
        try String(appid).write(to: appidFile, atomically: true, encoding: .utf8)

        let bundledDylib = directory.appendingPathComponent("libsteam_api.dylib")
        if !fm.fileExists(atPath: bundledDylib.path) {
            let candidates = [
                URL(fileURLWithPath: "/Users/george/Documents/SteamIdleMac/ThirdParty/libsteam_api.dylib"),
                URL(fileURLWithPath: "/Users/george/Documents/SteamIdleMac/idle-helper/target/release/build/steamworks-sys-2cb9440c9a5c448e/out/libsteam_api.dylib"),
            ]
            if let source = candidates.first(where: { fm.fileExists(atPath: $0.path) }) {
                try? fm.copyItem(at: source, to: bundledDylib)
            }
        }

        let steamClient = try pathService.steamClientLibraryPath().appendingPathComponent("steamclient.dylib")
        let destClient = directory.appendingPathComponent("steamclient.dylib")
        if fm.fileExists(atPath: steamClient.path) {
            if fm.fileExists(atPath: destClient.path) {
                try? fm.removeItem(at: destClient)
            }
            try? fm.copyItem(at: steamClient, to: destClient)
        }
    }

    private func helperEnvironment(helperDirectory: URL) throws -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var paths = [helperDirectory.path]

        if let steamLib = try? pathService.steamClientLibraryPath().path {
            paths.append(steamLib)
        }

        let combined = paths.joined(separator: ":")
        if let existing = env["DYLD_LIBRARY_PATH"], !existing.isEmpty {
            env["DYLD_LIBRARY_PATH"] = combined + ":" + existing
        } else {
            env["DYLD_LIBRARY_PATH"] = combined
        }

        env.removeValue(forKey: "SteamAppId")
        return env
    }

    private func parseHelperError(_ output: String) -> String {
        if output.contains("Steam client must be running") || output.contains("NoSteamClient") {
            return "Steam must be running and you must be signed in."
        }
        if output.contains("Failed to initialize Steam API") || output.contains("steamclient") {
            return "Steam API failed to initialize. Quit and reopen Steam, then try again."
        }
        if output.isEmpty {
            return "idle-helper crashed on startup. Ensure Steam is running."
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
