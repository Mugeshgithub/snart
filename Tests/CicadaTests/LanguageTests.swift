// Based on Cicada (https://github.com/wquguru/cicada), Apache License 2.0.
// Modified by CognivexAI, 2026.
import Testing
@testable import Cicada

@Suite struct LanguageTests {
    @Test(arguments: [
        ("zh-Hans-CN", "zh-CN"), ("zh-Hans-CA", "zh-CN"), ("zh-Hant-TW", "zh-TW"),
        ("zh-TW", "zh-TW"), ("zh-HK", "zh-TW"), ("zh-CN", "zh-CN"),
        ("en-CA", "en"), ("ja-JP", "ja"), ("pt-BR", "pt"),
    ])
    func systemLanguageMapsToTranslationCode(id: String, code: String) {
        #expect(translationCode(forSystemLanguage: id) == code)
    }

    @Test func cjkJoinsWithoutSpaces() {
        #expect(joiner(for: "zh-CN") == "")
        #expect(joiner(for: "ja") == "")
        #expect(joiner(for: "en") == " ")
    }

    private let english = sourceLanguages.first { $0.code == "en" }!

    @Test func detectionScoreFollowsConfidence() {
        let text = "hello there everyone"
        #expect(LanguageDetector.score(conf: 0.9, chars: text.count, text: text, lang: english) == 0.9)
        #expect(LanguageDetector.score(conf: 0.9, chars: 0, text: "", lang: english) == 0)
    }

    @Test func shortOutputCountsAsNoise() {
        #expect(LanguageDetector.score(conf: 0.9, chars: 3, text: "abc", lang: english) == 0.45)
    }

    @Test func snartsFiveLanguagesWithTamilHeardByTheService() {
        #expect(sourceLanguages.map(\.code) == ["en", "fr", "it", "de", "ta"])
        #expect(targetLanguages.map(\.code) == ["en", "fr", "it", "de", "ta"])
        #expect(sourceLanguages.filter(\.cloud).map(\.code) == ["ta"])
        // Tamil presses still run through a Mac model, whose words are dropped.
        #expect(sourceLanguages.first { $0.code == "ta" }?.recognizerLocale == "en-US")
        #expect(sourceLanguages.first { $0.code == "de" }?.recognizerLocale == "de-DE")
    }
}

@Suite struct FollowSystemTests {
    /// Whatever the Mac lists, English is read and French is the other side's.
    @Test(arguments: [["en-IN"], ["zh-Hans-CN"], ["fr-FR", "en-US"], [String]()])
    func englishAndFrenchOnly(prefs: [String]) {
        #expect(myLanguage(systemLanguages: prefs) == "en")
        #expect(followSystemTarget(source: "fr", systemLanguages: prefs) == "en")
        #expect(followSystemTarget(source: "en", systemLanguages: prefs) == "fr")
        #expect(followSystemTarget(source: nil, systemLanguages: prefs) == "en")
    }
}

