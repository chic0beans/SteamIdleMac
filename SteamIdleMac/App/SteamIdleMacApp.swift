import AppKit
import SwiftUI

@main
struct SteamIdleMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState()
    @StateObject private var updater = SparkleUpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appState.bootstrap()
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
            }
        }

        MenuBarExtra {
            MenuBarDashboard()
                .environmentObject(appState)
                .environmentObject(updater)
        } label: {
            let count = appState.idleManager.activeSessions.count
            Image(systemName: count > 0 ? "gamecontroller.fill" : "gamecontroller")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
