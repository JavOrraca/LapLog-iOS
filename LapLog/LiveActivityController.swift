import ActivityKit
import Foundation

/// Thin wrapper around ActivityKit. Best-effort: any failure (user disabled
/// Live Activities, system declined the request) is silently ignored — the
/// app continues to function, just without the Dynamic Island / Lock Screen
/// presence.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    private var activity: Activity<LapLogActivityAttributes>?

    func startOrUpdate(state: LapLogActivityAttributes.ContentState,
                       attributes: LapLogActivityAttributes) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity == nil {
            do {
                let content = ActivityContent(state: state, staleDate: nil)
                activity = try Activity.request(attributes: attributes,
                                                content: content,
                                                pushType: nil)
            } catch {
                // No-op: Live Activity is a best-effort enhancement.
            }
        } else {
            Task { await update(state: state) }
        }
    }

    func update(state: LapLogActivityAttributes.ContentState) async {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
    }

    func end() async {
        guard let activity else { return }
        let final = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(final, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
