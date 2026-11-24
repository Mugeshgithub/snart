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
                SettingsRow(title: "I speak", detail: model.speaksFrench ? "You read French; they hear you in English"
                                                                         : "You read English; they hear you in French") {
                    Segments(options: [("en", "English"), ("fr", "French")], value: model.speaksFrench ? "fr" : "en") {
                        model.setSpeaksFrench($0 == "fr")
                    }
                    .fixedSize()
                }
                SettingsRow(title: "Hold to talk") { ShortcutField(model: model, role: .talk) }
                SettingsRow(title: "Hands-free", detail: "No key: it speaks for you after a short pause. Best with headphones.",
                            divider: false) {
                    Toggle("Hands-free", isOn: $settings.speakHandsFree)
                        .toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Palette.ink)
                }
            }
            Text("ElevenLabs").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
                .padding(.top, 4)
            SettingsCard { eleven }
        }
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
                        model.previewVoice(ElevenLabs.id, language: model.speaksFrench ? "en" : "fr")
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
                TextField("IjgHBy2HxC6Is60nxCjO", text: $voice)
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
