// Copyright 2026 CognivexAI. Apache License 2.0.
namespace Cicada.App;

/// Hands-free on Windows (the Mac's SpeakEngine hands-free): while a meeting is listened to, the
/// mic runs through Windows' echo cancellation, HandsFreeDetector finds each sentence, and the
/// sentence is interpreted as a press would be. Runs on its own thread; `send` gets 16 kHz mono.
sealed class HandsFreeMic
{
    readonly EchoMic mic;
    readonly HandsFreeDetector detector = new();
    readonly Action began;
    readonly Action<short[], bool> send;
    readonly Thread thread;
    volatile bool running = true;
    /// Audio from before the detector is sure: the onset and the first syllable's rise.
    const int PreRoll = 16000 * 3 / 10;
    const int Block = 160; // 10 ms

    public string? Error => mic.Error;

    public HandsFreeMic(string micId, string? reference, Action began, Action<short[], bool> send)
    {
        this.began = began;
        this.send = send;
        mic = new EchoMic(micId, reference);
        mic.Start();
        thread = new Thread(Run) { IsBackground = true, Name = "HandsFree" };
        if (mic.Error is null) thread.Start();
        Log.Debug(mic.Error is null ? $"hands-free: listening ({mic.Detail})" : $"hands-free: mic failed {mic.Error}");
    }

    public void Stop()
    {
        running = false;
        if (thread.IsAlive) thread.Join(1000);
        mic.Stop();
        Log.Debug("hands-free: stopped");
    }

    void Run()
    {
        var recent = new List<short>();
        List<short>? sentence = null;
        var carry = new List<short>();
        while (running)
        {
            Thread.Sleep(50);
            carry.AddRange(mic.Take());
            var at = 0;
            for (; at + Block <= carry.Count; at += Block)
            {
                var block = carry.GetRange(at, Block).ToArray();
                if (sentence is not null) sentence.AddRange(block);
                else
                {
                    recent.AddRange(block);
                    if (recent.Count > PreRoll) recent.RemoveRange(0, recent.Count - PreRoll);
                }
                switch (detector.Feed(HandsFreeDetector.Rms(block), Block / 16000.0))
                {
                    case HandsFreeDetector.Event.Began:
                        sentence = [.. recent];
                        recent.Clear();
                        Log.Debug("hands-free: voice began");
                        began();
                        break;
                    case HandsFreeDetector.Event.Ended:
                    case HandsFreeDetector.Event.Cut:
                        if (sentence is { } done)
                        {
                            Log.Debug($"hands-free: sentence of {done.Count / 16000.0:F1} s");
                            send([.. done], mic.EchoCancelled);
                        }
                        sentence = detector.Talking ? [] : null;
                        break;
                }
            }
            carry.RemoveRange(0, at);
        }
    }
}
