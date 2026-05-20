import SwiftUI

struct GameLibraryView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if appState.isLoadingLibrary && appState.games.isEmpty {
                ProgressView("Loading library…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.games.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No games loaded")
                        .font(.title3)
                    Text("Add your API key and refresh.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appState.filteredGames) { game in
                            GameCardView(
                                game: game,
                                isSelected: appState.selectedAppIDs.contains(game.appid),
                                isIdling: appState.idleManager.activeAppIDs.contains(game.appid)
                            ) {
                                appState.toggleSelection(game)
                            } onStart: {
                                appState.startIdle(game: game)
                            } onStop: {
                                appState.stopIdle(game: game)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Search games", text: $appState.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Picker("", selection: $appState.sortOrder) {
                ForEach(GameSortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .labelsHidden()

            Text("\(appState.idleManager.activeSessions.count)/\(IdleProcessManager.maxConcurrent) idling")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !appState.selectedAppIDs.isEmpty {
                Text("\(appState.selectedAppIDs.count) selected")
                    .font(.caption)
            }

            Button("Start Selected") {
                appState.startIdleForSelection()
            }
            .disabled(!appState.canStartIdle)

            Button("Stop All") {
                appState.idleManager.stopAll()
            }
            .disabled(appState.idleManager.activeSessions.isEmpty)

            Button {
                Task { await appState.refreshLibrary(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(appState.isLoadingLibrary)
            .help("Refresh library")
        }
        .padding(12)
    }
}

struct GameCardView: View {
    let game: Game
    let isSelected: Bool
    let isIdling: Bool
    let onToggleSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: game.headerImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(460.0 / 215.0, contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .aspectRatio(460.0 / 215.0, contentMode: .fit)
                    }
                }
                .frame(height: 103)
                .clipped()
                .cornerRadius(6)

                if isIdling {
                    Label("Idling", systemImage: "bolt.fill")
                        .font(.caption2.bold())
                        .padding(4)
                        .background(.green.opacity(0.85))
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                        .padding(6)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .padding(6)
                }
            }

            Text(game.name)
                .font(.headline)
                .lineLimit(2)

            Text(String(format: "%.1f hrs played", game.playtimeHours))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(isSelected ? "Deselect" : "Select", action: onToggleSelect)
                    .controlSize(.small)

                Spacer()

                if isIdling {
                    Button("Stop", role: .destructive, action: onStop)
                        .controlSize(.small)
                } else {
                    Button("Idle", action: onStart)
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isIdling ? Color.green : (isSelected ? Color.accentColor : Color.clear), lineWidth: 2)
        )
    }
}
