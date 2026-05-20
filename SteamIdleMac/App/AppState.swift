import Foundation
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case apiKey = 1
    case stylePicker = 2
    case tutorialIdle = 3
}

@MainActor
final class AppState: ObservableObject {
    @Published var games: [Game] = []
    @Published var selectedAppIDs: Set<UInt64> = []
    @Published var searchText = ""
    @Published var sortOrder: GameSortOrder = .nameAscending
    @Published var steamID64 = ""
    @Published var apiKey = ""
    @Published var isLoadingLibrary = false
    @Published var errorMessage: String?
    @Published var showSettings = false

    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
    @AppStorage("bannerStyle") private var bannerStyleRaw: String = BannerStyle.landscape.rawValue
    @AppStorage("keepWindowAboveBanners") var keepWindowAboveBanners: Bool = true

    var bannerStyle: BannerStyle {
        get { BannerStyle(rawValue: bannerStyleRaw) ?? .landscape }
        set { bannerStyleRaw = newValue.rawValue }
    }

    let idleManager = IdleProcessManager()
    private let pathService = SteamPathService()
    private let libraryService = SteamLibraryService()

    var filteredGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [Game]
        if query.isEmpty {
            base = games
        } else {
            base = games.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return sortOrder.sort(base)
    }

    var canStartIdle: Bool {
        !selectedAppIDs.isEmpty && idleManager.activeSessions.count < IdleProcessManager.maxConcurrent
    }

    /// Highest-playtime game from the library; used in onboarding tutorial.
    var topPlaytimeGame: Game? {
        games.max(by: { $0.playtimeForever < $1.playtimeForever })
    }

    func bootstrap() {
        apiKey = KeychainService.loadAPIKey() ?? ""
        do {
            steamID64 = try pathService.detectSteamID64()
        } catch {
            errorMessage = error.localizedDescription
        }

        if onboardingCompleted, !apiKey.isEmpty, !steamID64.isEmpty {
            Task { await refreshLibrary(force: false) }
        }
    }

    func saveSettings() throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            try KeychainService.deleteAPIKey()
            return
        }
        try KeychainService.saveAPIKey(trimmedKey)
    }

    func completeOnboarding() {
        onboardingCompleted = true
    }

    func refreshLibrary(force: Bool) async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            errorMessage = SteamLibraryError.missingAPIKey.localizedDescription
            return
        }

        if steamID64.isEmpty {
            do {
                steamID64 = try pathService.detectSteamID64()
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        isLoadingLibrary = true
        errorMessage = nil
        defer { isLoadingLibrary = false }

        do {
            games = try await libraryService.fetchOwnedGames(
                steamID: steamID64,
                apiKey: key,
                forceRefresh: force
            )
        } catch {
            if let cached = libraryService.loadCache(steamID: steamID64), !cached.isEmpty {
                games = cached
                errorMessage = "Using cached library: \(error.localizedDescription)"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleSelection(_ game: Game) {
        if selectedAppIDs.contains(game.appid) {
            selectedAppIDs.remove(game.appid)
            return
        }

        if selectedAppIDs.count + idleManager.activeSessions.count >= IdleProcessManager.maxConcurrent {
            errorMessage = IdleProcessError.maxSessionsReached.localizedDescription
            return
        }

        selectedAppIDs.insert(game.appid)
    }

    func startIdleForSelection() {
        let selected = games.filter { selectedAppIDs.contains($0.appid) }
        guard !selected.isEmpty else { return }

        var failures: [String] = []

        for game in selected {
            if idleManager.activeAppIDs.contains(game.appid) { continue }

            do {
                try idleManager.startIdle(game: game)
                selectedAppIDs.remove(game.appid)
            } catch {
                failures.append("\(game.name): \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
    }

    func startIdle(game: Game) {
        do {
            try idleManager.startIdle(game: game)
            selectedAppIDs.remove(game.appid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopIdle(game: Game) {
        idleManager.stopIdle(appid: game.appid)
    }
}
