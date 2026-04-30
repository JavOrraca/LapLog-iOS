import StoreKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.requestReview) private var requestReview

    /// Session-count milestones at which to surface the App Store rating prompt.
    /// Apple's `requestReview` itself caps at ~3 prompts per year, so anything above
    /// the first hit is best-effort and silently no-ops if the cap is reached.
    private static let reviewMilestones: Set<Int> = [3, 10, 25]

    var body: some View {
        let p = state.palette
        ZStack {
            p.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                timerArea
                    .padding(.bottom, 6)
                controls
                ScrollView { LapsListView() }
                    .background(p.card)
            }
        }
        .tint(state.accentColor)
        .onChange(of: state.history.count) { _, newValue in
            if Self.reviewMilestones.contains(newValue) {
                requestReview()
            }
        }
        .sheet(isPresented: Binding(
            get: { state.activeOverlay == .history },
            set: { if !$0 { state.activeOverlay = .none } }
        )) {
            HistoryPanel(onClose: { state.activeOverlay = .none })
                .environmentObject(state)
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackground(p.bg)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(
            get: { state.activeOverlay == .menu },
            set: { if !$0 { state.activeOverlay = .none } }
        )) {
            MenuSheet(
                onClose: { state.activeOverlay = .none },
                onNew: {
                    state.resetAndArchive()
                    state.activeOverlay = .none
                },
                onExport: {
                    state.exportLaps()
                    state.activeOverlay = .none
                },
                onSettings: { state.activeOverlay = .settings }
            )
            .environmentObject(state)
            .presentationDetents([.height(320)])
            .presentationBackground(p.bg)
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: Binding(
            get: { state.activeOverlay == .settings },
            set: { if !$0 { state.activeOverlay = .none } }
        )) {
            SettingsPanel(onClose: { state.activeOverlay = .none })
                .environmentObject(state)
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackground(p.bg)
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Top bar (editable session title + icons)

    private var topBar: some View {
        let p = state.palette
        return HStack(alignment: .center) {
            EditableSessionTitle()
            Spacer()
            HStack(spacing: 10) {
                IconCircle(background: p.chipBg,
                           action: { state.activeOverlay = .history }) {
                    ClockGlyph(color: p.text)
                }
                .accessibilityLabel("History")

                IconCircle(background: p.chipBg,
                           action: { state.activeOverlay = .menu }) {
                    HamburgerGlyph(color: p.text)
                }
                .accessibilityLabel("Menu")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    // MARK: - Timer area

    private var timerArea: some View {
        let p = state.palette
        return ZStack {
            SecondHandRing(ms: state.elapsedMs,
                           running: state.running,
                           accent: state.accentColor,
                           track: p.text)
                .frame(width: 300, height: 300)

            VStack(spacing: 14) {
                TimeReadout(ms: state.elapsedMs,
                            color: p.text,
                            muted: state.palette.muted,
                            big: state.bigNumerals)

                HStack(spacing: 6) {
                    Circle()
                        .fill(state.running ? state.accentColor : p.faint)
                        .frame(width: 6, height: 6)
                        .shadow(color: state.running ? state.accentColor.opacity(0.8) : .clear,
                                radius: state.running ? 6 : 0)
                        .animation(.easeInOut(duration: 0.3), value: state.running)

                    Text(statusText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(p.muted)
                }
            }
        }
        .frame(height: 300)
    }

    private var statusText: String {
        if state.running { return "RUNNING" }
        if state.elapsedMs == 0 { return "READY" }
        if !state.laps.isEmpty {
            return "PAUSED · CURRENT LAP \(fmtLap(state.activeLapElapsedMs).uppercased())"
        }
        return "PAUSED"
    }

    // MARK: - Controls

    private var controls: some View {
        let canLeft = state.running || state.elapsedMs > 0
        let leftLabel = state.running ? "Lap" : (state.elapsedMs > 0 ? "Reset" : "Lap")
        let rightLabel = state.running ? "Stop" : "Start"
        let rightHex: UInt32 = state.running ? 0xc92a2a : state.accentHex

        return HStack {
            RoundButton(label: leftLabel, kind: .ghost,
                        accentHex: state.accentHex,
                        palette: state.palette,
                        disabled: !canLeft) {
                if state.running {
                    state.addLap()
                } else if state.elapsedMs > 0 {
                    state.resetAndArchive()
                }
            }
            Spacer()
            RoundButton(label: rightLabel, kind: .primary,
                        accentHex: rightHex,
                        palette: state.palette,
                        disabled: false) {
                state.running ? state.stop() : state.start()
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 10)
        .padding(.bottom, 22)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
