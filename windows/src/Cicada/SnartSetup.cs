// Copyright 2026 CognivexAI. Apache License 2.0.
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Cicada.App;

/// Snart's first-run setup, as on the Mac (SnartSetup.swift): one glass card, six steps. Welcome,
/// hearing the call, the language pair, the AI and ElevenLabs keys, the virtual microphone, done.
/// Each step can be skipped; settings hold the same choices later.
sealed class SnartSetup : Window
{
    static readonly string[] Steps = ["Welcome", "Hearing", "Languages", "Keys", "Voice out", "Done"];
    static readonly SolidColorBrush Blue = new(Color.FromRgb(0x3B, 0x82, 0xF6));
    // Nearly opaque: WPF can't blur what is behind, as the Mac's glass does.
    static readonly SolidColorBrush Glass = new(Color.FromArgb(0xFC, 0xF7, 0xF9, 0xFC));
    static readonly SolidColorBrush Card = new(Color.FromArgb(0xE6, 0xFF, 0xFF, 0xFF));
    static readonly SolidColorBrush Ok = new(Color.FromRgb(0x1F, 0x9D, 0x55));

    readonly Controller app;
    readonly Action finished;
    readonly ContentControl page = new(), dots = new(), foot = new();
    readonly PasswordBox aiKey = new(), elevenKey = new();
    readonly TextBox elevenVoice = new();
    string? note;
    int step;

