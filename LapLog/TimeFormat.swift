import Foundation

func fmt(_ ms: Int) -> String {
    let m = max(0, ms)
    let cs = (m / 10) % 100
    let s = (m / 1000) % 60
    let mins = (m / 60_000) % 60
    let h = m / 3_600_000
    if h > 0 {
        return String(format: "%d:%02d:%02d.%02d", h, mins, s, cs)
    }
    return String(format: "%02d:%02d.%02d", mins, s, cs)
}

func fmtLap(_ ms: Int) -> String { fmt(ms) }

/// Split "mm:ss.cs" into the main and centisecond parts.
func splitTime(_ text: String) -> (main: String, cs: String) {
    if let dot = text.lastIndex(of: ".") {
        return (String(text[..<dot]), String(text[dot...]))
    }
    return (text, "")
}
