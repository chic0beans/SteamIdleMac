import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var bannerManager = IdleBannerWindowManager()

    var body: some View {
        Group {
            if !appState.onboardingCompleted {
                OnboardingView()
            } else if appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SetupView()
            } else {
                GameLibraryView()
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .alert("Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .onAppear { applyAlwaysOnTop() }
        .onChange(of: appState.keepWindowAboveBanners) { _ in applyAlwaysOnTop() }
        .onChange(of: appState.bannerStyle) { _ in resyncBanners() }
        .onChange(of: appState.idleManager.activeSessions.map(\.appid)) { _ in
            resyncBanners()
        }
        .onDisappear {
            bannerManager.closeAll()
            appState.idleManager.cleanupOnQuit()
        }
    }

    private func resyncBanners() {
        bannerManager.sync(
            with: appState.idleManager.activeSessions,
            games: appState.games,
            style: appState.bannerStyle
        ) { appid in
            appState.idleManager.stopIdle(appid: appid)
        }
        applyAlwaysOnTop()
    }

    private func applyAlwaysOnTop() {
        let elevated = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        for window in NSApp.windows {
            // Skip panels (banners) and the menubar window.
            guard window.contentViewController != nil,
                  !(window is NSPanel) else { continue }
            window.level = appState.keepWindowAboveBanners ? elevated : .normal
            window.collectionBehavior.insert(.canJoinAllSpaces)
        }
    }
}
