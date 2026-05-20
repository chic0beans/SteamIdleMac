import AppKit

struct SteamRunningService {
    func isSteamRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            let bid = app.bundleIdentifier?.lowercased() ?? ""
            let name = app.localizedName?.lowercased() ?? ""
            return bid.contains("steam") || name == "steam"
        }
    }
}
