import Foundation

/// Claude through Anthropic's Messages API (`POST /v1/messages`, raw HTTP: there is no Anthropic
/// SDK for Swift). `LingClient` builds every request as a chat completion; this turns one into a
/// Messages request and the answer back, so translation, notes and checks need no second path.
enum Anthropic {
    static func serves(_ url: URL?) -> Bool { url?.host == "api.anthropic.com" }

    /// Models that take the server-side fallback on a refusal (Opus 5.5 and up).
    private static func fallsBack(_ model: String) -> Bool { model.hasPrefix("claude-opus-5-5") }

    static func beta(for req: URLRequest) -> String? {
        guard req.httpMethod == "POST", let body = req.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              json["fallbacks"] != nil else { return nil }
        return "server-side-fallback-2026-07-01"
    }

    /// System messages become `system`; JSON mode becomes an instruction (Claude answers JSON when
    /// asked). Sampling and thinking switches are left out: current models refuse them, and the
    /// least effort keeps a live translation quick.
    static func messages(from chat: [String: Any]) -> [String: Any] {
        let model = chat["model"] as? String ?? "claude-opus-5-5"
        var system: [String] = []
        var turns: [[String: Any]] = []
        for m in chat["messages"] as? [[String: Any]] ?? [] {
            let role = m["role"] as? String ?? "user"
            let text: String
            if let s = m["content"] as? String { text = s }
            else { text = (m["content"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }.joined(separator: "\n") }
            if role == "system" { system.append(text) } else { turns.append(["role": role == "assistant" ? "assistant" : "user", "content": text]) }
        }
        if turns.first?["role"] as? String != "user" { turns.insert(["role": "user", "content": "Go."], at: 0) }
        if (chat["response_format"] as? [String: Any])?["type"] as? String == "json_object" {
            system.append("Reply with one JSON object only, no prose and no code fence.")
        }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": chat["max_tokens"] as? Int ?? chat["max_completion_tokens"] as? Int ?? 1024,
            "messages": turns,
            "output_config": ["effort": "low"],
        ]
        if !system.isEmpty { body["system"] = system.joined(separator: "\n\n") }
        if fallsBack(model) { body["fallbacks"] = "default" }
        return body
    }

    /// The answer's text as a chat completion (`choices[0].message.content`, `finish_reason`, usage).
    /// A refusal has no text to give: it fails like an unreadable answer and the caller falls back.
    static func completion(from root: [String: Any]) throws -> [String: Any] {
        let stop = root["stop_reason"] as? String
        if stop == "refusal" {
            debugLog("anthropic: refused (\((root["stop_details"] as? [String: Any])?["category"] as? String ?? "?"))")
            throw LingClient.Failure.parse
        }
        let text = (root["content"] as? [[String: Any]] ?? [])
            .filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        let usage = root["usage"] as? [String: Any]
        return [
            "choices": [["message": ["role": "assistant", "content": text],
                         "finish_reason": stop == "max_tokens" ? "length" : "stop"]],
            "usage": ["prompt_tokens": usage?["input_tokens"] as? Int ?? 0, "completion_tokens": usage?["output_tokens"] as? Int ?? 0],
        ]
    }
}
