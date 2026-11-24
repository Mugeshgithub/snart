// Pure Foundation: the iOS app shares this file (ios/shared-sources.txt).
import Foundation

// MARK: - Languages

struct Lang: Equatable {
    let name: String
    /// Locale used by SpeechTranscriber.
    let locale: String
    /// Language code used by the translation endpoint.
    let code: String
}

// Snart's five languages. Tamil has no speech model on the Mac: ElevenLabs hears it (`Lang.cloud`).
let sourceLanguages: [Lang] = [
    .init(name: "English", locale: "en-US", code: "en"),
    .init(name: "French", locale: "fr-FR", code: "fr"),
    .init(name: "Italian", locale: "it-IT", code: "it"),
    .init(name: "German", locale: "de-DE", code: "de"),
    .init(name: "Tamil", locale: "ta-IN", code: "ta"),
]

let targetLanguages: [Lang] = [
    .init(name: "English", locale: "en", code: "en"),
    .init(name: "French", locale: "fr", code: "fr"),
    .init(name: "Italian", locale: "it", code: "it"),
    .init(name: "German", locale: "de", code: "de"),
    .init(name: "Tamil", locale: "ta", code: "ta"),
]

extension Lang {
    /// Heard by a service (ElevenLabs Scribe), not on the Mac.
    var cloud: Bool { code == "ta" }
    /// The Mac model a press still runs through when the language is heard by the service: its words
    /// are thrown away, it only keeps the press flowing (`SpeakEngine`).
    var recognizerLocale: String { cloud ? "en-US" : locale }
}

/// Maps a system language identifier ("zh-Hans-CA", "en-CA", "zh-TW") to a translation code.
func translationCode(forSystemLanguage id: String) -> String {
    let locale = Locale(identifier: id)
    let lang = locale.language.languageCode?.identifier ?? "en"
    guard lang == "zh" else { return lang }
    let script = locale.language.script?.identifier
    let region = locale.region?.identifier
    if script == "Hant" { return "zh-TW" }
    if script == nil, let region, ["TW", "HK", "MO"].contains(region) { return "zh-TW" }
    return "zh-CN"
}

/// The reader's own language under "follow system": Chinese when the system list has it (the
/// app speaks Chinese), otherwise the first system language. Subtitles, notes and speak-back
/// all start from this one answer, so they never disagree.
func myLanguage(systemLanguages prefs: [String]) -> String {
    // Snart: yours is the language you speak, whatever the Mac lists.
    let locale = UserDefaults.standard.string(forKey: "speakFrom")
    return sourceLanguages.first { $0.locale == locale }?.code ?? "en"
}

/// The language the other side speaks (the fixed source), or the one beside yours when unset.
func theirLanguage() -> String {
    let locale = UserDefaults.standard.string(forKey: "sourceMode")
    let mine = myLanguage(systemLanguages: [])
    if let code = sourceLanguages.first(where: { $0.locale == locale })?.code, code != mine { return code }
    return mine == "en" ? "fr" : "en"
}

/// What "follow system" translates into: my language, unless that is what they speak; then the
/// next system language, or between Chinese and English when the system has only one.
func followSystemTarget(source: String?, systemLanguages prefs: [String]) -> String {
    // English and French only: shown in yours, unless they speak it too; then in the other one.
    let mine = myLanguage(systemLanguages: prefs)
    return source == mine ? theirLanguage() : mine
}

/// The languages "auto" most likely hears, most likely first: the last one detected, the Mac's
/// own languages, then English. Detection compares two or more models, so a Mac with fewer
/// fetches the first ones of these it lacks; and they are what 听不出 offers to pick from.
func likelySourceLanguages(last: String?, systemLanguages prefs: [String]) -> [Lang] {
    var out: [Lang] = []
    func add(_ lang: Lang?) { if let lang, !out.contains(lang) { out.append(lang) } }
    add(sourceLanguages.first { $0.locale == last })
    for id in prefs {
        let code = translationCode(forSystemLanguage: id)
        // The only Chinese model listed is Mandarin (zh-CN); it hears Taiwanese Mandarin as well.
        add(sourceLanguages.first { $0.code == (code.hasPrefix("zh") ? "zh-CN" : code) })
    }
    add(sourceLanguages.first { $0.code == "en" })
    return out
}

/// The model auto starts with: the room's own language, else the last meeting's, else the
/// Mac's language before the remaining installed models. `candidates` is in `sourceLanguages`
/// order (English first), so taking `candidates.first` would start every fresh Mac in English.
func initialSourceLanguage(candidates: [Lang], last: String?, systemLanguages prefs: [String],
                           mine: Lang? = nil) -> Lang {
    if let mine { return mine }
    if let last, let lang = candidates.first(where: { $0.locale == last }) { return lang }
    let likely = likelySourceLanguages(last: last, systemLanguages: prefs)
    return likely.first(where: { candidates.contains($0) })
        ?? likely.first
        ?? candidates.first
        ?? sourceLanguages[0]
}

/// The speech locale to listen for when I speak my language (English when it isn't one we recognize).
func speakLocale(forLanguage code: String) -> String {
    if code.hasPrefix("zh") { return "zh-CN" }
    return sourceLanguages.first { $0.code == code }?.locale ?? "en-US"
}

func targetName(_ code: String) -> String {
    targetLanguages.first(where: { $0.code == code })?.name
        ?? Locale.current.localizedString(forIdentifier: code) ?? code
}

/// CJK text is joined without spaces.
func joiner(for code: String) -> String {
    (code.hasPrefix("zh") || code == "ja") ? "" : " "
}

