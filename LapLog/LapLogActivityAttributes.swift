import ActivityKit
import Foundation

/// Shared between the main app and the Widget Extension.
/// Both targets must include this file in their Compile Sources.
struct LapLogActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Effective session start anchor for `Text(timerInterval:)`.
        /// While running, this equals `Date() - totalMs/1000` so the OS-rendered
        /// timer reads the correct elapsed time and ticks forward on its own.
        var sessionStartDate: Date

        /// Effective active-lap start anchor. Same trick as `sessionStartDate`
        /// but for the in-progress lap.
        var activeLapStartDate: Date

        /// Snapshot total elapsed (ms). Used to render frozen time when paused.
        var totalMs: Int

        /// Snapshot active-lap elapsed (ms). Used to render frozen time when paused.
        var activeLapMs: Int

        /// 1-based number of the in-progress lap (laps.count + 1).
        var activeLapNumber: Int

        /// When false, the widget renders static `totalMs` / `activeLapMs` instead of
        /// a live `Text(timerInterval:)`.
        var isRunning: Bool
    }

    /// Static for the lifetime of this activity. Updated by ending + restarting if it changes.
    var sessionTitle: String
}
