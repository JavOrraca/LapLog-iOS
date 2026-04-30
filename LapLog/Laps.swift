import SwiftUI

// MARK: - Laps list (card-styled, newest first)

struct LapsListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let p = state.palette
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("Laps")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(p.text)
                    if !state.laps.isEmpty {
                        Text("· \(state.laps.count)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(p.muted)
                    }
                }
                Spacer()
                Text("TAP TO RENAME")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(p.faint)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Current lap preview (visible while running OR paused past the last lap)
            if showsCurrentLapRow {
                CurrentLapRow()
            }

            // Empty state or completed laps
            if state.laps.isEmpty && state.elapsedMs == 0 {
                EmptyState()
            } else {
                ForEach(Array(state.laps.enumerated().reversed()), id: \.element.id) { i, lap in
                    LapRow(lap: lap, index: i, isLatest: i == state.laps.count - 1)
                    if i > 0 {
                        Rectangle().fill(p.sep).frame(height: 0.5)
                    }
                }
            }

            Color.clear.frame(height: 50)  // bottom breathing room
        }
        .frame(maxWidth: .infinity)
        .background(p.card)
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .overlay(alignment: .top) {
            Rectangle().fill(p.sep).frame(height: 0.5)
        }
    }

    private var showsCurrentLapRow: Bool {
        state.elapsedMs > 0 && state.elapsedMs > state.activeLapStart
    }
}

// MARK: - Current lap (editable, pins to top of list)

struct CurrentLapRow: View {
    @EnvironmentObject var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        let p = state.palette
        let idx = state.activeLapNumber
        let curr = state.activeLapElapsedMs

        HStack(spacing: 12) {
            Text(String(format: "%02d", idx))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(state.accentColor)
                .frame(width: 28, alignment: .leading)

            HStack(spacing: 8) {
                TextField("Name this lap…", text: $state.currentLapName)
                    .focused($focused)
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(p.text)
                    .autocorrectionDisabled()
                    .submitLabel(.done)

                if state.running {
                    PulseDot(color: state.accentColor)
                } else {
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(p.muted)
                }
            }

            Spacer(minLength: 6)

            Text(fmtLap(curr))
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .monospacedDigit()
                .tracking(-0.3)
                .foregroundStyle(p.text)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(p.chipBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(p.sep).frame(height: 0.5)
        }
    }
}

// MARK: - Completed lap row (tap → rename, long-press → quick picks)

struct LapRow: View {
    let lap: Lap
    let index: Int            // position in state.laps
    let isLatest: Bool

    @EnvironmentObject var state: AppState
    @State private var editing = false
    @State private var draft = ""
    @State private var quickOpen = false
    @FocusState private var focused: Bool

    var body: some View {
        let p = state.palette
        ZStack {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", lap.index))
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(p.faint)
                    .frame(width: 28, alignment: .leading)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    if editing {
                        TextField("", text: $draft)
                            .focused($focused)
                            .font(.system(size: 17, weight: isLatest ? .semibold : .medium))
                            .tracking(-0.3)
                            .foregroundStyle(p.text)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(state.accentColor).frame(height: 1.5)
                            }
                            .onAppear {
                                draft = lap.name
                                focused = true
                            }
                            .onSubmit { commit() }
                            .onChange(of: focused) { _, f in if !f { commit() } }
                    } else {
                        Text(lap.name)
                            .font(.system(size: 17, weight: isLatest ? .semibold : .medium))
                            .tracking(-0.3)
                            .foregroundStyle(p.text)
                            .lineLimit(1)
                            .contentShape(.rect)
                            .onTapGesture { editing = true }
                    }
                    Text("at \(fmtLap(lap.totalMs))")
                        .font(.system(size: 11, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(p.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(fmtLap(lap.durationMs))
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.3)
                    .foregroundStyle(p.text)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: 0.42) {
                if state.showQuick { quickOpen = true }
            }
        }
        .sheet(isPresented: $quickOpen) {
            QuickPickSheet(
                onPick: { name in
                    state.renameLap(at: index, to: name)
                    quickOpen = false
                },
                onDelete: {
                    state.deleteLap(at: index)
                    quickOpen = false
                }
            )
            .environmentObject(state)
            .presentationDetents([.height(340)])
            .presentationBackground(p.bg)
            .presentationDragIndicator(.visible)
        }
    }

    private func commit() {
        state.renameLap(at: index, to: draft)
        editing = false
    }
}

// MARK: - Quick picks sheet (long-press on a lap row)

struct QuickPickSheet: View {
    let onPick: (String) -> Void
    let onDelete: () -> Void
    @EnvironmentObject var state: AppState

    var body: some View {
        let p = state.palette
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK PICK")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(p.muted)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            FlowLayout(spacing: 6) {
                ForEach(QUICK_PICKS, id: \.self) { pick in
                    Button {
                        onPick(pick)
                    } label: {
                        Text(pick)
                            .font(.system(size: 13, weight: .medium))
                            .tracking(-0.1)
                            .foregroundStyle(p.text)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(p.chipBg, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Divider().background(p.sep).padding(.top, 12)

            Button(action: onDelete) {
                Text("Delete lap")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: 0xc92a2a))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .background(p.bg)
    }
}

// A tiny wrap-flowing HStack for the quick-pick chip grid.
struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            maxX = max(maxX, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: min(width, maxX), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                       proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let p = state.palette
        let lap = Text("Lap").bold().foregroundStyle(p.text)
        let mile1 = Text("mile 1").foregroundStyle(state.accentColor).fontWeight(.medium)
        let ribeye = Text("Ribeye flip").foregroundStyle(state.accentColor).fontWeight(.medium)
        let stage2 = Text("stage 2").foregroundStyle(state.accentColor).fontWeight(.medium)
        let sessionLabel = Text("Session · \(state.sessionTitle.uppercased())")
            .bold().foregroundStyle(p.muted)

        VStack(spacing: 12) {
            Text("Start the timer and tap \(lap) each time you want to mark a moment. Then tap any lap to rename it — \(mile1), \(ribeye), \(stage2) — whatever you're tracking.")
                .foregroundStyle(p.muted)
                .font(.system(size: 15))
                .tracking(-0.2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Tip: tap \(sessionLabel) in the top-left to rename this session.")
                .foregroundStyle(p.faint)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
    }
}
