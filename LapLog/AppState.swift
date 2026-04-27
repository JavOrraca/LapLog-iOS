import SwiftUI
import Combine
import UIKit

enum AppOverlay: Equatable { case none, history, menu, settings }

@MainActor
final class AppState: ObservableObject {
    // MARK: - Stopwatch state
    @Published var elapsedMs: Int = 0
    @Published var running: Bool = false
    @Published var laps: [Lap] = []
    @Published var currentLapName: String = ""
    @Published var sessionTitle: String = "Grill"

    // MARK: - History
    @Published var history: [Session] = [] {
        didSet { persistHistory() }
    }
    @Published var selectedSession: Session? = nil

    private static let historyStorageKey = "LapLog.history.v1"
    private static let themeStorageKey = "LapLog.theme.v1"
    private static let accentStorageKey = "LapLog.accentHex.v1"
    private static let showQuickStorageKey = "LapLog.showQuick.v1"
    private static let bigNumeralsStorageKey = "LapLog.bigNumerals.v1"
    private static let concurrentLapsStorageKey = "LapLog.concurrentLaps.v1"

    // MARK: - Settings
    @Published var theme: AppTheme = .paper {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: AppState.themeStorageKey) }
    }
    @Published var accentHex: UInt32 = 0x1a1916 {
        didSet { UserDefaults.standard.set(Int(accentHex), forKey: AppState.accentStorageKey) }
    }
    @Published var showQuick: Bool = true {
        didSet { UserDefaults.standard.set(showQuick, forKey: AppState.showQuickStorageKey) }
    }
    @Published var bigNumerals: Bool = true {
        didSet { UserDefaults.standard.set(bigNumerals, forKey: AppState.bigNumeralsStorageKey) }
    }
    /// When true, each lap keeps timing until the session stops — so multiple laps can run concurrently.
    @Published var concurrentLaps: Bool = false {
        didSet { UserDefaults.standard.set(concurrentLaps, forKey: AppState.concurrentLapsStorageKey) }
    }

    // MARK: - UI state
    @Published var activeOverlay: AppOverlay = .none

    // MARK: - Internal timing
    private var timer: Timer?
    private var startedAt: TimeInterval = 0
    private var baseMs: Int = 0
    /// In parallel mode, when the currently-un-committed lap began. Bumped on each Lap press.
    @Published private(set) var pendingStartMs: Int = 0

    var palette: Palette { Palette(theme: theme) }
    var accentColor: Color { Color(hex: accentHex) }
    var isAccentLight: Bool { Color.isLight(hex: accentHex) }

    /// Accent hex that blends with the current theme — used to auto-swap when toggling light/dark.
    var themeMonochromeAccent: UInt32 { theme == .dark ? 0xece7d8 : 0x1a1916 }

    /// The fixed accent swatches plus the theme-aware 6th.
    var accentSwatches: [UInt32] {
        [0xc2410c, 0x0a7c41, 0x1e5fbf, 0x8b4fbf, 0xb3142f, themeMonochromeAccent]
    }

    init() {
        self.history = AppState.loadHistory()
        self.theme = AppState.loadTheme()
        self.accentHex = AppState.loadAccentHex()
        self.showQuick = AppState.loadBool(key: AppState.showQuickStorageKey, default: true)
        self.bigNumerals = AppState.loadBool(key: AppState.bigNumeralsStorageKey, default: true)
        self.concurrentLaps = AppState.loadBool(key: AppState.concurrentLapsStorageKey, default: false)
    }

    // MARK: - History persistence

    private static func loadHistory() -> [Session] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([Session].self, from: data)) ?? []
    }

    private func persistHistory() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: AppState.historyStorageKey)
        }
    }

    // MARK: - Settings persistence

    private static func loadTheme() -> AppTheme {
        guard let raw = UserDefaults.standard.string(forKey: themeStorageKey),
              let t = AppTheme(rawValue: raw) else { return .paper }
        return t
    }

    private static func loadAccentHex() -> UInt32 {
        guard UserDefaults.standard.object(forKey: accentStorageKey) != nil else { return 0x1a1916 }
        return UInt32(truncatingIfNeeded: UserDefaults.standard.integer(forKey: accentStorageKey))
    }

    private static func loadBool(key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    // MARK: - Stopwatch controls

    func start() {
        guard !running else { return }
        startedAt = CACurrentMediaTime()
        running = true
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        guard running else { return }
        timer?.invalidate(); timer = nil
        baseMs += Int((CACurrentMediaTime() - startedAt) * 1000)
        elapsedMs = baseMs
        finalizeConcurrentDurations()
        running = false
    }

    private func tick() {
        elapsedMs = baseMs + Int((CACurrentMediaTime() - startedAt) * 1000)
        finalizeConcurrentDurations()
    }

    private func finalizeConcurrentDurations() {
        guard concurrentLaps else { return }
        for i in laps.indices {
            laps[i].durationMs = max(0, elapsedMs - laps[i].startMs)
        }
    }

    private func resetTimer() {
        timer?.invalidate(); timer = nil
        baseMs = 0
        elapsedMs = 0
        running = false
    }

    // MARK: - Lap actions

    func addLap() {
        guard running else { return }
        let idx = laps.count + 1
        let now = elapsedMs
        let name = currentLapName.trimmed.isEmpty ? "Lap \(idx)" : currentLapName.trimmed
        if concurrentLaps {
            // Parallel mode: the pending lap (the one being named in the preview row)
            // commits at its own startMs. Its duration will keep ticking until session stop.
            laps.append(Lap(index: idx, name: name,
                            startMs: pendingStartMs,
                            totalMs: pendingStartMs,
                            durationMs: max(0, now - pendingStartMs)))
            pendingStartMs = now
        } else {
            let prevTotal = laps.last?.totalMs ?? 0
            laps.append(Lap(index: idx, name: name,
                            startMs: prevTotal, totalMs: now,
                            durationMs: max(0, now - prevTotal)))
        }
        currentLapName = ""
    }

    func renameLap(at index: Int, to name: String) {
        guard laps.indices.contains(index) else { return }
        let final = name.trimmed.isEmpty ? "Lap \(laps[index].index)" : name.trimmed
        laps[index].name = final
    }

    func deleteLap(at index: Int) {
        guard laps.indices.contains(index) else { return }
        laps.remove(at: index)
        for i in laps.indices { laps[i].index = i + 1 }
    }

    // MARK: - Session / reset

    func resetAndArchive() {
        let totalMs = elapsedMs
        var snapshot = laps

        if concurrentLaps {
            // Parallel mode: freeze every lap's duration at session stop…
            for i in snapshot.indices {
                snapshot[i].durationMs = max(0, totalMs - snapshot[i].startMs)
            }
            // …then fold the trailing un-committed pending lap in with its typed-or-default name.
            if totalMs > pendingStartMs {
                let idx = snapshot.count + 1
                let name = currentLapName.trimmed.isEmpty ? "Lap \(idx)" : currentLapName.trimmed
                snapshot.append(Lap(index: idx, name: name,
                                    startMs: pendingStartMs,
                                    totalMs: pendingStartMs,
                                    durationMs: max(0, totalMs - pendingStartMs)))
            }
        } else if totalMs > 0 {
            // Sequential mode: fold the in-progress lap into the archive so no time is lost.
            let prevTotal = snapshot.last?.totalMs ?? 0
            if totalMs > prevTotal {
                let idx = snapshot.count + 1
                let name = currentLapName.trimmed.isEmpty ? "Lap \(idx)" : currentLapName.trimmed
                snapshot.append(Lap(index: idx, name: name,
                                    startMs: prevTotal, totalMs: totalMs,
                                    durationMs: max(0, totalMs - prevTotal)))
            }
        }
        if totalMs > 0 || !snapshot.isEmpty {
            let title = sessionTitle.trimmed.isEmpty ? "Session" : sessionTitle
            history.insert(Session(title: title, date: Date(),
                                   totalMs: totalMs, laps: snapshot), at: 0)
        }
        resetTimer()
        laps = []
        currentLapName = ""
        pendingStartMs = 0
        sessionTitle = "New"
    }

    // MARK: - History mutations

    func renameSession(id: UUID, to name: String) {
        let final = name.trimmed
        guard !final.isEmpty else { return }
        if let i = history.firstIndex(where: { $0.id == id }) {
            history[i].title = final
        }
        if selectedSession?.id == id {
            selectedSession?.title = final
        }
    }

    func renameSessionLap(sessionId: UUID, lapIndex: Int, to name: String) {
        let final = name.trimmed
        guard !final.isEmpty else { return }
        if let i = history.firstIndex(where: { $0.id == sessionId }),
           history[i].laps.indices.contains(lapIndex) {
            history[i].laps[lapIndex].name = final
        }
        if var s = selectedSession, s.id == sessionId, s.laps.indices.contains(lapIndex) {
            s.laps[lapIndex].name = final
            selectedSession = s
        }
    }

    // MARK: - Settings

    func setTheme(_ t: AppTheme) {
        let wasDark = theme == .dark
        let toDark = t == .dark
        theme = t
        // Auto-swap accent when it would blend with the new background
        if toDark != wasDark {
            if toDark, accentHex == 0x1a1916 { accentHex = 0xece7d8 }
            else if !toDark, accentHex == 0xece7d8 { accentHex = 0x1a1916 }
        }
    }

    // MARK: - Export

    func exportLaps() {
        let text = laps.map { l in
            let idx = String(format: "%02d", l.index)
            return "\(idx)  \(l.name)  \(fmtLap(l.durationMs))  @ \(fmtLap(l.totalMs))"
        }.joined(separator: "\n")
        UIPasteboard.general.string = text.isEmpty ? "(no laps)" : text
    }
}
