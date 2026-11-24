import AppKit
import AVFoundation
import SwiftUI

/// Snart's first-run setup, in the live drop's glass: welcome, hearing the call, the language pair,
/// the AI and ElevenLabs keys, the virtual microphone, done. Each step can be skipped; settings
/// hold the same choices later.
struct SetupView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var ling: LingClient
    @ObservedObject var installer: VirtualMicInstaller
    let close: () -> Void
    let finish: () -> Void

    /// The step, 0-based, kept on the model so the `step:` debug command can show any of them.
    private var step: Int {
        get { min(max(model.onboardingStep - 1, 0), Self.steps.count - 1) }
        nonmutating set { model.onboardingStep = newValue + 1 }
    }
    @State private var aiKey = ""
    @State private var elevenKey = ""
    @State private var elevenVoice = ElevenLabs.voice ?? ""
    @State private var elevenSaved = ElevenLabs.configured

    private static let steps = ["Welcome", "Hearing", "Languages", "Keys", "Voice out", "Done"]
    private static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BrandMark(size: 18)
                Text(verbatim: "Snart").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                Spacer()
                dots
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.secondary)
                        .frame(width: 20, height: 20).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close (set up later in Settings)")
            }
            .frame(height: 22)
            .padding(.bottom, 22)

            Group {
                switch step {
                case 0: welcome
                case 1: hearing
                case 2: languages
                case 3: keys
                case 4: voiceOut
                default: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 && step < 5 {
                    Button { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } } label: {
                        Text(verbatim: "Back").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if step < 5 {
                    primary(step == 0 ? "Set up Snart" : "Continue") { withAnimation(.easeOut(duration: 0.2)) { step += 1 } }
                } else {
                    primary("Open Snart", action: finish)
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 520)
        .background(DropBackground(radius: 30))
        .sheet(isPresented: $model.speakTestShown) {
            SpeakTestView(model: model, tester: model.speakTester) {
                if model.speakTester.busy { model.speakTester.cancel() }
                model.speakTestShown = false
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(0..<Self.steps.count, id: \.self) { i in
                Capsule().fill(i == step ? Self.blue : Palette.ink.opacity(0.15))
                    .frame(width: i == step ? 14 : 5, height: 5)
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrandMark(size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "Talk across languages,\nin your own voice.")
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                Text(verbatim: "Snart sits beside your call as a small bubble.")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                point("text.bubble", "They speak, you read it in your language.")
                point("waveform", "You speak, they hear it in theirs, in your voice.")
                point("globe", "English, French, Italian, German and Tamil.")
            }
            .padding(.top, 4)
        }
    }

    private var hearing: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Let Snart hear the call", "Sound from your Mac becomes your subtitles. Only sound, never the screen.")
            card {
                row("speaker.wave.2", "Your Mac's sound", model.systemAudioRefused ? "Turned off: allow it, then reopen Snart" : "What the other side says") {
                    if model.systemAudioOK { ok } else if model.systemAudioRefused {
                        HStack(spacing: 6) { secondary("Reopen") { model.relaunch() }; secondary("Allow") { model.requestSystemAudio() } }
                    } else { secondary("Allow") { model.requestSystemAudio() } }
                }
                if Recognition.legacy {
                    Divider().opacity(0.5)
                    row("waveform", "Speech recognition", "Turn on Dictation and allow it") {
                        if model.speechOK { ok } else { secondary("Allow") { model.requestSpeech() } }
                    }
                }
                Divider().opacity(0.5)
                row("mic", "Microphone", "What you say, while you talk") {
                    if model.micStatus == .authorized { ok } else {
                        secondary("Allow") {
                            AVCaptureDevice.requestAccess(for: .audio) { _ in
                                DispatchQueue.main.async { MainActor.assumeIsolated { model.refreshPermissions() } }
                            }
                        }
                    }
                }
            }
        }
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Your languages", "Change them any time from the bubble.")
            card {
                row("person", "I speak", "You read this, and talk in it") {
                    languageMenu(model.myCode) { model.setLanguages(mine: $0, theirs: model.theirCode) }
                }
                Divider().opacity(0.5)
                row("person.2", "They speak", "They hear you in this") {
                    languageMenu(model.theirCode) { model.setLanguages(mine: model.myCode, theirs: $0) }
                }
                Divider().opacity(0.5)
                row("hand.tap", "How you talk", settings.speakHandsFree ? "Just talk; it speaks after a short pause" : "Hold right ⌥ while you speak") {
                    HStack(spacing: 2) {
                        segment("Hold ⌥", on: !settings.speakHandsFree) { settings.speakHandsFree = false }
                        segment("Hands-free", on: settings.speakHandsFree) { settings.speakHandsFree = true }
                    }
                    .padding(2)
                    .background(Capsule().fill(Palette.ink.opacity(0.06)))
                }
            }
        }
    }

    private var keys: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Your keys", "Stored only on this Mac. You can add them later in Settings.")
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label { Text(verbatim: "Translation and notes") } icon: { Image(systemName: "sparkles") }
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
                        Spacer()
                        if ling.usable { ok }
                    }
                    HStack(spacing: 2) {
                        ForEach(AIProvider.all.filter { $0.id != .custom }, id: \.id) { p in
                            segment(p.name, on: settings.provider.id == p.id) {
                                settings.aiProvider = p.id.rawValue
                                model.applyAIService()
                            }
                        }
                    }
                    .padding(2)
                    .background(Capsule().fill(Palette.ink.opacity(0.06)))
                    HStack(spacing: 8) {
                        SecureField(ling.hasKey ? "Saved · paste to replace" : keyHint, text: $aiKey).textFieldStyle(.roundedBorder)
                        secondary("Save") {
                            let k = aiKey
                            aiKey = ""
                            Task { await ling.setKey(k) }
                        }
                        .disabled(aiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(14)
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label { Text(verbatim: "Your voice · ElevenLabs") } icon: { Image(systemName: "person.wave.2") }
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
                        Spacer()
                        if elevenSaved { ok }
                    }
                    SecureField(elevenSaved ? "Saved · paste to replace" : "ElevenLabs API key", text: $elevenKey).textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        TextField("Voice ID of your clone", text: $elevenVoice).textFieldStyle(.roundedBorder)
                        secondary("Save") {
                            guard ElevenLabs.save(key: elevenKey, voice: elevenVoice) else { return }
                            elevenKey = ""
                            elevenSaved = ElevenLabs.configured
                            model.setVoiceEverywhere(ElevenLabs.id, also: model.theirCode)
                        }
                        .disabled(elevenVoice.trimmingCharacters(in: .whitespaces).isEmpty || (!elevenSaved && elevenKey.isEmpty))
                    }
                }
                .padding(14)
            }
            .font(.system(size: 12))
        }
    }

    private var keyHint: String {
        switch settings.provider.id {
        case .anthropic: "sk-ant-…"
        case .openrouter: "sk-or-…"
        default: "sk-…"
        }
    }

    private var voiceOut: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("So they hear you", "Snart speaks into a virtual microphone, BlackHole 2ch. Your call app listens to it like a mic.")
            if let mic = model.virtualMic {
                card {
                    row("checkmark.seal", "\(mic.name) is ready", "In WhatsApp, Zoom or Meet, use it as the microphone") { ok }
                    Divider().opacity(0.5)
                    row("play.circle", "Try a sentence", "Say one line and hear exactly what they will hear") {
                        secondary("Try") { model.speakTestShown = true }
                    }
                }
            } else {
                MicSetupCard(installer: installer, deviceName: nil)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.6)))
            }
        }
        .onAppear { if !settings.speakEnabled { model.enableSpeaking(true) } }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Self.blue)
            Text(verbatim: "You're set.").font(.system(size: 26, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 10) {
                point("1.circle", "Open Snart's bubble and press Start listening.")
                point("2.circle", "Then start the call, with BlackHole 2ch as its microphone.")
                point("3.circle", settings.speakHandsFree ? "Talk. They hear you after a short pause." : "Hold right ⌥ while you talk.")
            }
        }
    }

    // MARK: Pieces

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(verbatim: detail).font(.system(size: 12.5)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(Self.blue).frame(width: 18)
            Text(verbatim: text).font(.system(size: 13)).foregroundStyle(Palette.ink)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 0.6))
    }

    private func row<Trailing: View>(_ icon: String, _ title: String, _ detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Self.blue).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
                Text(verbatim: detail).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var ok: some View {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(Palette.ok)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 20).frame(height: 34)
                .background(Capsule().fill(LinearGradient(colors: [Self.blue, Color(red: 0.11, green: 0.31, blue: 0.85)],
                                                          startPoint: .top, endPoint: .bottom)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).frame(height: 26)
                .background(Capsule().fill(Color.white.opacity(0.8)))
                .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.08), lineWidth: 0.6))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func segment(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title).font(.system(size: 11.5, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Palette.ink : Palette.secondary)
                .padding(.horizontal, 10).frame(height: 22)
                .background(Capsule().fill(on ? Color.white : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func languageMenu(_ code: String, pick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(sourceLanguages, id: \.code) { l in Button(l.name) { pick(l.code) } }
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: VoiceSettings.name(code)).font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Capsule().fill(Color.white.opacity(0.8)))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}

/// A borderless window that still takes the keyboard (the key fields), dragged by its glass.
final class SetupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
