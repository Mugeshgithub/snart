// Copyright 2026 CognivexAI. Apache License 2.0.
using System.Net;
using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;

namespace Cicada;

/// ElevenLabs, as on the Mac (ElevenLabs.swift): Scribe hears every stretch of speech (Windows has
/// no on-device recognizer that covers Tamil), and the user's cloned voice speaks the translations.
/// The key is a DPAPI-sealed file like the AI service's (`ai-key-elevenlabs`, read through AIKey
/// by the app); the voice id is no secret and lives in settings.
public sealed class ElevenLabsClient(Func<string?> key, Func<string?> voice, HttpMessageHandler? handler = null)
{
    public const string Service = "elevenlabs";
    /// Multilingual over Flash: a clone speaking another language sounded rough on Flash.
    public const string VoiceModel = "eleven_multilingual_v2";
    public const string HearModel = "scribe_v1";
    static readonly Uri Api = new("https://api.elevenlabs.io/v1/");

    readonly HttpClient http = handler is null ? new HttpClient() : new HttpClient(handler);

    public string? Key => string.IsNullOrWhiteSpace(key()) ? null : key()!.Trim();
    public string? Voice => string.IsNullOrWhiteSpace(voice()) ? null : voice()!.Trim();
    public bool CanHear => Key is not null;
    public bool CanSpeak => Key is not null && Voice is not null;

    /// The text of a 16 kHz mono WAV. `language` (ISO 639-1, "ta") pins what Scribe listens for:
    /// the pair is chosen, and a pinned language keeps a short or accented stretch from flipping.
    public async Task<string> Transcribe(byte[] wav, string? language, CancellationToken cancel = default)
    {
        if (Key is not { } key) throw new LingException(LingException.Kind.NoKey);
        using var form = new MultipartFormDataContent("snart-" + Guid.NewGuid().ToString("N"));
        form.Add(new StringContent(HearModel), "model_id");
        if (!string.IsNullOrEmpty(language)) form.Add(new StringContent(Code(language)), "language_code");
        form.Add(new StringContent("false"), "tag_audio_events");
        var file = new ByteArrayContent(wav);
        file.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        form.Add(file, "file", "speech.wav");
        using var req = new HttpRequestMessage(HttpMethod.Post, new Uri(Api, "speech-to-text")) { Content = form };
        req.Headers.Add("xi-api-key", key);
        var started = DateTime.UtcNow;
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancel);
        timeout.CancelAfter(TimeSpan.FromSeconds(15));
        HttpResponseMessage res;
        try { res = await http.SendAsync(req, timeout.Token); }
        catch (OperationCanceledException) when (!cancel.IsCancellationRequested) { throw new LingException(LingException.Kind.Timeout); }
        catch (HttpRequestException) { throw new LingException(LingException.Kind.Network); }
        using (res)
        {
            var body = await res.Content.ReadAsStringAsync(cancel);
            if (res.StatusCode != HttpStatusCode.OK)
            {
                // Its error JSON says why (quota_exceeded, voice_not_found); it never carries the key.
                Log.Debug($"elevenlabs stt: HTTP {(int)res.StatusCode} {Clip(body)}");
                throw Failure(res.StatusCode);
            }
            var text = ParseText(body) ?? throw new LingException(LingException.Kind.Parse);
            Log.Debug($"elevenlabs stt: {Math.Max(0, wav.Length - 44) / 32000.0:F1} s of audio heard in {(DateTime.UtcNow - started).TotalSeconds:F2} s");
            return text;
        }
    }

    /// The voice saying `text`: 24 kHz mono 16-bit PCM, handed on in 0.1 s pieces as it arrives.
    public async IAsyncEnumerable<byte[]> Speech(string text, [EnumeratorCancellation] CancellationToken cancel = default)
    {
        if (Key is not { } key || Voice is not { } v) throw new LingException(LingException.Kind.NoKey);
        var body = JsonSerializer.Serialize(new Dictionary<string, string> { ["text"] = text, ["model_id"] = VoiceModel });
        using var req = new HttpRequestMessage(HttpMethod.Post, new Uri(Api, $"text-to-speech/{Uri.EscapeDataString(v)}/stream?output_format=pcm_24000"))
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        };
        req.Headers.Add("xi-api-key", key);
        var started = DateTime.UtcNow;
        HttpResponseMessage res;
        try { res = await http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, cancel); }
        catch (HttpRequestException) { throw new LingException(LingException.Kind.Network); }
        using (res)
        {
            if (res.StatusCode != HttpStatusCode.OK)
            {
                Log.Debug($"elevenlabs: HTTP {(int)res.StatusCode} {Clip(await res.Content.ReadAsStringAsync(cancel))}");
                throw Failure(res.StatusCode);
            }
            await using var stream = await res.Content.ReadAsStreamAsync(cancel);
            var buffer = new byte[4800];
            var filled = 0;
            double? first = null;
            while (true)
            {
                var n = await stream.ReadAsync(buffer.AsMemory(filled), cancel);
                if (n == 0) break;
                filled += n;
                if (filled < buffer.Length) continue;
                first ??= (DateTime.UtcNow - started).TotalSeconds;
                yield return buffer.ToArray();
                filled = 0;
            }
            if (filled > 0) yield return buffer[..filled];
            Log.Debug($"elevenlabs: {text.Length} chars, first audio {first ?? (DateTime.UtcNow - started).TotalSeconds:F2} s");
        }
    }

    /// Opens the connection while the user is still talking, so the voice doesn't wait on a handshake.
    public void Warm()
    {
        if (!CanSpeak) return;
        _ = Task.Run(async () =>
        {
            try { using var _ = await http.SendAsync(new HttpRequestMessage(HttpMethod.Head, new Uri(Api, "models"))); } catch { }
        });
    }

    /// "ta-IN", "fr" → "ta", "fr": Scribe takes ISO 639-1.
    public static string Code(string language) => language.Split('-', '_')[0].ToLowerInvariant();

    public static string? ParseText(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.TryGetProperty("text", out var t) && t.ValueKind == JsonValueKind.String ? t.GetString()!.Trim() : null;
        }
        catch (JsonException) { return null; }
    }

    static LingException Failure(HttpStatusCode status) => status switch
    {
        HttpStatusCode.Unauthorized => new LingException(LingException.Kind.InvalidKey),
        HttpStatusCode.TooManyRequests => new LingException(LingException.Kind.RateLimited),
        _ => new LingException(LingException.Kind.Http, (int)status),
    };

    static string Clip(string s) => s.Length > 300 ? s[..300] : s;
}
