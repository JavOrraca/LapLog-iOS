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
    @Published var history: [Session] = []
    @Published var selectedSession: Session? = nil

    // MARK: - Settings
    @Published var theme: AppTheme = .paper
    @Published var accentHex: UInt32 = 0x1a1916
    @Published var showQuick: Bool = true
    @Published var bigNumerals: Bool = true
    /// When true, each lap keeps timing until the session stops — so multiple laps can run concurrently.
    @Published var concurrentLaps: Bool = false

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
        self.history = AppState.seedHistory()
    }

    // MARK: - Demo history

    private static func seedHistory() -> [Session] {
        func d(_ month: Int, _ day: Int) -> Date {
            var comps = DateComponents()
            comps.year = 2026; comps.month = month; comps.day = day
            return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
        }
        return [
            Session(title: "Sat cookout", date: d(4, 19), totalMs: 2_745_000, laps: [
                Lap(index: 1, name: "Coals ready", startMs: 0,          totalMs:   420_000, durationMs: 420_000),
                Lap(index: 2, name: "Ribeye on",   startMs:   420_000, totalMs: 1_020_000, durationMs: 600_000),
                Lap(index: 3, name: "Ribeye flip", startMs: 1_020_000, totalMs: 1_860_000, durationMs: 840_000),
                Lap(index: 4, name: "Ribeye rest", startMs: 1_860_000, totalMs: 2_745_000, durationMs: 885_000)
            ]),
            Session(title: "Weeknight steak", date: d(4, 16), totalMs: 1_082_000, laps: [
                Lap(index: 1, name: "Sear", startMs: 0,         totalMs:   180_000, durationMs: 180_000),
                Lap(index: 2, name: "Flip", startMs:   180_000, totalMs:   540_000, durationMs: 360_000),
                Lap(index: 3, name: "Rest", startMs:   540_000, totalMs: 1_082_000, durationMs: 542_000)
            ]),
            Session(title: "Friends over", date: d(4, 12), totalMs: 4_210_000, laps: [
                Lap(index: 1, name: "Veg on",       startMs: 0,         totalMs:   600_000, durationMs: 600_000),
                Lap(index: 2, name: "Burgers on",   startMs:   600_000, totalMs: 1_260_000, durationMs: 660_000),
                Lap(index: 3, name: "Burgers flip", startMs: 1_260_000, totalMs: 1_920_000, durationMs: 660_000),
                Lap(index: 4, name: "Corn on",      startMs: 1_920_000, totalMs: 2_640_000, durationMs: 720_000),
                Lap(index: 5, name: "Sausages on",  startMs: 2_640_000, totalMs: 3_420_000, durationMs: 780_000),
                Lap(index: 6, name: "All plated",   startMs: 3_420_000, totalMs: 4_210_000, durationMs: 790_000)
            ])
        ]
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
