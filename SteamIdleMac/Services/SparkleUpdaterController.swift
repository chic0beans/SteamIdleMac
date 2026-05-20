import Foundation
import Sparkle
import SwiftUI

/// Wrapper around SPUStandardUpdaterController. We instantiate it lazily so that startup
/// doesn't crash when SUFeedURL/SUPublicEDKey have not been configured yet (e.g. ad-hoc dev builds).
@MainActor
final class SparkleUpdaterController: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var _updater: SPUStandardUpdaterController?
    private var hasProbedForUpdates = false
    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var availableUpdateDisplayVersion: String?

    private var updater: SPUStandardUpdaterController? {
        if _updater == nil, isConfigured {
            _updater = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: self,
                userDriverDelegate: nil
            )
        }
        return _updater
    }

    var canCheck: Bool {
        guard let u = updater else { return false }
        return u.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updater?.checkForUpdates(nil)
    }

    /// Performs a non-intrusive probe so UI can show an "update available" badge.
    func probeForUpdatesIfNeeded() {
        guard !hasProbedForUpdates else { return }
        guard let u = updater else { return }
        hasProbedForUpdates = true
        u.updater.checkForUpdateInformation()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let display = item.displayVersionString.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = item.versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        availableUpdateDisplayVersion = display.isEmpty ? (fallback.isEmpty ? nil : fallback) : display
        isUpdateAvailable = true
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        isUpdateAvailable = false
        availableUpdateDisplayVersion = nil
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        isUpdateAvailable = false
        availableUpdateDisplayVersion = nil
    }

    private var isConfigured: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = (info["SUFeedURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pub = (info["SUPublicEDKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Sparkle 2.x will refuse to install updates without an EdDSA public key, so we require
        // both `SUFeedURL` and `SUPublicEDKey` before creating the standard controller. Dev
        // builds without these keys silently disable the "Check for updates..." menu items.
        return !feed.isEmpty && !pub.isEmpty
    }
}
