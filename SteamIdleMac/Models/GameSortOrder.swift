import Foundation

enum GameSortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "A-Z"
    case playtimeHighest = "Most played"
    case playtimeLowest = "Least played"
    case recentlyPlayed = "Recent"

    var id: String { rawValue }

    func sort(_ games: [Game]) -> [Game] {
        switch self {
        case .nameAscending:
            return games.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .playtimeHighest:
            return games.sorted { $0.playtimeForever > $1.playtimeForever }
        case .playtimeLowest:
            return games.sorted { $0.playtimeForever < $1.playtimeForever }
        case .recentlyPlayed:
            return games.sorted {
                ($0.lastPlayedAt ?? 0) > ($1.lastPlayedAt ?? 0)
            }
        }
    }
}