    public SnartSetup(Controller app, Action finished)
    {
        this.app = app;
        this.finished = finished;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        FontFamily = Palette.Font;
        Title = "Snart setup";
        Width = 460 + 2 * Ui.ShadowRoom;
        Height = 540 + 2 * Ui.ShadowRoom;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Icon = AppIcon.Image;
        MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed && e.OriginalSource is not TextBox and not PasswordBox) try { DragMove(); } catch { } };
        elevenVoice.Text = app.Settings.ElevenVoice;

        var head = new DockPanel { Margin = new Thickness(0, 0, 0, 22) };
        var close = Ui.IconButton(Icons.Close, "Close (set up later in Settings)", Close, Palette.Secondary, 26, 12);
        DockPanel.SetDock(close, Dock.Right);
        head.Children.Add(close);
        DockPanel.SetDock(dots, Dock.Right);
        dots.Margin = new Thickness(0, 0, 8, 0);
        dots.VerticalAlignment = VerticalAlignment.Center;
        head.Children.Add(dots);
        head.Children.Add(Ui.Row(8, AppIcon.Small(18), Ui.Text("Snart", 13, Palette.Ink, FontWeights.SemiBold, wrap: false)));

        var root = new DockPanel { Margin = new Thickness(24) };
        DockPanel.SetDock(head, Dock.Top);
        DockPanel.SetDock(foot, Dock.Bottom);
        root.Children.Add(head);
        root.Children.Add(foot);
        root.Children.Add(page);
        Content = Ui.Floating(root, Glass, 30);
        Render();
    }

    public void Go(int to) { step = Math.Clamp(to, 0, Steps.Length - 1); note = null; Render(); }

    void Render()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        for (var i = 0; i < Steps.Length; i++)
            row.Children.Add(new Border { Width = i == step ? 14 : 5, Height = 5, CornerRadius = new CornerRadius(2.5), Margin = new Thickness(0, 0, 5, 0), Background = i == step ? Blue : new SolidColorBrush(Color.FromArgb(0x26, 0x15, 0x17, 0x1C)) });
        dots.Content = row;
        page.Content = step switch { 0 => Welcome(), 1 => Hearing(), 2 => Pair(), 3 => Keys(), 4 => VoiceOut(), _ => Done() };
        var bar = new DockPanel();
        if (step is > 0 and < 5)
        {
            var back = Ui.LinkText("Back", () => Go(step - 1));
            back.Foreground = Palette.Secondary; back.VerticalAlignment = VerticalAlignment.Center;
            DockPanel.SetDock(back, Dock.Left);
            bar.Children.Add(back);
        }
        var next = step < 5 ? Primary(step == 0 ? "Set up Snart" : "Continue", () => Go(step + 1)) : Primary("Open Snart", Finish);
        next.HorizontalAlignment = HorizontalAlignment.Right;
        bar.Children.Add(next);
        foot.Content = bar;
    }

    void Finish()
    {
        app.Settings.Onboarded = true;
        app.Settings.Save();
        Close();
        finished();
    }

    // MARK: Steps

    UIElement Welcome() => Stack(18,
        Left(AppIcon.Small(56)),
        Stack(6, Big("Talk across languages,\nin your own voice.", 26), Ui.Text("Snart sits beside your call as a small bubble.", 13, Palette.Secondary)),
        Stack(10,
            Point(Icons.Subtitles, "They speak, you read it in your language."),
            Point(Icons.Wave, "You speak, they hear it in theirs, in your voice."),
            Point(Icons.Globe, "English, French, Italian, German and Tamil.")));

    UIElement Hearing()
    {
        var mic = Endpoints.Microphone();
        return Stack(16, Heading("Let Snart hear the call", "Sound from your PC becomes your subtitles. Only sound, never the screen."),
            CardOf(
                Row(Icons.Speaker, "Your PC's sound", "What the other side says. Windows needs no permission", Tick()),
                Line(),
                Row(Icons.Mic, "Microphone", mic is null ? "No microphone found: plug in a headset" : $"{mic.Name}, while you talk",
                    mic is null ? Ui.Text("Missing", 12, Palette.Danger, wrap: false) : Tick())));
    }

    UIElement Pair()
    {
        var s = app.Settings;
        var langs = Languages.Sources.Select(l => (l.Code, l.Name)).ToList();
        var how = Ui.Segmented([("hold", $"Hold {PushToTalk.Label}"), ("free", "Hands-free")], s.HandsFree ? "free" : "hold", v => { app.SetHandsFree(v == "free"); Render(); });
        return Stack(16, Heading("Your languages", "Change them any time from the bubble."),
            CardOf(
                Row(Icons.Subtitles, "I speak", "You read this, and talk in it", Ui.Choice(langs, s.Mine, v => { app.SetLanguages(v, s.Theirs); Render(); }, 140)),
                Line(),
                Row(Icons.Globe, "They speak", "They hear you in this", Ui.Choice(langs, s.Theirs, v => { app.SetLanguages(s.Mine, v); Render(); }, 140)),
                Line(),
                Row(Icons.Keyboard, "How you talk", s.HandsFree ? "Just talk; it speaks after a short pause" : $"Hold {PushToTalk.Label} while you speak", how)));
    }

    UIElement Keys()
    {
        var s = app.Settings;
        var providers = AIProvider.All.Where(p => p.Id != "custom").Select(p => (p.Id, p.Name));
        var choose = Ui.Segmented(providers, s.AiProvider, v => { app.SetAIProvider(v); Render(); });
        var hint = s.AiProvider switch { "anthropic" => "sk-ant-…", "openrouter" => "sk-or-…", _ => "sk-…" };
        var aiSaved = app.Ling.HasKey;
        var elevenSaved = app.Eleven.CanSpeak;
        var ai = Stack(10,
            Ui.Spread(Ui.Text("Translation and notes", 13, Palette.Ink, FontWeights.SemiBold, wrap: false), aiSaved ? Tick() : new Border()),
            choose,
            Ui.Row(8, Field(aiKey, aiSaved ? "Saved · paste to replace" : hint, 250), Secondary("Save", SaveAi)));
        var voice = Stack(10,
            Ui.Spread(Ui.Text("Your voice · ElevenLabs", 13, Palette.Ink, FontWeights.SemiBold, wrap: false), elevenSaved ? Tick() : new Border()),
            Field(elevenKey, elevenSaved ? "Saved · paste to replace" : "ElevenLabs API key", 330),
            Ui.Row(8, Field(elevenVoice, "Voice ID of your clone", 250), Secondary("Save", SaveEleven)));
        ai.Margin = voice.Margin = new Thickness(14);
        var stack = Stack(14, Heading("Your keys", "Stored only on this PC. You can add them later in Settings."), CardOf(ai, Line(), voice));
        if (note is not null) stack.Children.Add(Ui.Text(note, 12, Palette.Secondary));
        return stack;
    }

    void SaveAi()
    {
        var k = aiKey.Password.Trim();
        if (k.Length == 0) return;
        aiKey.Clear();
        if (AICheck.Owner(k) is { } whose && !whose.Management && whose.Service != app.Settings.AiProvider && AIProvider.All.Any(p => p.Id == whose.Service))
            note = $"That's a {AIProvider.Named(whose.Service).Name} key: switched to {AIProvider.Named(whose.Service).Name}.";
        app.SwitchService(AICheck.Owner(k) is { Management: false } w && AIProvider.All.Any(p => p.Id == w.Service) ? w.Service : app.Settings.AiProvider, k);
        _ = app.Ling.Check();
        Render();
    }

    void SaveEleven()
    {
        if (elevenVoice.Text.Trim().Length == 0 || (!app.Eleven.CanHear && elevenKey.Password.Trim().Length == 0)) return;
        app.SaveElevenLabs(elevenKey.Password, elevenVoice.Text);
        elevenKey.Clear();
        Render();
    }

    UIElement VoiceOut()
    {
        if (!app.Settings.Speak) { app.Settings.Speak = true; app.Settings.Save(); app.SettingsChanged(); }
        var cable = Endpoints.Cable() is not null;
        var theirs = Ui.TargetName(app.Settings.Theirs);
        return Stack(16, Heading("So they hear you", "Snart speaks into a virtual microphone, VB-Cable. Your call app listens to it like a mic."),
            CardOf(
                cable ? Row(Icons.Check, "VB-Cable is ready", "In Zoom, Meet or Teams, choose CABLE Output as the microphone", Tick())
                      : Row(Icons.Mic, "Install VB-Cable", note ?? "Free, from VB-Audio. Windows asks you to confirm", Secondary("Install", () => _ = InstallCable())),
                Line(),
                Row(Icons.Play, "Hear your voice", $"A sample line in {theirs}, in your voice, on your speakers", Secondary("Play", () => _ = app.Preview(app.Settings.Theirs)))));
    }

    async Task InstallCable()
    {
        note = "Downloading…";
        Render();
        var result = await CableInstaller.Install(p => Dispatcher.BeginInvoke(() => { note = p; Render(); }));
        note = result == CableInstaller.Result.Installed ? null : "Didn't install. Try again, or install it from Settings › Interpreting";
        Render();
    }

    UIElement Done()
    {
        var check = Ui.Icon(Icons.Check, 40, Blue, stroke: 2.4);
        check.HorizontalAlignment = HorizontalAlignment.Left;
        return Stack(16, check, Big("You're set.", 26),
            Stack(10,
                Point(Icons.Power, "Click Snart in the taskbar corner, then Start listening."),
                Point(Icons.Mic, "Then start the call, with CABLE Output as its microphone."),
                Point(Icons.Keyboard, app.Settings.HandsFree ? "Talk. They hear you after a short pause." : $"Hold {PushToTalk.Label} while you talk.")));
    }

    // MARK: Pieces

    static StackPanel Stack(double gap, params UIElement[] children)
    {
        var s = new StackPanel();
        for (var i = 0; i < children.Length; i++)
        {
            if (i > 0 && children[i] is FrameworkElement f && f.Margin == default) f.Margin = new Thickness(0, gap, 0, 0);
            s.Children.Add(children[i]);
        }
        return s;
    }

    static FrameworkElement Left(FrameworkElement e) { e.HorizontalAlignment = HorizontalAlignment.Left; return e; }

    static TextBlock Big(string text, double size) => Ui.Text(text, size, Palette.Ink, FontWeights.SemiBold);

    static UIElement Heading(string title, string detail) => Stack(6, Big(title, 22), Ui.Text(detail, 12.5, Palette.Secondary));

    static UIElement Point(string icon, string text) => Ui.Row(10, Ui.Icon(icon, 14, Blue), Ui.Text(text, 13, Palette.Ink));

    static Border CardOf(params UIElement[] rows)
    {
        var s = new StackPanel();
        foreach (var r in rows) s.Children.Add(r);
        return new Border { Background = Card, CornerRadius = new CornerRadius(18), BorderBrush = new SolidColorBrush(Color.FromArgb(0xE6, 0xFF, 0xFF, 0xFF)), BorderThickness = new Thickness(0.8), Child = s };
    }

    static UIElement Line() => new Border { Height = 1, Background = new SolidColorBrush(Color.FromArgb(0x14, 0x15, 0x17, 0x1C)), Margin = new Thickness(14, 0, 14, 0) };

    static UIElement Row(string icon, string title, string detail, UIElement trailing)
    {
        var text = Stack(2, Ui.Text(title, 13, Palette.Ink, FontWeights.SemiBold), Ui.Text(detail, 11, Palette.Secondary));
        var row = new DockPanel { Margin = new Thickness(14, 11, 14, 11) };
        var i = Ui.Icon(icon, 15, Blue);
        i.Margin = new Thickness(0, 2, 12, 0); i.VerticalAlignment = VerticalAlignment.Top;
        DockPanel.SetDock(i, Dock.Left);
        row.Children.Add(i);
        if (trailing is FrameworkElement t) { t.VerticalAlignment = VerticalAlignment.Center; t.Margin = new Thickness(10, 0, 0, 0); }
        DockPanel.SetDock(trailing, Dock.Right);
        row.Children.Add(trailing);
        row.Children.Add(text);
        return row;
    }

    static FrameworkElement Tick() => Ui.Icon(Icons.Check, 16, Ok, stroke: 2.2);

    static Button Primary(string label, Action click)
    {
        var b = Ui.Button(label, click, Ui.Kind.Primary, height: 36);
        b.MinWidth = 120;
        return b;
    }

    static Button Secondary(string label, Action click) => Ui.Button(label, click, Ui.Kind.Standard, height: 30);

    static FrameworkElement Field(Control box, string hint, double width)
    {
        var f = Ui.Field(box);
        f.Width = width; f.Height = 34;
        var placeholder = Ui.Text(hint, 12, Palette.Tertiary, wrap: false);
        placeholder.IsHitTestVisible = false;
        placeholder.Margin = new Thickness(12, 0, 0, 0);
        placeholder.VerticalAlignment = VerticalAlignment.Center;
        void Show() => placeholder.Visibility = box switch
        {
            PasswordBox p => p.Password.Length == 0 ? Visibility.Visible : Visibility.Collapsed,
            TextBox t => t.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed,
            _ => Visibility.Collapsed,
        };
        if (box is PasswordBox pb) pb.PasswordChanged += (_, _) => Show();
        if (box is TextBox tb) tb.TextChanged += (_, _) => Show();
        Show();
        System.Windows.Automation.AutomationProperties.SetName(box, hint);
        return new Grid { HorizontalAlignment = HorizontalAlignment.Left, Children = { f, placeholder } };
    }
}
