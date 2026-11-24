// Copyright 2026 CognivexAI. Apache License 2.0.
namespace Cicada;

/// Hands-free interpreting, as on the Mac (HandsFree.swift, Cicada's HandsFreeDetector): the mic
/// all the time, a sentence from when your voice rises over the room's floor to `Hangover` of quiet
/// after it. Fed the mic block by block (~10 ms). A blip (a click, a cough) is not a start until it
/// has lasted `Onset`; a pause between words shorter than `Hangover` doesn't end the sentence.
public sealed class HandsFreeDetector
{
    public sealed record Tuning
    {
        /// Seconds of voice before a sentence starts (gaps under `Bridge` don't reset it).
        public double Onset { get; init; } = 0.1;
        public double Bridge { get; init; } = 0.15;
        /// Quiet that ends a sentence: 0.7 s keeps a conversation moving and still lets you breathe.
        public double Hangover { get; init; } = 0.7;
        /// A sentence is cut here; the next one starts at once.
        public double Longest { get; init; } = 20;
        /// The voice must be this many times the room's floor, and at least `Lowest`.
        public float Margin { get; init; } = 4;
        public float Lowest { get; init; } = 0.004f;
        /// Once talking, voice goes on down to this share of the line (a word's quiet ending isn't quiet).
        public float Hold { get; init; } = 0.5f;
        public static readonly Tuning Standard = new();
    }

    /// Ended(cut: true): `Longest` reached while still talking; the next sentence has begun.
    public enum Event { None, Began, Ended, Cut }

    readonly Tuning tuning;
    public bool Talking { get; private set; }
    public double Length { get; private set; }
    double voiced, gap, quiet;
    /// The quietest block of each of the last seconds: the room's floor.
    readonly List<float> quietest = [];
    float second = float.PositiveInfinity;
    double elapsed;

    public HandsFreeDetector(Tuning? tuning = null) { this.tuning = tuning ?? Tuning.Standard; }

    public float Floor => quietest.Count < 3 ? tuning.Lowest / tuning.Margin : quietest.OrderBy(x => x).ElementAt(quietest.Count / 5);
    public float Line => Math.Max(tuning.Lowest, Floor * tuning.Margin);

    /// Seconds of floor learned: nothing starts before 3 (a noisy room would read as a voice).
    public bool Ready => quietest.Count >= 3;

    public void Reset()
    {
        Talking = false;
        Length = 0; voiced = 0; gap = 0; quiet = 0;
    }

    public Event Feed(float rms, double seconds)
    {
        // Always learning: speech has a gap in every second, so a sentence doesn't raise the floor.
        Learn(rms, seconds);
        if (!Ready) return Event.None;
        if (!Talking)
        {
            if (rms >= Line) { voiced += seconds; gap = 0; }
            else
            {
                gap += seconds;
                if (gap > tuning.Bridge) voiced = 0;
            }
            if (voiced < tuning.Onset) return Event.None;
            Talking = true;
            Length = voiced; quiet = 0; voiced = 0; gap = 0;
            return Event.Began;
        }
        Length += seconds;
        quiet = rms >= Line * tuning.Hold ? 0 : quiet + seconds;
        if (quiet >= tuning.Hangover)
        {
            Reset();
            return Event.Ended;
        }
        if (Length >= tuning.Longest)
        {
            Length = 0;
            return Event.Cut;
        }
        return Event.None;
    }

    void Learn(float rms, double seconds)
    {
        second = Math.Min(second, rms);
        elapsed += seconds;
        if (elapsed < 1 - 1e-9) return;
        quietest.Add(second);
        if (quietest.Count > 10) quietest.RemoveAt(0);
        second = float.PositiveInfinity;
        elapsed = 0;
    }

    /// The RMS of 16-bit samples, 0–1.
    public static float Rms(ReadOnlySpan<short> block)
    {
        if (block.Length == 0) return 0;
        double sum = 0;
        foreach (var s in block) { var v = s / 32768.0; sum += v * v; }
        return (float)Math.Sqrt(sum / block.Length);
    }
}
