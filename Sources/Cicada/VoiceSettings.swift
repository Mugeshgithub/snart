// Copyright 2026 CognivexAI. Apache License 2.0.
import SwiftUI

/// Settings › 声音, the whole of interpreting in this build: the virtual mic (until it is
/// installed), which of English and French is yours, the talk key or hands-free, and the user's
/// own ElevenLabs voice.
struct VoiceSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var installer: VirtualMicInstaller

    @State private var key = ""
    @State private var voice = ElevenLabs.voice ?? ""
    /// Bumped on save so the card reads the stored key again.
    @State private var version = 0
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.virtualMic == nil {
                SettingsCard { MicSetupCard(installer: installer, deviceName: nil) }
            }
            SettingsCard {
                SettingsRow(title: "I speak", detail: "You read this, and speak it") {
                    PillMenu(value: Self.name(model.myCode), options: Self.languages) { model.setLanguages(mine: $0, theirs: model.theirCode) }
                }
                SettingsRow(title: "They speak", detail: tamilNote ?? "They hear you in this, in your voice") {
                    PillMenu(value: Self.name(model.theirCode), options: Self.languages) { model.setLanguages(mine: model.myCode, theirs: $0) }
                }
                SettingsRow(title: "Hold to talk") { ShortcutField(model: model, role: .talk) }
                SettingsRow(title: "Try a sentence", detail: "Say one line and hear what they will hear, before a call") {
                    SoftButton("Try") { model.speakTestShown = true }
                        .disabled(model.virtualMic == nil)
                }
                SettingsRow(title: "Hands-free", detail: "No key: it speaks for you after a short pause. Best with headphones.",
                            divider: false) {
                    Toggle("Hands-free", isOn: $settings.speakHandsFree)
                        .toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Palette.brand)
                }
            }
            Text("ElevenLabs").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                .padding(.top, 4)
            SettingsCard { eleven }
        }
        .sheet(isPresented: $model.speakTestShown) {
            SpeakTestView(model: model, tester: model.speakTester) {
                if model.speakTester.busy { model.speakTester.cancel() }
                model.speakTestShown = false
            }
        }
    }

    static let languages = sourceLanguages.map { ($0.code, $0.name) }
    static func name(_ code: String) -> String { sourceLanguages.first { $0.code == code }?.name ?? code }

    /// Tamil can't be heard on the Mac: ElevenLabs does it, so it needs the key below.
    private var tamilNote: String? {
        guard [model.myCode, model.theirCode].contains("ta") else { return nil }
        return ElevenLabs.configured && version >= 0 ? "Tamil is heard by ElevenLabs" : "Tamil needs your ElevenLabs key below"
    }

    private var eleven: some View {
        let ready = ElevenLabs.configured && version >= 0
        let changed = !key.isEmpty || voice.trimmingCharacters(in: .whitespaces) != (ElevenLabs.voice ?? "")
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(ready ? Palette.ok : Palette.placeholder).frame(width: 7, height: 7)
                Text(ready ? L("对方听到你自己的声音") : L("填好 key 和 Voice ID，对方就听到你的声音"))
                    .font(.system(size: 13)).foregroundStyle(Palette.ink)
                Spacer()
                if ready {
                    SoftButton(model.previewing == ElevenLabs.id ? L("播放中…") : L("试听")) {
                        model.previewVoice(ElevenLabs.id, language: model.theirCode)
                    }
                    .disabled(model.previewing != nil)
                }
            }
            HStack(spacing: 10) {
                Text("API key").font(.system(size: 12)).foregroundStyle(Palette.secondary).frame(width: 64, alignment: .leading)
                SecureField(ready ? L("已保存 · 留空则不变") : "sk_…", text: $key)
            }
            HStack(spacing: 10) {
                Text("Voice ID").font(.system(size: 12)).foregroundStyle(Palette.secondary).frame(width: 64, alignment: .leading)
                TextField("Voice ID of your clone", text: $voice)
            }
            HStack {
                if saved && !changed { Text("已保存").font(.system(size: 12)).foregroundStyle(Palette.secondary) }
                Spacer()
                SoftButton(L("保存"), dark: true) {
                    guard ElevenLabs.save(key: key, voice: voice) else { return }
                    key = ""
                    version += 1
                    saved = true
                    model.setVoiceEverywhere(ElevenLabs.id, also: "fr")
                }
                .disabled(!changed || voice.trimmingCharacters(in: .whitespaces).isEmpty || (!ready && key.isEmpty))
            }
        }
        .textFieldStyle(.roundedBorder).font(.system(size: 13))
        .padding(16)
    }
}
