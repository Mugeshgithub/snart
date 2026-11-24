import AppKit
import SwiftUI

/// Cognivex Interpreter's one window: start and stop, what they said (French) with its English,
/// what you said with its French, and the talk key. Floats over the meeting app without taking
/// focus, stays out of screen sharing, remembers where it was put. Settings open from the gear.
@MainActor
final class LiveWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var model: AppModel?
    private static let autosave = "CognivexLive"

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        guard let model else { return }
        if panel == nil {
            let p = LivePanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                              backing: .buffered, defer: false)
            p.titleVisibility = .hidden
            p.titlebarAppearsTransparent = true
            p.isMovableByWindowBackground = true
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false
            // Others never see it when you share your screen.
            p.sharingType = .none
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.minSize = NSSize(width: 320, height: 260)
            p.backgroundColor = .white
            p.delegate = self
            p.contentView = FirstClickHostingView(rootView: LiveView(model: model, store: model.store))
            p.setFrameAutosaveName(Self.autosave)
            if !p.setFrameUsingName(Self.autosave), let screen = NSScreen.main?.visibleFrame {
                p.setFrameOrigin(NSPoint(x: screen.maxX - 400, y: screen.maxY - 480))
            }
            panel = p
        }
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}

private final class LivePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// What is being heard right now, before the line is finished.
struct LiveDraft: Equatable {
    var src = ""
    var dst = ""
}

struct LiveView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: SessionStore

    private var session: Session? { store.session(store.liveID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.running { transcript } else { idle }
            Divider()
            footer
        }
        .background(Color.white)
        .frame(minWidth: 320, minHeight: 260)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            BrandMark(size: 20)
            Text(verbatim: "Cognivex").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
            Spacer()
            if model.running {
                HStack(spacing: 5) {
                    Circle().fill(Palette.accent).frame(width: 7, height: 7)
                    Text(verbatim: "Live").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                    if let start = session?.startedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(verbatim: TranscriptExport.clock(max(0, ctx.date.timeIntervalSince(start))))
                                .font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.secondary)
                        }
                    }
                }
            }
            Button { model.openSettings(.ai) } label: {
                Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        // Clear of the close button in the transparent title bar.
        .padding(.leading, 74).padding(.trailing, 12).frame(height: 40)
    }

    // MARK: Body

    private var idle: some View {
        VStack(spacing: 14) {
            Spacer()
            Text(verbatim: "They speak French, you read English.\nYou speak English, they hear French.")
                .font(.system(size: 13)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            Button { model.setRunning(true) } label: {
                Text(verbatim: "Start listening").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(height: 32)
                    .background(Capsule().fill(Palette.ink))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Text(verbatim: "⌘R").font(.system(size: 11)).foregroundStyle(Palette.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    let lines = Array((session?.lines ?? []).suffix(60))
                    if lines.isEmpty && model.draft.src.isEmpty {
                        Text(verbatim: "Listening. Lines appear here when someone speaks.")
                            .font(.system(size: 12)).foregroundStyle(Palette.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 40)
                    }
                    ForEach(lines) { line in row(line) }
                    if !model.draft.src.isEmpty {
                        pair(label: "FR", src: model.draft.src, dst: model.draft.dst, me: false).opacity(0.6)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .onChange(of: session?.lines.count) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .bottom) } }
            .onChange(of: model.draft) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    private func row(_ line: TranscriptLine) -> some View {
        let me = line.speaker == "me"
        return pair(label: me ? "You" : line.srcLang.uppercased().prefix(2).description, src: line.src, dst: line.dst ?? "…", me: me)
    }

    /// The original small and grey, the translation in ink: the line you read is the English one.
    private func pair(label: String, src: String, dst: String, me: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: label).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(me ? Palette.accent : Palette.tertiary).frame(width: 26, alignment: .leading)
                Text(verbatim: src).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Text(verbatim: dst.isEmpty ? "…" : dst).font(.system(size: 14, weight: me ? .regular : .medium)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                .padding(.leading, 32)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: speakIcon).font(.system(size: 12))
                .foregroundStyle(model.speakPhase == .idle ? Palette.tertiary : Palette.accent)
            Text(verbatim: speakLine).font(.system(size: 12)).foregroundStyle(model.speakPhase == .idle ? Palette.secondary : Palette.ink)
                .lineLimit(2)
            Spacer(minLength: 6)
            if model.running {
                Button { model.requestStop() } label: {
                    Text(verbatim: "Stop").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 24)
                        .background(Capsule().fill(Palette.ink))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 44)
        .background(Palette.raised)
    }

    private var speakIcon: String {
        switch model.speakPhase {
        case .idle: "option"
        case .listening: "mic.fill"
        case .translating: "ellipsis"
        case .speaking: "speaker.wave.2.fill"
        }
    }

    private var speakLine: String {
        switch model.speakPhase {
        case .idle: return "Hold right ⌥ to speak French"
        case .listening: return model.liveSource.isEmpty ? "Listening to you…" : model.liveSource
        case .translating: return "Translating…"
        case .speaking: return model.liveTranslation.isEmpty ? "Speaking French…" : model.liveTranslation
        }
    }
}
