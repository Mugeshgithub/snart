// Copyright 2026 CognivexAI. Apache License 2.0.
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace Cicada.App;

/// Snart's bubble, as on the Mac (LiveWindow.swift): a small floating drop beside the call. The
/// pair (EN ⇄ FR, click to swap), the last lines (theirs translated, yours as they heard it), and
/// the talk line. It never takes focus and stays out of screen sharing, like the notes window.
sealed class LiveBubble : Window
{
    readonly Controller app;
    readonly DispatcherTimer clock = new() { Interval = TimeSpan.FromSeconds(1) };
    readonly TextBlock clockText = Ui.Text("", 12, Palette.Secondary, wrap: false);
    readonly ContentControl body = new(), talk = new(), chip = new(), mode = new();
    bool notes, renderQueued;

    static readonly SolidColorBrush Brand = new(Color.FromRgb(0x2F, 0x62, 0xE0));
    static readonly SolidColorBrush Glass = new(Color.FromArgb(0xF2, 0xFA, 0xFB, 0xFD));
    static readonly SolidColorBrush Bead = new(Color.FromArgb(0xC0, 0xFF, 0xFF, 0xFF));

    public LiveBubble(Controller app)
    {
        this.app = app;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ShowActivated = false;
        ResizeMode = ResizeMode.NoResize;
        FontFamily = Palette.Font;
        Title = "Snart";
        Width = 360 + 2 * Ui.ShadowRoom;
        Height = 236 + 2 * Ui.ShadowRoom;
        var area = SystemParameters.WorkArea;
        Left = area.Right - Width - 12 + Ui.ShadowRoom;
        Top = area.Top + 12 - Ui.ShadowRoom;
        SourceInitialized += (_, _) =>
        {
            Native.MakeNonActivating(this);
            Native.SetCaptureVisible(this, app.Settings.ShowInCapture);
        };
        MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) try { DragMove(); } catch { } };
        clock.Tick += (_, _) => Tick();
        IsVisibleChanged += (_, _) => { if (IsVisible) clock.Start(); else clock.Stop(); };

        var head = new DockPanel { Margin = new Thickness(14, 12, 10, 6), LastChildFill = false };
        var left = Ui.Row(8, AppIcon.Small(20), chip);
        DockPanel.SetDock(left, Dock.Left);
        head.Children.Add(left);
        var right = Ui.Row(2,
            Ui.Row(6, Ui.LiveDot(7), clockText),
            Ui.IconButton(Icons.Notes, "Notes", () => { notes = !notes; Render(); }, Palette.Secondary, 30, 15),
            Ui.IconButton(Icons.Gear, "Settings", app.ShowSettings, Palette.Secondary, 30, 15),
            Ui.IconButton(Icons.Close, "Hide", Hide, Palette.Secondary, 30, 14));
        DockPanel.SetDock(right, Dock.Right);
        head.Children.Add(right);

        var foot = new DockPanel { Margin = new Thickness(12, 4, 12, 12) };
        var stop = Ui.IconButton(Icons.Stop, "End meeting", () => { if (app.Listen.Listening) app.RequestStop(); else _ = app.ToggleListening(); }, Palette.Ink, 36, 14, fill: true);
        DockPanel.SetDock(stop, Dock.Right);
        foot.Children.Add(stop);
        // Hold the key, or hands-free: one click switches, as the Mac's ⌥ / 〰.
        DockPanel.SetDock(mode, Dock.Left);
        mode.Margin = new Thickness(0, 0, 6, 0);
        foot.Children.Add(mode);
        foot.Children.Add(new Border { Background = Bead, CornerRadius = new CornerRadius(17), Padding = new Thickness(14, 8, 14, 8), Margin = new Thickness(0, 0, 8, 0), Child = talk });

        var root = new DockPanel();
        DockPanel.SetDock(head, Dock.Top);
        DockPanel.SetDock(foot, Dock.Bottom);
        root.Children.Add(head);
        root.Children.Add(foot);
        body.Margin = new Thickness(16, 0, 16, 2);
        root.Children.Add(body);
        Content = Ui.Floating(root, Glass, 22);
        Render();
    }

    /// Changes come from engine threads: one render on the UI thread.
    public void Refresh()
    {
        if (renderQueued) return;
        renderQueued = true;
        Dispatcher.BeginInvoke(DispatcherPriority.Background, () => { renderQueued = false; Render(); });
    }

    void Tick()
    {
        var s = app.Listen.SessionId is { } id ? app.Store.Get(id) : null;
        clockText.Text = app.Listen.Listening && s is not null ? Languages.Clock((DateTimeOffset.Now - s.StartedAt).TotalSeconds) : "";
    }

    static string Short(string code) => Languages.Base(code).ToUpperInvariant();

    void Render()
    {
        var st = app.Settings;
        var pair = Ui.Row(6,
            Ui.Text(Short(st.Mine), 13, Palette.Ink, FontWeights.SemiBold, wrap: false),
            Ui.Icon(Icons.Arrow, 12, Palette.Secondary),
            Ui.Text(Short(st.Theirs), 13, Palette.Ink, FontWeights.SemiBold, wrap: false));
        var swap = new Button { Content = pair, Padding = new Thickness(10, 4, 10, 4), Background = Bead, BorderThickness = new Thickness(0), Cursor = Cursors.Hand, ToolTip = "Swap languages" };
        swap.Template = BeadTemplate();
        swap.Click += (_, _) => app.SetLanguages(st.Theirs, st.Mine);
        chip.Content = swap;
        body.Content = notes ? Notes() : Lines();
        talk.Content = TalkLine();
        var hands = app.Settings.HandsFree;
        mode.Content = Ui.IconButton(hands ? Icons.Wave : Icons.Keyboard, hands ? "Hands-free (click for hold to talk)" : "Hold to talk (click for hands-free)",
            () => app.SetHandsFree(!app.Settings.HandsFree), hands ? Brand : Palette.Secondary, 34, 15);
        Tick();
    }

    static ControlTemplate BeadTemplate()
    {
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
        border.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding("Background") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        border.SetBinding(Border.PaddingProperty, new System.Windows.Data.Binding("Padding") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        border.AppendChild(new FrameworkElementFactory(typeof(ContentPresenter)));
        return new ControlTemplate(typeof(Button)) { VisualTree = border };
    }

    /// The last few lines, newest at the bottom: the original small and grey, the translation bold.
    UIElement Lines()
    {
        var s = app.Listen.SessionId is { } id ? app.Store.Get(id) : null;
        var lines = s?.Lines.TakeLast(3).ToList() ?? [];
        if (lines.Count == 0)
        {
            var hint = app.Listen.Listening ? $"Listening for {Ui.TargetName(app.Settings.Theirs)}…" : "Start listening, then start your call.";
            return Ui.Text(hint, 13, Palette.Secondary);
        }
        var stack = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom };
        foreach (var l in lines)
        {
            var mine = l.Speaker == "me";
            var tag = Ui.Text(mine ? "You" : Short(l.SrcLang), 11, mine ? Palette.Live : Palette.Tertiary, FontWeights.SemiBold, wrap: false);
            tag.Width = 30;
            var text = new StackPanel
            {
                Children =
                {
                    Ui.Text(l.Src, 12, Palette.Secondary),
                    Ui.Text(l.Dst ?? "…", 14, Palette.Ink, FontWeights.SemiBold),
                },
            };
            var row = new DockPanel { Margin = new Thickness(0, 0, 0, 8) };
            DockPanel.SetDock(tag, Dock.Left);
            row.Children.Add(tag);
            row.Children.Add(text);
            stack.Children.Add(row);
        }
        return Scrolled(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = stack });
    }

    /// Kept at the newest line as lines come in; scrolling up to read stays where it is.
    static ScrollViewer Scrolled(ScrollViewer sv)
    {
        sv.Loaded += (_, _) => sv.ScrollToEnd();
        sv.ScrollChanged += (_, e) => { if (e.ExtentHeightChange > 0) sv.ScrollToEnd(); };
        return sv;
    }

    UIElement Notes()
    {
        var s = app.Listen.SessionId is { } id ? app.Store.Get(id) : null;
        var n = s?.Notes;
        if (n is null || n.IsEmpty) return Ui.Text("Notes appear here as the meeting goes on.", 13, Palette.Secondary);
        var stack = new StackPanel();
        if (n.Summary.Length > 0) stack.Children.Add(Ui.Text(n.Summary, 13, Palette.Ink));
        foreach (var t in n.Todos.Take(4)) stack.Children.Add(Ui.Text("• " + t.WithOwner, 12, Palette.Body));
        return new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = stack };
    }

    /// What the talk key is doing, in one line.
    UIElement TalkLine()
    {
        var sp = app.Speak;
        var theirs = Ui.TargetName(app.Settings.Theirs);
        var (icon, color, text) = sp.State switch
        {
            SpeakEngine.Phase.Recording => (Icons.Mic, Palette.Live, "Listening to you…"),
            SpeakEngine.Phase.Translating => (Icons.Wave, Palette.Live, "Translating…"),
            SpeakEngine.Phase.Speaking => (Icons.Speaker, Palette.Live, sp.Heard ?? $"Speaking {theirs}…"),
            SpeakEngine.Phase.Failed => (Icons.Warning, Palette.Danger, sp.Problem ?? "Nothing sent"),
            _ when !app.Settings.Speak => (Icons.Keyboard, Palette.Secondary, "Turn on speaking in Settings › Interpreting"),
            _ when app.Settings.HandsFree && app.HandsFreeOn => (Icons.Wave, Palette.Secondary, $"Hands-free: just talk, they hear {theirs}"),
            _ => (Icons.Keyboard, Palette.Secondary, $"Hold {PushToTalk.Label} to speak {theirs}"),
        };
        var t = Ui.Text(text, 13, sp.State == SpeakEngine.Phase.Idle ? Palette.Secondary : Palette.Ink, wrap: false);
        t.TextTrimming = TextTrimming.CharacterEllipsis;
        return Ui.Row(8, Ui.Icon(icon, 14, color), t);
    }
}
