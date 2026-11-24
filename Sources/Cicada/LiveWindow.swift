import AppKit
import SwiftUI

/// Snart's one window, a small floating glass drop: the language pair, the latest exchange (scroll
/// up for the rest), and what happens when you talk. Floats over the meeting app without taking
/// focus, stays out of screen sharing, remembers where it was put. Settings open from the gear.
@MainActor
final class LiveWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var model: AppModel?
    private static let autosave = "SnartDrop"
    static let size = NSSize(width: 340, height: 214)

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        guard let model else { return }
        if panel == nil {
            let p = LivePanel(contentRect: NSRect(origin: .zero, size: Self.size),
                              styleMask: [.borderless, .nonactivatingPanel, .resizable],
                              backing: .buffered, defer: false)
            // The drop draws its own glass and corners: the window itself is clear.
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.isMovableByWindowBackground = true
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false
            // Others never see it when you share your screen.
            p.sharingType = .none
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.minSize = NSSize(width: 300, height: 150)
            p.maxSize = NSSize(width: 560, height: 640)
            p.delegate = self
            let host = FirstClickHostingView(rootView: LiveView(model: model, store: model.store, settings: model.settings,
                                                                close: { [weak self] in self?.hide() }))
            host.wantsLayer = true
            host.layer?.backgroundColor = .clear
            p.contentView = host
            p.setFrameAutosaveName(Self.autosave)
            if !p.setFrameUsingName(Self.autosave), let screen = NSScreen.main?.visibleFrame {
                p.setFrame(NSRect(x: screen.maxX - Self.size.width - 16, y: screen.maxY - Self.size.height - 12,
                                  width: Self.size.width, height: Self.size.height), display: false)
            }
            panel = p
        }
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    /// Debug (`liveCapturable`): let `screencapture -l` see it, to check the glass as drawn.
    func setCapturable(_ on: Bool) { panel?.sharingType = on ? .readOnly : .none }
    var windowNumber: Int? { panel?.windowNumber }
}

private final class LivePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// What is being heard right now, before the line is finished.
struct LiveDraft: Equatable {
    var src = ""
    var dst = ""
}

/// The water drop: frosted glass, a sheen from the top-left like light on water, a faint blue
/// depth at the bottom (the brand's ring colour), and a hairline rim. No heavy outline.
struct DropBackground: View {
    var radius: CGFloat = 26
    private static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.2)],
                                      startPoint: .top, endPoint: .bottom))
            shape.fill(RadialGradient(colors: [Self.blue.opacity(0.10), .clear], center: .bottom, startRadius: 0, endRadius: 220))
            // The highlight a drop of water catches.
            Ellipse().fill(Color.white.opacity(0.6)).frame(width: 130, height: 34).blur(radius: 14)
                .offset(x: -8, y: -6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipShape(shape)
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0.25), Self.blue.opacity(0.18)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
        }
    }
}

/// A small glass capsule for chips and the talk line.
private struct Bead: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Capsule().fill(Color.white.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 0.6))
    }
}

