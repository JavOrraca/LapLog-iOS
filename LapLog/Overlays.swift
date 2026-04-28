import SwiftUI

// MARK: - Shared slide-up sheet shell

struct OverlayShell<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @EnvironmentObject var state: AppState

    var body: some View {
        let p = state.palette
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(p.faint)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.text)
                Spacer()
                Button("Done") { onClose() }
                    .font(.system(size: 15))
                    .foregroundStyle(p.muted)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.bottom, 14)

            content()
        }
        .background(p.bg)
    }
}

// MARK: - History panel

struct HistoryPanel: View {
    let onClose: () -> Void
    @EnvironmentObject var state: AppState
    @State private var renamingId: UUID?
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let p = state.palette
        OverlayShell(title: "History", onClose: onClose) {
            ScrollView {
                if state.history.isEmpty {
                    Text("Sessions will appear here once you reset.")
                        .font(.system(size: 15))
                        .foregroundStyle(p.muted)
                        .padding(40)
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(state.history.enumerated()), id: \.element.id) { i, s in
                            row(session: s)
                            if i < state.history.count - 1 {
                                Rectangle().fill(p.sep).frame(height: 0.5)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $state.selectedSession) { session in
            SessionDetailView(session: session,
                              onClose: { state.selectedSession = nil })
                .environmentObject(state)
                .presentationDetents([.fraction(0.82), .large])
                .presentationBackground(p.bg)
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private func row(session s: Session) -> some View {
        let p = state.palette
        HStack(spacing: 14) {
            Text(s.dayBadge)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(p.muted)
                .frame(width: 38, height: 38)
                .background(p.chipBg, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                if renamingId == s.id {
                    TextField("", text: $draft)
                        .focused($focused)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(p.text)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(state.accentColor).frame(height: 1.5)
                        }
                        .onSubmit { commitRename(for: s) }
                        .onChange(of: focused) { _, f in if !f { commitRename(for: s) } }
                } else {
                    Text(s.title)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(p.text)
                        .onTapGesture {
                            renamingId = s.id
                            draft = s.title
                            focused = true
                        }
                }
                Text("\(s.shortDate) · \(s.lapCount) lap\(s.lapCount == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(fmtLap(s.totalMs))
                .font(.system(size: 17, design: .rounded))
                .monospacedDigit()
                .tracking(-0.3)
                .foregroundStyle(p.text)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(p.faint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(.rect)
        .onTapGesture {
            if renamingId != s.id {
                state.selectedSession = s
            }
        }
    }

    private func commitRename(for s: Session) {
        state.renameSession(id: s.id, to: draft)
        renamingId = nil
    }
}

// MARK: - Session detail

struct SessionDetailView: View {
    let session: Session
    let onClose: () -> Void
    @EnvironmentObject var state: AppState
    @State private var editingTitle = false
    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool
    @State private var editingLap = -1
    @State private var lapDraft = ""
    @FocusState private var lapFocused: Bool

    var body: some View {
        OverlayShell(title: "Session details", onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleRow
                    summary
                    lapsHeader
                    lapsList
                    Color.clear.frame(height: 24)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear { titleDraft = session.title }
    }

    private var titleRow: some View {
        let p = state.palette
        return Group {
            if editingTitle {
                TextField("", text: $titleDraft)
                    .focused($titleFocused)
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(p.text)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(state.accentColor).frame(height: 1.5)
                    }
                    .onSubmit { commitTitle() }
                    .onChange(of: titleFocused) { _, f in if !f { commitTitle() } }
            } else {
                HStack(spacing: 8) {
                    Text(session.title)
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(p.text)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(p.muted)
                        .opacity(0.5)
                }
                .contentShape(.rect)
                .onTapGesture {
                    titleDraft = session.title
                    editingTitle = true
                    titleFocused = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var summary: some View {
        let p = state.palette
        return HStack(spacing: 20) {
            Text(session.shortDate.uppercased())
            Text("·")
            Text("\(session.laps.count) LAP\(session.laps.count == 1 ? "" : "S")")
            Text("·")
            HStack(spacing: 4) {
                Text("TOTAL")
                Text(fmtLap(session.totalMs))
                    .foregroundStyle(p.text)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .tracking(1)
        .foregroundStyle(p.muted)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var lapsHeader: some View {
        let p = state.palette
        return HStack {
            Text("Laps")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(p.text)
            Spacer()
            Text("TAP TO RENAME")
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(p.faint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var lapsList: some View {
        let p = state.palette
        return LazyVStack(spacing: 0) {
            ForEach(Array(session.laps.enumerated()), id: \.element.id) { i, lap in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d", lap.index))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(p.faint)
                        .frame(width: 28, alignment: .leading)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        if editingLap == i {
                            TextField("", text: $lapDraft)
                                .focused($lapFocused)
                                .font(.system(size: 17, weight: .medium))
                                .tracking(-0.3)
                                .foregroundStyle(p.text)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(state.accentColor).frame(height: 1.5)
                                }
                                .onSubmit { commitLap(i) }
                                .onChange(of: lapFocused) { _, f in if !f { commitLap(i) } }
                        } else {
                            Text(lap.name)
                                .font(.system(size: 17, weight: .medium))
                                .tracking(-0.3)
                                .foregroundStyle(p.text)
                                .onTapGesture {
                                    editingLap = i
                                    lapDraft = lap.name
                                    lapFocused = true
                                }
                        }
                        Text("at \(fmtLap(lap.totalMs))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(p.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(fmtLap(lap.durationMs))
                        .font(.system(size: 20, design: .rounded))
                        .monospacedDigit()
                        .tracking(-0.3)
                        .foregroundStyle(p.text)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                if i < session.laps.count - 1 {
                    Rectangle().fill(p.sep).frame(height: 0.5).padding(.leading, 60)
                }
            }
        }
    }

    private func commitTitle() {
        state.renameSession(id: session.id, to: titleDraft)
        editingTitle = false
    }

    private func commitLap(_ i: Int) {
        state.renameSessionLap(sessionId: session.id, lapIndex: i, to: lapDraft)
        editingLap = -1
    }
}

// MARK: - Menu sheet

struct MenuSheet: View {
    let onClose: () -> Void
    let onNew: () -> Void
    let onExport: () -> Void
    let onSettings: () -> Void
    @EnvironmentObject var state: AppState

    var body: some View {
        let p = state.palette
        OverlayShell(title: "Session", onClose: onClose) {
            VStack(spacing: 0) {
                row(icon: "plus", title: "New session", sub: "Archive current & reset", action: onNew)
                Rectangle().fill(p.sep).frame(height: 0.5).padding(.leading, 70)
                row(icon: "square.and.arrow.up", title: "Export laps", sub: "Copy to clipboard", action: onExport)
                Rectangle().fill(p.sep).frame(height: 0.5).padding(.leading, 70)
                row(icon: "gearshape", title: "Settings", sub: "Theme, accent, display", action: onSettings)
            }
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        let p = state.palette
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(p.text)
                    .frame(width: 34, height: 34)
                    .background(p.chipBg, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(p.text)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(p.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(p.faint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings panel

struct SettingsPanel: View {
    let onClose: () -> Void
    @EnvironmentObject var state: AppState

    var body: some View {
        OverlayShell(title: "Settings", onClose: onClose) {
            ScrollView {
                VStack(spacing: 20) {
                    themeSection
                    accentSection
                    displaySection
                    privacySection
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private var themeSection: some View {
        section(title: "THEME") {
            VStack(spacing: 0) {
                ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { i, t in
                    themeRow(theme: t, last: i == AppTheme.allCases.count - 1)
                }
            }
        }
    }

    private func themeRow(theme t: AppTheme, last: Bool) -> some View {
        let p = state.palette
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { state.setTheme(t) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Palette(theme: t).bg)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(p.sep, lineWidth: 1))
                Text(t.label)
                    .font(.system(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(p.text)
                Spacer()
                if state.theme == t {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(state.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle().fill(p.sep).frame(height: 0.5).padding(.leading, 48)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var accentSection: some View {
        section(title: "ACCENT") {
            HStack {
                Text("Color")
                    .font(.system(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(state.palette.text)
                Spacer()
                HStack(spacing: 8) {
                    ForEach(state.accentSwatches, id: \.self) { c in
                        Button {
                            state.accentHex = c
                        } label: {
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(
                                        state.accentHex == c ? state.palette.text : state.palette.sep,
                                        lineWidth: state.accentHex == c ? 2 : 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var displaySection: some View {
        section(title: "DISPLAY") {
            VStack(spacing: 0) {
                toggleRow(title: "Big numerals",
                          sub: "Larger timer readout",
                          on: $state.bigNumerals)
                Rectangle().fill(state.palette.sep).frame(height: 0.5).padding(.leading, 16)
                toggleRow(title: "Quick picks menu",
                          sub: "Long-press a lap for presets",
                          on: $state.showQuick)
                Rectangle().fill(state.palette.sep).frame(height: 0.5).padding(.leading, 16)
                toggleRow(title: "Parallel laps",
                          sub: "Each lap tracks time until session stops",
                          on: $state.concurrentLaps)
            }
        }
    }

    private var privacySection: some View {
        let p = state.palette
        return section(title: "PRIVACY") {
            VStack(alignment: .leading, spacing: 0) {
                Text("LapLog stores all session data locally on your device. We do not collect, transmit, or store any personal information.")
                    .font(.system(size: 13))
                    .foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Rectangle().fill(p.sep).frame(height: 0.5).padding(.leading, 16)

                Link(destination: URL(string: "https://javorraca.github.io/laplog-privacy/")!) {
                    HStack {
                        Text("Read online")
                            .font(.system(size: 15))
                            .tracking(-0.2)
                            .foregroundStyle(p.text)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(p.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleRow(title: String, sub: String, on: Binding<Bool>) -> some View {
        let p = state.palette
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .tracking(-0.2)
                    .foregroundStyle(p.text)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(p.muted)
            }
            Spacer()
            Toggle("", isOn: on)
                .labelsHidden()
                .tint(state.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func section<Body: View>(title: String, @ViewBuilder _ body: () -> Body) -> some View {
        let p = state.palette
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(p.muted)
                .padding(.horizontal, 20)
            body()
                .background(p.card, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
        }
    }
}
