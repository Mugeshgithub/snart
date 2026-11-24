import Foundation

/// Cognivex Interpreter grew out of a Cicada build installed on the same Mac: on its first launch it
/// takes over that build's settings and its folder (AI keys, meeting records, voices), so nothing
/// has to be set up again. Copies, never moves: the old app keeps working if it is still there.
enum Migration {
    private static let oldDomain = "com.wquguru.cicada"
    private static let oldFolder = "LiveSubs"
    private static let doneKey = "migratedFromCicada"

    static func run() {
        let defaults = UserDefaults.standard
        guard !DevBuild.isDev, !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }
        if let old = defaults.persistentDomain(forName: oldDomain) {
            // Where the settings window was, and update bookkeeping, belong to the old app.
            for (key, value) in old where !["settingsSection", "updateLastChecked"].contains(key) && defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let from = base.appendingPathComponent(oldFolder), to = base.appendingPathComponent(DevBuild.supportFolder)
        guard fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) else { return }
        do {
            try fm.copyItem(at: from, to: to)
            // Shares lived on the old project's server; their tokens mean nothing here.
            try? fm.removeItem(at: to.appendingPathComponent("Shares"))
            debugLog("migration: settings and \(oldFolder) copied from Cicada")
        } catch {
            debugLog("migration: copy failed: \(error)")
        }
    }
}
