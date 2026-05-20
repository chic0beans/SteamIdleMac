import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var apiKeyInput: String = ""
    @State private var testStatus: TestStatus = .idle
    @State private var tutorialStarted = false

    enum TestStatus: Equatable {
        case idle
        case testing
        case success(Int)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch step {
                case .welcome: WelcomeStep(next: { step = .apiKey })
                case .apiKey: apiKeyStep
                case .stylePicker: stylePickerStep
                case .tutorialIdle: tutorialStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        }
        .frame(minWidth: 720, minHeight: 540)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(step.rawValue >= s.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - API key step

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add your Steam Web API key")
                .font(.title2.bold())
            Text("This loads your owned games. The key is stored only in your macOS Keychain.")
                .foregroundStyle(.secondary)

            HStack {
                Link("Open Steam to get your API key",
                     destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
                    .buttonStyle(.bordered)
                Spacer()
            }

            SecureField("Paste API key here", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Test key") { testKey() }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                statusView
                Spacer()
            }

            Spacer()
            HStack {
                Button("Back") { step = .welcome }
                Spacer()
                Button("Continue") {
                    Task {
                        try? appState.saveSettings()
                        await appState.refreshLibrary(force: true)
                        step = .stylePicker
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled({
                    if case .success = testStatus { return false }
                    return true
                }())
            }
        }
        .onAppear {
            apiKeyInput = appState.apiKey
            appState.apiKey = apiKeyInput
        }
        .onChange(of: apiKeyInput) { new in
            appState.apiKey = new
            testStatus = .idle
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch testStatus {
        case .idle: EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
            Text("Testing...").font(.caption).foregroundStyle(.secondary)
        case .success(let count):
            Label("\(count) games found", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.caption)
        case .failure(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.caption).lineLimit(2)
        }
    }

    private func testKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        testStatus = .testing
        Task {
            do {
                try appState.saveSettings()
                await appState.refreshLibrary(force: true)
                if let err = appState.errorMessage, appState.games.isEmpty {
                    testStatus = .failure(err)
                    appState.errorMessage = nil
                } else {
                    testStatus = .success(appState.games.count)
                }
            } catch {
                testStatus = .failure(error.localizedDescription)
            }
        }
    }

    // MARK: - Design picker step

    private var stylePickerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your design")
                .font(.title2.bold())
            if let game = appState.topPlaytimeGame {
                Text("Here's a preview using \(game.name) — your most-played game.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    ForEach(BannerStyle.allCases) { style in
                        StylePreviewCard(game: game,
                                         style: style,
                                         selected: appState.bannerStyle == style) {
                            appState.bannerStyle = style
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else if appState.isLoadingLibrary {
                ProgressView("Loading your library...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Couldn't load your games. Make sure your API key is correct.")
                    .foregroundStyle(.red)
            }

            Spacer()
            HStack {
                Button("Back") { step = .apiKey }
                Spacer()
                Button("Continue") { step = .tutorialIdle }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Tutorial step

    private var tutorialStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try it out")
                .font(.title2.bold())
            if let game = appState.topPlaytimeGame {
                Text("Let's idle \(game.name) for a moment so you can see what it looks like.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    StylePreviewCard(game: game, style: appState.bannerStyle, selected: true) { }
                        .frame(width: 260)
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Steam shows you as in-game", systemImage: "checkmark.circle.fill")
                        Label("A small banner appears on screen", systemImage: "rectangle.on.rectangle")
                        Label("Click Stop on the banner or here to end", systemImage: "stop.circle")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    if !tutorialStarted {
                        Button("Start tutorial idle") {
                            appState.startIdle(game: game)
                            tutorialStarted = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Stop tutorial idle") {
                            appState.stopIdle(game: game)
                            tutorialStarted = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Spacer()
            HStack {
                Button("Back") { step = .stylePicker }
                Spacer()
                Button("Finish") {
                    if let game = appState.topPlaytimeGame, tutorialStarted {
                        appState.stopIdle(game: game)
                    }
                    appState.completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome to Steam Idle Mac")
                .font(.largeTitle.bold())

            Text("Idle multiple Steam games using lightweight helper processes — without actually launching the games.")
                .foregroundStyle(.secondary)

            GroupBox("Quick facts") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Up to 32 games can idle at once.", systemImage: "32.circle")
                    Label("Steam must be running and signed in.", systemImage: "person.fill.checkmark")
                    Label("Avoid VAC-protected multiplayer games.", systemImage: "shield.slash")
                    Label("Idling may conflict with Steam terms; use at your own risk.", systemImage: "exclamationmark.triangle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
            HStack {
                Spacer()
                Button("Get started") { next() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct StylePreviewCard: View {
    let game: Game
    let style: BannerStyle
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                IdleBannerView(game: game, style: style, onStop: {})
                    .allowsHitTesting(false)
                    .scaleEffect(style == .landscape ? 0.6 : 0.8)
                    .frame(width: 280, height: 200)
                Text(style.displayName)
                    .font(.subheadline.bold())
            }
            .padding(12)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
