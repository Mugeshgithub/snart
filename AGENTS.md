# AGENTS.md

Cognivex Interpreter is a CognivexAI Mac app: live English subtitles for a French call, and what you say in English spoken into the call in French in your own ElevenLabs voice. It is a fork of Cicada (wquguru/cicada, Apache-2.0); the Swift target and many comments still say Cicada or 知了, which is the code's history, not the product name.

## Scope

- Mac only (menu bar app). Settings show two pages: AI Service and Voice (`SettingsSection.simple`). Other pages stay in the code for what opens them, redirected by `SettingsSection.shown(for:)`.
- Languages are fixed: they speak French, you read English; you speak English, they hear French. Don't add language options unless asked.
- Nothing the user does needs the Terminal.

## Hard rules

- Keys live only in 0600 files (`AIKey`: the AI service's, and "elevenlabs"): never UserDefaults, logs or exports.
- Never speak untranslated text into the call. Never bundle the GPL BlackHole driver; download it and check its pinned SHA-256.
- Nothing talks to the original project's servers: no updates from wquguru/cicada, no Share (cicada.indaloop.app).
- Keep LICENSE and NOTICE, and the "Based on Cicada" line in the About panel (Apache-2.0).
- Bundle id `eu.cognivexai.interpreter`; its designated requirement is the bundle id alone, so rebuilds keep permissions.
- No third-party dependencies. Command Line Tools only, no `.xcodeproj`.
- UI and engine state are `@MainActor`; audio callbacks hand buffers to `AudioRouter`'s queue.

## Design

- Calm and minimal: few controls, short English copy, at most one grey helper line. Chinese text is the localization key; `Resources/en.lproj` holds the English the user sees. After changing UI text run `python3 scripts/strings.py --write` and fill the TODOs.
- Brand: the CognivexAI rings (blue outer, orange inner, white core) on navy, drawn in `CicadaLogo` (`Onboarding.swift`) and `Sources/CicadaIcon`; keep the two in step.

## Layout

- `Sources/Cicada`: the app, one concern per file. Engines are UI-free (`ListenEngine`, `SpeakEngine`, `Translator`, `Ling`…); `AppModel` wires them. Settings keys: `AppSettings` in `Settings.swift`.
- `ElevenLabs.swift`: the voice; `VoiceSettings.swift`: the Voice page; `Migration.swift`: first launch takes over an old Cicada install's settings and folder.
- `Tests/CicadaTests`: unit tests for the pure parts. `tools/`: debug helpers (`tools/README.md`).

## Commands

```bash
scripts/test.sh                                   # AGENTS.md check + unit tests
scripts/build.sh && open "build/Cognivex Interpreter.app"   # dev build: own bundle id, settings, log
RELEASE=1 scripts/build.sh                        # the real app
```

## Verifying

- Run the app and check the behaviour, not just the build. Drive the dev build with `tools/lsctl`; render settings with `lsctl settingsRender:<ai|voice>=<png>`; the dev log is `/tmp/cognivex-interpreter-dev-debug.log`.
- A real voice, the BlackHole install and permissions need a person.

## Conventions

- Match the existing naming and comment density; comments say why.
- English Conventional Commits (`feat:` `fix:` `refactor:` `docs:` `build:` `test:` `chore:`), one change per commit.
- Versions in `VERSION`, read by every build.
