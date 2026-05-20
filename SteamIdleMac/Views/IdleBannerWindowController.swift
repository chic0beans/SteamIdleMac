import AppKit
import SwiftUI

@MainActor
final class IdleBannerWindowController: NSWindowController {
    private let onStop: () -> Void
    let appid: UInt64

    init(game: Game, style: BannerStyle, onStop: @escaping () -> Void) {
        self.onStop = onStop
        self.appid = game.appid

        let size = style.windowSize
        let panel = NSPanel(
            contentRect: NSRect(x: 120, y: 120, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = game.name
        // Below the main app window (which is set to .floating + 1) but above normal windows.
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        let root = IdleBannerView(game: game, style: style) { [weak self] in
            self?.onStop()
            self?.close()
        }
        panel.contentView = NSHostingView(rootView: root)
        panel.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct IdleBannerView: View {
    let game: Game
    let style: BannerStyle
    let onStop: () -> Void

    var body: some View {
        switch style {
        case .landscape:
            landscapeBody
        case .icon:
            iconBody
        }
    }

    private var landscapeBody: some View {
        VStack(spacing: 0) {
            AsyncImage(url: game.headerImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(460.0 / 215.0, contentMode: .fill)
                case .failure:
                    fallbackArtwork
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                }
            }
            .frame(height: 215)
            .clipped()

            footer
                .padding(8)
                .background(.bar)
        }
        .frame(width: 460)
    }

    private var iconBody: some View {
        VStack(spacing: 0) {
            AsyncImage(url: game.iconImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    AsyncImage(url: game.capsuleImageURL) { phase2 in
                        switch phase2 {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            fallbackArtwork
                        }
                    }
                }
            }
            .frame(width: 200, height: 200)
            .clipped()

            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.bar)
        }
        .frame(width: 200)
    }

    private var fallbackArtwork: some View {
        ZStack {
            Rectangle().fill(Color.gray.opacity(0.35))
            Text(game.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(8)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill").foregroundStyle(.green)
            Text("Idling").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Button("Stop", role: .destructive, action: onStop)
                .controlSize(.small)
        }
    }
}

@MainActor
final class IdleBannerWindowManager: ObservableObject {
    private var controllers: [UInt64: IdleBannerWindowController] = [:]

    func sync(with sessions: [ActiveIdleSession],
              games: [Game],
              style: BannerStyle,
              onStop: @escaping (UInt64) -> Void) {
        let activeIDs = Set(sessions.map(\.appid))

        for (appid, controller) in controllers where !activeIDs.contains(appid) {
            controller.close()
            controllers.removeValue(forKey: appid)
        }

        for session in sessions {
            guard controllers[session.appid] == nil else { continue }
            let game = games.first(where: { $0.appid == session.appid })
                ?? Game(appid: session.appid, name: session.name, playtimeForever: 0)

            let controller = IdleBannerWindowController(game: game, style: style) {
                onStop(session.appid)
            }
            controller.showWindow(nil)
            controllers[session.appid] = controller
        }
    }

    func closeAll() {
        for (_, controller) in controllers {
            controller.close()
        }
        controllers.removeAll()
    }
}
