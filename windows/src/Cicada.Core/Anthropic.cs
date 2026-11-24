// Copyright 2026 CognivexAI. Apache License 2.0.
using System.Text.Json.Nodes;

namespace Cicada;

/// Claude through Anthropic's Messages API (`POST /v1/messages`, raw HTTP: there is no Anthropic
/// SDK without NuGet), as on the Mac (Anthropic.swift). LingClient builds every request as a chat
/// completion; this turns one into a Messages request and the answer back, so translation, notes
/// and checks need no second path.
public static class Anthropic
{
    public static bool Serves(Uri url) => url.Host == "api.anthropic.com";

    /// Models that take the server-side fallback on a refusal (Opus 5.5 and up).
    static bool FallsBack(string model) => model.StartsWith("claude-opus-5-5");

    public const string FallbackBeta = "server-side-fallback-2026-07-01";

    /// `…/v1/chat/completions` → `…/v1/messages`.
    public static Uri MessagesUrl(Uri chat) => new(chat.ToString().Replace("/chat/completions", "/messages"));

    /// System messages become `system`; JSON mode becomes an instruction (Claude answers JSON when
    /// asked). Sampling and thinking switches are left out: current models refuse them, and the
    /// least effort keeps a live translation quick.
    public static JsonObject Messages(JsonNode chat)
    {
        var model = chat["model"]?.GetValue<string>() ?? "claude-opus-5-5";
        var system = new List<string>();
        var turns = new JsonArray();
        foreach (var m in chat["messages"]?.AsArray() ?? [])
        {
            var role = m?["role"]?.GetValue<string>() ?? "user";
            var content = m?["content"];
            var text = content is JsonValue v ? v.GetValue<string>()
                : string.Join("\n", (content?.AsArray() ?? []).Select(p => p?["text"]?.GetValue<string>()).Where(t => t is not null));
            if (role == "system") system.Add(text);
            else turns.Add(new JsonObject { ["role"] = role == "assistant" ? "assistant" : "user", ["content"] = text });
        }
        if (turns.Count == 0 || turns[0]?["role"]?.GetValue<string>() != "user")
            turns.Insert(0, new JsonObject { ["role"] = "user", ["content"] = "Go." });
        if (chat["response_format"]?["type"]?.GetValue<string>() == "json_object")
            system.Add("Reply with one JSON object only, no prose and no code fence.");
        var max = (chat["max_tokens"] ?? chat["max_completion_tokens"])?.GetValue<int>() ?? 1024;
        var body = new JsonObject
        {
            ["model"] = model,
            ["max_tokens"] = max,
            ["messages"] = turns,
            ["output_config"] = new JsonObject { ["effort"] = "low" },
        };
        if (system.Count > 0) body["system"] = string.Join("\n\n", system);
        if (FallsBack(model)) body["fallbacks"] = "default";
        return body;
    }

    /// The answer's text as a chat completion (`choices[0].message.content`, `finish_reason`,
    /// usage). A refusal has no text to give: it fails like an unreadable answer and the caller
    /// falls back.
    public static JsonObject Completion(JsonNode root)
    {
        var stop = root["stop_reason"]?.GetValue<string>();
        if (stop == "refusal")
        {
            Log.Debug($"anthropic: refused ({root["stop_details"]?["category"]?.GetValue<string>() ?? "?"})");
            throw new LingException(LingException.Kind.Parse);
        }
        var text = string.Concat((root["content"]?.AsArray() ?? [])
            .Where(b => b?["type"]?.GetValue<string>() == "text")
            .Select(b => b?["text"]?.GetValue<string>() ?? ""));
        return new JsonObject
        {
            ["choices"] = new JsonArray(new JsonObject
            {
                ["message"] = new JsonObject { ["role"] = "assistant", ["content"] = text },
                ["finish_reason"] = stop == "max_tokens" ? "length" : "stop",
            }),
            ["usage"] = new JsonObject
            {
                ["prompt_tokens"] = root["usage"]?["input_tokens"]?.GetValue<int>() ?? 0,
                ["completion_tokens"] = root["usage"]?["output_tokens"]?.GetValue<int>() ?? 0,
            },
        };
    }
}
