import Foundation

/// The user's own voice, cloned on elevenlabs.io, speaking translations into the room in place of
/// Ling's clone: Flash starts in a few hundred ms whatever the length, and one voice speaks every
/// language (Tamil too). The key lives in its 0600 file like the AI service's (`AIKey`); the voice
/// id is no secret.
enum ElevenLabs {
    /// Stored in `speakVoices` for each language it speaks.
    static let id = "eleven"
    static let model = "eleven_flash_v2_5"
    private static let service = "elevenlabs"

    static var key: String? { AIKey.read(service) }
    static var voice: String? {
        let v = UserDefaults.standard.string(forKey: "elevenVoice")?.trimmingCharacters(in: .whitespaces)
        return v?.isEmpty == false ? v : nil
    }
    static var configured: Bool { key != nil && voice != nil }

    /// A nil or empty `key` keeps the one saved.
    @discardableResult
    static func save(key: String?, voice: String) -> Bool {
        UserDefaults.standard.set(voice.trimmingCharacters(in: .whitespaces), forKey: "elevenVoice")
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return self.key != nil }
        return AIKey.save(key, service)
    }

    static func remove() {
        AIKey.remove(service)
        UserDefaults.standard.removeObject(forKey: "elevenVoice")
    }

    static var option: VoiceOption {
        VoiceOption(id: id, name: L("我的声音"), tags: ["ElevenLabs"], kind: .cloud("eleven"))
    }

    /// Opens the connection while you are still talking, so the voice's first chunk doesn't wait on a handshake.
    static func warm() {
        guard configured, let url = URL(string: "https://api.elevenlabs.io/v1/models") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 5
        Task { _ = try? await URLSession.shared.data(for: req) }
    }

    /// `text` as raw 24 kHz mono 16-bit PCM chunks, the format `SpeakEngine` plays a stream in.
    static func speech(_ text: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                guard let key, let voice,
                      var url = URLComponents(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voice)/stream")
                else { cont.finish(throwing: LingClient.Failure.noKey); return }
                url.queryItems = [URLQueryItem(name: "output_format", value: "pcm_24000")]
                var req = URLRequest(url: url.url!)
                req.httpMethod = "POST"
                req.timeoutInterval = 15
                req.setValue(key, forHTTPHeaderField: "xi-api-key")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text, "model_id": model])
                let started = Date()
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        // Its error JSON says why (quota_exceeded, voice_not_found); it never carries the key.
                        var detail = Data()
                        for try await b in bytes { detail.append(b); if detail.count >= 300 { break } }
                        debugLog("elevenlabs: HTTP \(status) \(String(decoding: detail, as: UTF8.self))")
                        throw status == 401 ? LingClient.Failure.invalidKey : LingClient.Failure.http(status)
                    }
                    // Handed on in 0.1 s pieces so playback starts with the first.
                    var chunk = Data()
                    chunk.reserveCapacity(4800)
                    var first: Double?
                    for try await b in bytes {
                        chunk.append(b)
                        if chunk.count >= 4800 {
                            if first == nil { first = Date().timeIntervalSince(started) }
                            cont.yield(chunk)
                            chunk.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunk.isEmpty { cont.yield(chunk) }
                    debugLog(String(format: "elevenlabs: %d chars, first audio %.2f s", text.count, first ?? Date().timeIntervalSince(started)))
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}
