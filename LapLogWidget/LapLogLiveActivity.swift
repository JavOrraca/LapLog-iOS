import ActivityKit
import SwiftUI
import WidgetKit

struct LapLogLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LapLogActivityAttributes.self) { context in
            // Lock Screen / Banner presentation.
            LockScreenView(state: context.state, title: context.attributes.sessionTitle)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — shown when long-pressed, or when this is the prominent activity.
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TimerLabel(state: context.state, kind: .total)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("L\(context.state.activeLapNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TimerLabel(state: context.state, kind: .lap, alignment: .trailing)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.sessionTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !context.state.isRunning {
                            Text("Paused")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text("Total:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TimerLabel(state: context.state, kind: .total)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                }
            } compactTrailing: {
                HStack(spacing: 3) {
                    Text("L\(context.state.activeLapNumber):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TimerLabel(state: context.state, kind: .lap)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                }
            } minimal: {
                Text("L\(context.state.activeLapNumber)")
                    .font(.caption2.weight(.semibold))
            }
        }
    }
}

// MARK: - Lock Screen presentation

private struct LockScreenView: View {
    let state: LapLogActivityAttributes.ContentState
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if !state.isRunning {
                    Text("Paused")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    TimerLabel(state: state, kind: .total)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("L\(state.activeLapNumber)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    TimerLabel(state: state, kind: .lap, alignment: .trailing)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Self-ticking timer label

/// Renders a live count-up via `Text(timerInterval:)` while running, or a frozen
/// formatted string while paused. The OS handles the per-second tick when running,
/// so the widget doesn't need any push updates between state transitions.
private struct TimerLabel: View {
    enum Kind { case total, lap }
    let state: LapLogActivityAttributes.ContentState
    let kind: Kind
    var alignment: TextAlignment = .leading

    var body: some View {
        Group {
            if state.isRunning {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
            } else {
                Text(staticFormatted)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(alignment)
    }

    private var startDate: Date {
        kind == .total ? state.sessionStartDate : state.activeLapStartDate
    }

    private var staticFormatted: String {
        let ms = kind == .total ? state.totalMs : state.activeLapMs
        let totalSec = ms / 1000
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        let s = totalSec % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
