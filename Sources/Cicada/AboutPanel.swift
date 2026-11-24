// Based on Cicada (https://github.com/wquguru/cicada), Apache License 2.0.
// Modified by CognivexAI, 2026.
import AppKit

/// "About": the standard About panel (icon, name, version and copyright come from Info.plist)
/// with a line about the app and links to the website, the project and its issues.
@MainActor
enum AboutPanel {
    static let website = URL(string: "https://cognivexai.eu/")!
    static let issues = UpdateChecker.repository.appendingPathComponent("issues/new")

    static func show() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private static var credits: NSAttributedString {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.paragraphSpacing = 6
        let plain: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor, .paragraphStyle: centered,
        ]
        let text = NSMutableAttributedString(string: L("把 Mac 正在播放的声音变成实时双语字幕和会议纪要") + "\n", attributes: plain)
        let links = [(L("网站"), website)]
        for (i, (title, url)) in links.enumerated() {
            if i > 0 { text.append(NSAttributedString(string: "  ·  ", attributes: plain)) }
            var linked = plain
            linked[.link] = url
            text.append(NSAttributedString(string: title, attributes: linked))
        }
        var note = plain
        note[.foregroundColor] = NSColor.secondaryLabelColor
        note[.font] = NSFont.systemFont(ofSize: 10)
        text.append(NSAttributedString(string: "\n" + L("声纹模型：WeSpeaker ResNet34-LM（VoxCeleb），CC BY 4.0"), attributes: note))
        // Apache-2.0 asks for the origin to be kept with the work (LICENSE and NOTICE in the repo).
        text.append(NSAttributedString(string: "\nBased on Cicada by wquguru, Apache License 2.0", attributes: note))
        if let dev = DevBuild.label {
            var secondary = plain
            secondary[.foregroundColor] = NSColor.secondaryLabelColor
            text.append(NSAttributedString(string: "\nDEV · \(dev)", attributes: secondary))
        }
        return text
    }
}
