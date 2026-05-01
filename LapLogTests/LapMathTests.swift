import Foundation
import Testing
@testable import LapLog

/// Math + state-machine tests around `addLap` and the active-lap anchor.
/// The Parallel-mode anchor was a real-world bug (PR #5); these tests pin the
/// expected behavior of both modes and the few edge cases around them.
@MainActor
struct LapMathTests {

    /// Build an `AppState` backed by a fresh, isolated UserDefaults suite so
    /// each test starts with the declared in-code defaults — no leakage from
    /// prior test runs or the host app's saved state.
    private func makeState() -> AppState {
        let suiteName = "LapLogTests-\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suiteName)!
        return AppState(defaults: isolated)
    }

    // MARK: - Sequential mode

    @Test
    func sequentialAddLapStoresPrevTotalAsStartAndElapsedAsEnd() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()

        #expect(s.laps.count == 1)
        #expect(s.laps[0].startMs == 0)
        #expect(s.laps[0].totalMs == 10_000)
        #expect(s.laps[0].durationMs == 10_000)
    }

    @Test
    func sequentialSecondLapBuildsOnFirst() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.elapsedMs = 25_000
        s.addLap()

        #expect(s.laps.count == 2)
        #expect(s.laps[1].startMs == 10_000)
        #expect(s.laps[1].totalMs == 25_000)
        #expect(s.laps[1].durationMs == 15_000)
    }

    @Test
    func sequentialActiveLapStartIsLastLapEnd() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.elapsedMs = 25_000

        #expect(s.activeLapStart == 10_000)
        #expect(s.activeLapElapsedMs == 15_000)
        #expect(s.activeLapNumber == 2)
    }

    @Test
    func sequentialActiveLapStartIsZeroWhenNoLapsCommitted() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 7_000

        #expect(s.activeLapStart == 0)
        #expect(s.activeLapElapsedMs == 7_000)
        #expect(s.activeLapNumber == 1)
    }

    // MARK: - Parallel / concurrent mode

    @Test
    func parallelAddLapStoresPendingStartAndAdvancesPending() {
        let s = makeState()
        s.concurrentLaps = true
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()

        #expect(s.laps.count == 1)
        #expect(s.laps[0].startMs == 0)
        #expect(s.laps[0].totalMs == 0)             // parallel: totalMs == startMs
        #expect(s.laps[0].durationMs == 10_000)
        #expect(s.pendingStartMs == 10_000)         // pending advances to "now"
    }

    @Test
    func parallelSecondLapAnchorsToOldPendingStart() {
        let s = makeState()
        s.concurrentLaps = true
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.elapsedMs = 25_000
        s.addLap()

        #expect(s.laps.count == 2)
        #expect(s.laps[1].startMs == 10_000)
        #expect(s.laps[1].totalMs == 10_000)
        #expect(s.pendingStartMs == 25_000)
    }

    /// Regression test for the PR #5 bug: the active-lap anchor in parallel
    /// mode is `pendingStartMs`, NOT `laps.last?.totalMs`. Using totalMs there
    /// would surface the prior committed lap's duration as if it were the
    /// active lap's elapsed time.
    @Test
    func parallelActiveLapStartFollowsPendingStartNotLastLapTotal() {
        let s = makeState()
        s.concurrentLaps = true
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()                              // L1 commits, pendingStartMs = 10_000
        s.elapsedMs = 20_000
        s.addLap()                              // L2 commits, pendingStartMs = 20_000
        s.elapsedMs = 25_000                    // L3 in progress for 5s

        #expect(s.activeLapStart == 20_000)     // NOT laps.last.totalMs (10_000)
        #expect(s.activeLapElapsedMs == 5_000)  // NOT 15_000 (the bug's symptom)
        #expect(s.activeLapNumber == 3)
    }

    // MARK: - Reset / archive

    @Test
    func resetAndArchiveFoldsTrailingActiveLapInSequentialMode() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.elapsedMs = 17_000                    // 7s of active L2, never committed
        s.sessionTitle = "Test session"
        s.resetAndArchive()

        #expect(s.history.count == 1)
        let archived = s.history[0]
        #expect(archived.totalMs == 17_000)
        #expect(archived.laps.count == 2)        // both L1 and the folded L2
        #expect(archived.laps[1].durationMs == 7_000)
    }

    @Test
    func resetAndArchiveDoesNotInsertWhenNothingHappened() {
        let s = makeState()
        // No start, no laps, no elapsed.
        s.resetAndArchive()

        #expect(s.history.isEmpty)
    }

    @Test
    func resetAndArchiveClearsTransientStateForNextSession() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.currentLapName = "Half-typed"
        s.resetAndArchive()

        #expect(s.laps.isEmpty)
        #expect(s.currentLapName.isEmpty)
        #expect(s.pendingStartMs == 0)
    }

    // MARK: - Lap-name editing flag (drives keyboard-avoidance UI)

    @Test
    func isEditingLapNameDefaultsFalse() {
        let s = makeState()
        #expect(s.isEditingLapName == false)
    }

    /// If the user was naming a lap and then archives the session (Reset / "New"),
    /// the CurrentLapRow disappears and its TextField's focus binding goes out of
    /// scope without firing `onChange`. Without a defensive clear here, the flag
    /// would stay stuck at `true` — and ContentView would keep the timer area
    /// hidden indefinitely, even on the next session.
    @Test
    func resetAndArchiveClearsIsEditingLapNameFlag() {
        let s = makeState()
        s.running = true
        s.elapsedMs = 10_000
        s.addLap()
        s.isEditingLapName = true   // simulate the user tapping the lap-name field

        s.resetAndArchive()

        #expect(s.isEditingLapName == false)
    }
}
