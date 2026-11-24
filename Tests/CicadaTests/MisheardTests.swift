// Copyright 2026 CognivexAI. Apache License 2.0.
import Testing
@testable import Cicada

@Suite @MainActor struct MisheardTests {
    @Test func tamilHeardAsEnglishIsCaught() {
        #expect(SpeakEngine.looksMisheard("Now, like, client, the proposal, Anupidalama, Bagge, konjum, kami, pannanum.", language: "en"))
    }

    @Test func realSentencesPassEvenWithNames() {
        #expect(!SpeakEngine.looksMisheard("Thanks everyone, let's approve the budget before Friday.", language: "en"))
        #expect(!SpeakEngine.looksMisheard("Mugesh will send the Snart proposal to Pondicherry tomorrow.", language: "en"))
        #expect(!SpeakEngine.looksMisheard("Merci à tous, je vous envoie le contrat signé demain matin.", language: "fr"))
        #expect(!SpeakEngine.looksMisheard("Sounds good.", language: "en"))
    }
}
