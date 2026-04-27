import SwiftUI

// MARK: - Domain models

struct Lap: Identifiable, Hashable, Codable {
    let id: UUID
    var index: Int
    var name: String
    /// Session elapsed when this lap began (sequential: prior lap's totalMs; parallel: the moment Lap was pressed).
    var startMs: Int
    /// Display anchor for the "at" subtitle — sequential: lap end time; parallel: same as startMs.
    var totalMs: Int
    /// Sequential: fixed at commit. Parallel: live-updated until the session stops.
    var durationMs: Int

    init(id: UUID = UUID(), index: Int, name: String, startMs: Int, totalMs: Int, durationMs: Int) {
        self.id = id
        self.index = index
        self.name = name
        self.startMs = startMs
        self.totalMs = totalMs
        self.durationMs = durationMs
    }
}

struct Session: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var totalMs: Int
    var laps: [Lap]

    init(id: UUID = UUID(), title: String, date: Date = Date(), totalMs: Int, laps: [Lap]) {
        self.id = id
        self.title = title
        self.date = date
        self.totalMs = totalMs
        self.laps = laps
    }

    var lapCount: Int { laps.count }
    var dayBadge: String { Session.dayFormatter.string(from: date) }
    var shortDate: String { Session.shortFormatter.string(from: date) }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()

    static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - Themes

enum AppTheme: String, CaseIterable, Identifiable {
    case warmLight = "warm-light"
    case paper
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .warmLight: return "Warm light"
        case .paper: return "Paper"
        case .dark: return "Dark"
        }
    }
}

struct Palette {
    let theme: AppTheme
    let dark: Bool
    let bg: Color
    let card: Color
    let text: Color
    let muted: Color
    let faint: Color
    let sep: Color
    let chipBg: Color

    init(theme: AppTheme) {
        self.theme = theme
        switch theme {
        case .warmLight:
            self.dark = false
            self.bg = Color(hex: 0xf5f2ec)
            self.card = Color.white
            self.text = Color(hex: 0x1b1b1a)
            self.muted = Color(hex: 0x1e1c18, opacity: 0.55)
            self.faint = Color(hex: 0x1e1c18, opacity: 0.30)
            self.sep = Color(hex: 0x1e1c18, opacity: 0.08)
            self.chipBg = Color(hex: 0x1e1c18, opacity: 0.05)
        case .paper:
            self.dark = false
            self.bg = Color(hex: 0xece7d8)
            self.card = Color(hex: 0xf7f3e6)
            self.text = Color(hex: 0x2a2417)
            self.muted = Color(hex: 0x2a2417, opacity: 0.55)
            self.faint = Color(hex: 0x2a2417, opacity: 0.30)
            self.sep = Color(hex: 0x2a2417, opacity: 0.10)
            self.chipBg = Color(hex: 0x2a2417, opacity: 0.05)
        case .dark:
            self.dark = true
            self.bg = Color(hex: 0x17130a)
            self.card = Color(hex: 0x1f1a10)
            self.text = Color(hex: 0xece7d8)
            self.muted = Color(hex: 0xece7d8, opacity: 0.55)
            self.faint = Color(hex: 0xece7d8, opacity: 0.30)
            self.sep = Color(hex: 0xece7d8, opacity: 0.10)
            self.chipBg = Color(hex: 0xece7d8, opacity: 0.06)
        }
    }
}

// Grill-themed quick picks — shown on long-press of a lap row.
let QUICK_PICKS: [String] = [
    "Steak flip", "Steak rest", "Chicken flip", "Veg on",
    "Veg off", "Burger flip", "Sausages", "Corn", "Fish",
    "Coals ready", "Sear", "Indirect"
]

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self = Color(red: r, green: g, blue: b).opacity(opacity)
    }

    /// Relative luminance (sRGB approximation) from a packed hex value.
    static func isLight(hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xff)
        let g = Double((hex >> 8) & 0xff)
        let b = Double(hex & 0xff)
        let l = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        return l > 0.7
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
