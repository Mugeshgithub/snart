# Snart

A CognivexAI Mac app for calls across English, French, Italian, German and Tamil.

- **They speak one language, you read yours.** Live subtitles and meeting notes from whatever plays on your Mac (Zoom, Meet, Teams, a browser). Pick the pair in the window: any two of English, French, Italian, German and Tamil.
- **You speak yours, they hear theirs in your own voice.** Hold the right ⌥ key (or turn on hands-free), talk, let go. The translation is spoken into the call through the BlackHole virtual microphone, in your ElevenLabs voice clone, about a second after you stop.
- English, French, Italian and German are recognised on the Mac; Tamil is recognised by ElevenLabs.

## Setup

1. Build: `RELEASE=1 scripts/build.sh`, then copy `build/Snart.app` to Applications.
2. Settings › **AI Service**: an OpenRouter key (or another provider) for translation and notes.
3. Settings › **Voice**: your languages, and your ElevenLabs API key and Voice ID.
4. In your meeting app, choose **BlackHole 2ch** as the microphone.

Requires macOS 14.4+ on Apple silicon (speech recognition runs on the Mac).

## Credits

Based on [Cicada](https://github.com/wquguru/cicada) by wquguru, Apache License 2.0. See `LICENSE` and `NOTICE`.
