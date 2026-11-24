// Copyright 2026 CognivexAI. Apache License 2.0.
import Testing
@testable import Cicada

@Suite struct SpeechPartsTests {
    @Test func shortTextStaysWhole() {
        #expect(SpeechParts.split("We ship on Friday, as planned.") == ["We ship on Friday, as planned."])
    }

    @Test func aLongSentenceStartsWithItsFirstClause() {
        let text = "Thanks everyone for joining today, I wanted to walk through the quarterly numbers. Then we can talk about the hiring plan for next year."
        #expect(SpeechParts.split(text) == [
            "Thanks everyone for joining today,",
            "I wanted to walk through the quarterly numbers.",
            "Then we can talk about the hiring plan for next year.",
        ])
    }

    @Test func numbersAndAbbreviationsAreNoPause() {
        let text = "Revenue grew 3.5 percent to 1,000 units e.g. in Paris and Lyon and the rest of the regions this year"
        #expect(SpeechParts.split(text) == [text])
    }

    @Test func aShortTailJoinsThePartBeforeIt() {
        let text = "Thanks everyone for joining today, I wanted to walk through the quarterly numbers. Thanks."
        #expect(SpeechParts.split(text) == ["Thanks everyone for joining today,", "I wanted to walk through the quarterly numbers. Thanks."])
    }

    @Test func chineseIsCutAtItsOwnMarks() {
        let text = "谢谢大家今天来参加会议，我们先过一下这个季度的数字和明年的招聘计划。然后再讨论巴黎办公室的两个新岗位以及预算安排的细节问题和时间表。"
        #expect(SpeechParts.split(text).count == 2)
    }
}
