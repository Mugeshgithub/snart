# Cognivex Interpreter

A CognivexAI Mac app for calls between English and French speakers.

- **They speak French, you read English.** Live subtitles and meeting notes from whatever plays on your Mac (Zoom, Meet, Teams, a browser).
- **You speak English, they hear French in your own voice.** Hold the right ⌥ key, talk, let go. The translation is spoken into the call through the BlackHole virtual microphone, in your ElevenLabs voice clone.

## Setup

1. Build: `RELEASE=1 scripts/build.sh`, then copy `build/Cognivex Interpreter.app` to Applications.
2. Settings › **AI Service**: an OpenRouter key (or another provider) for translation and notes.
3. Settings › **Voice**: your ElevenLabs API key and Voice ID.
4. In your meeting app, choose **BlackHole 2ch** as the microphone.

Requires macOS 14.4+ on Apple silicon (speech recognition runs on the Mac).

## Credits

Based on [Cicada](https://github.com/wquguru/cicada) by wquguru, Apache License 2.0. See `LICENSE` and `NOTICE`.