struct LiveView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: SessionStore
    @ObservedObject var settings: AppSettings
    var close: () -> Void = {}

    private var session: Session? { store.session(store.liveID) }

    var body: some View {
        VStack(spacing: 8) {
            header
            if settings.speakEnabled, let strip = micStrip { strip }
            if model.running { transcript } else { idle }
            footer
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
        .background(DropBackground())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            BrandMark(size: 16)
            direction
            Spacer(minLength: 4)
            if model.running {
                HStack(spacing: 4) {
                    Circle().fill(Palette.accent).frame(width: 6, height: 6)
                    if let start = session?.startedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(verbatim: TranscriptExport.clock(max(0, ctx.date.timeIntervalSince(start))))
                                .font(.system(size: 11).monospacedDigit()).foregroundStyle(Palette.secondary)
                        }
                    }
                }
            }
            iconButton("gearshape", help: "Settings") { model.openSettings(.ai) }
            iconButton("xmark", help: "Hide (open it again from the menu bar)") { close() }
        }
        .frame(height: 22)
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.secondary)
                .frame(width: 20, height: 20).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var mine: String { model.myCode.uppercased() }
    private var theirs: String { model.theirCode.uppercased() }
    private var myName: String { VoiceSettings.name(model.myCode) }
    private var theirName: String { VoiceSettings.name(model.theirCode) }

    /// The pair in one chip: yours on the left, theirs on the right, each a menu; the arrows swap them.
    private var direction: some View {
        HStack(spacing: 2) {
            languageMenu(mine, help: "You speak \(myName)") { model.setLanguages(mine: $0, theirs: model.theirCode) }
            Button { model.swapLanguages() } label: {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.secondary)
                    .frame(width: 18, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Swap")
            languageMenu(theirs, help: "They speak \(theirName)") { model.setLanguages(mine: model.myCode, theirs: $0) }
        }
        .padding(.horizontal, 4).frame(height: 22)
        .modifier(Bead())
    }

    private func languageMenu(_ code: String, help: String, pick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(sourceLanguages, id: \.code) { l in Button(l.name) { pick(l.code) } }
        } label: {
            Text(verbatim: code).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .help(help)
    }

    // MARK: Conversation

    private var idle: some View {
        VStack(spacing: 10) {
            Text(verbatim: "They speak \(theirName), you read \(myName).")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            Button { model.setRunning(true) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform").font(.system(size: 11, weight: .semibold))
                    Text(verbatim: "Start listening").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).frame(height: 30)
                .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96),
                                                                   Color(red: 0.11, green: 0.31, blue: 0.85)],
                                                          startPoint: .top, endPoint: .bottom)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Sized to the latest exchange; earlier lines are above it, a scroll away, fading out at the top.
    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    let lines = Array((session?.lines ?? []).suffix(80))
                    if lines.isEmpty && model.draft.src.isEmpty {
                        Text(verbatim: "Listening…").font(.system(size: 12)).foregroundStyle(Palette.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 18)
                    }
                    ForEach(lines) { line in row(line) }
                    if !model.draft.src.isEmpty {
                        pair(label: theirs, src: model.draft.src, dst: model.draft.dst, me: false).opacity(0.55)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, 2)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                         .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
            .onAppear { proxy.scrollTo("end", anchor: .bottom) }
            .onChange(of: session?.lines.count) { _, _ in withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("end", anchor: .bottom) } }
            .onChange(of: model.draft) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ line: TranscriptLine) -> some View {
        let me = line.speaker == "me"
        return pair(label: me ? "You" : line.srcLang.uppercased().prefix(2).description, src: line.src, dst: line.dst ?? "…", me: me)
    }

    /// The original small and grey, the translation larger: the line you read is the translation.
    private func pair(label: String, src: String, dst: String, me: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: label).font(.system(size: 9, weight: .bold))
                    .foregroundStyle(me ? Palette.accent : Palette.tertiary).frame(width: 24, alignment: .leading)
                Text(verbatim: src).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Text(verbatim: dst.isEmpty ? "…" : dst)
                .font(.system(size: 14, weight: me ? .regular : .medium, design: .rounded)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                .padding(.leading, 30)
        }
    }

    // MARK: Call app microphone

    /// Apps people call from (browsers for Meet). Not Snart itself, nor a dictation app reading the
    /// same virtual mic, which would read as "hears your translation" when nobody does.
    static let callApps: Set<String> = MicUsers.meetingApps.union([
        "net.whatsapp.WhatsApp", "com.apple.FaceTime", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
        "ru.keepcoder.Telegram", "org.whispersystems.signal-desktop", "com.skype.skype",
        "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "org.mozilla.firefox",
        "com.microsoft.edgemac", "com.brave.Browser",
    ])

    /// Whether the call app takes its microphone from Snart: if it reads another mic, the other
    /// side never hears the translation, and nothing else on screen would say so.
    private var micStrip: AnyView? {
        let calls = model.micUsers.filter { Self.callApps.contains($0.bundleID) }
        let wrong = calls.first { if case .otherMic = $0.state { return true } else { return false } }
        if let wrong, case .otherMic(let device) = wrong.state {
            return AnyView(strip(icon: "exclamationmark.triangle.fill", color: Palette.warn, fill: Palette.warnPale,
                                 text: "\(wrong.name) is on \(device): they can't hear you. Pick BlackHole 2ch as its mic."))
        }
        if let ok = calls.first(where: { $0.state == .virtualMic }) {
            return AnyView(strip(icon: "checkmark.circle.fill", color: Palette.ok, fill: Palette.okPale,
                                 text: "\(ok.name) hears your translation"))
        }
        return nil
    }

    private func strip(icon: String, color: Color, fill: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color).padding(.top, 1)
            Text(verbatim: text).font(.system(size: 10.5)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill.opacity(0.8)))
    }

    // MARK: Talk

    private var footer: some View {
        HStack(spacing: 8) {
            talkMode
            HStack(spacing: 6) {
                Image(systemName: speakIcon).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(model.speakPhase == .idle ? Palette.tertiary : Palette.accent)
                Text(verbatim: speakLine).font(.system(size: 11))
                    .foregroundStyle(model.speakPhase == .idle ? Palette.secondary : Palette.ink)
                    .lineLimit(1).truncationMode(.head)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: 26)
            .modifier(Bead())
            if model.running {
                Button { model.requestStop() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 9)).foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Palette.ink.opacity(0.85)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Stop")
            }
        }
    }

    /// How you talk, always in sight: hold the key, or hands-free (the mic stays open while
    /// listening, which is why it shows here and not only in settings).
    private var talkMode: some View {
        HStack(spacing: 1) {
            modeButton("option", on: !settings.speakHandsFree, help: "Hold right ⌥ to talk") { settings.speakHandsFree = false }
            modeButton("waveform", on: settings.speakHandsFree, help: "Hands-free: the mic stays open, it speaks after you pause") {
                settings.speakHandsFree = true
            }
        }
        .padding(2)
        .modifier(Bead())
    }

    private func modeButton(_ icon: String, on: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(on ? Color.white : Palette.secondary)
                .frame(width: 24, height: 22)
                .background(Capsule().fill(on ? Palette.ink.opacity(0.85) : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
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
        case .idle:
            if settings.speakHandsFree {
                return model.running ? "Hands-free: just talk, they hear \(theirName)" : "Hands-free starts when you start listening"
            }
            return "Hold right ⌥ to speak \(theirName)"
        case .listening: return model.liveSource.isEmpty ? "Listening to you…" : model.liveSource
        case .translating: return "Translating…"
        case .speaking: return model.liveTranslation.isEmpty ? "Speaking \(theirName)…" : model.liveTranslation
        }
    }
}
