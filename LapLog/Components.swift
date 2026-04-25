import SwiftUI

// MARK: - Icon circle button

struct IconCircle<Content: View>: View {
    let background: Color
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: 34, height: 34)
                .background(background, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }
}

struct ClockGlyph: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 1.4).frame(width: 12, height: 12)
            Path { p in
                p.move(to: CGPoint(x: 6, y: 3))
                p.addLine(to: CGPoint(x: 6, y: 6.2))
                p.addLine(to: CGPoint(x: 8.1, y: 7.4))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            .frame(width: 12, height: 12)
        }
        .frame(width: 15, height: 15)
    }
}

struct HamburgerGlyph: View {
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Capsule().fill(color).frame(width: 10, height: 1.4)
            Capsule().fill(color).frame(width: 10, height: 1.4)
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Big time readout

struct TimeReadout: View {
    let ms: Int
    let color: Color
    let muted: Color
    let big: Bool

    var body: some View {
        let parts = splitTime(fmt(ms))
        let mainSize: CGFloat = big ? 72 : 60   // iPhone-scaled from design's 92 / 72
        let csSize: CGFloat = big ? 30 : 24
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.main)
                .font(.system(size: mainSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .tracking(-1)
            Text(parts.cs)
                .font(.system(size: csSize, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(muted)
        }
    }
}

// MARK: - Second-hand progress ring

struct SecondHandRing: View {
    let ms: Int
    let running: Bool
    let accent: Color
    let track: Color

    var body: some View {
        let frac = (Double(ms) / 1000.0).truncatingRemainder(dividingBy: 60.0) / 60.0
        ZStack {
            Circle()
                .stroke(track.opacity(0.15), lineWidth: 2)
            Circle()
                .trim(from: 0, to: CGFloat(frac))
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(running ? nil : .easeInOut(duration: 0.3), value: frac)
        }
        .padding(8)
    }
}

// MARK: - Primary / ghost round button

struct RoundButton: View {
    let label: String
    let kind: Kind
    let accentHex: UInt32
    let palette: Palette
    let disabled: Bool
    let action: () -> Void

    enum Kind { case primary, ghost }

    @State private var pressed = false

    var body: some View {
        let accent = Color(hex: accentHex)
        let bg: Color = kind == .primary ? accent : palette.chipBg
        let fg: Color = {
            switch kind {
            case .primary: return Color.isLight(hex: accentHex) ? Color(hex: 0x1a1916) : .white
            case .ghost: return palette.text
            }
        }()

        Button(action: { if !disabled { action() } }) {
            Text(label)
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(fg)
                .frame(width: 84, height: 84)
                .background(bg, in: .circle)
                .scaleEffect(pressed ? 0.94 : 1)
                .shadow(color: kind == .primary ? accent.opacity(0.25) : .clear,
                        radius: 12, y: 8)
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(.easeOut(duration: 0.12), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Pulsing running indicator

struct PulseDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.9), radius: on ? 6 : 0)
            .opacity(on ? 1 : 0.3)
            .scaleEffect(on ? 1 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

// MARK: - Editable session title (top-left "Session · Grill")

struct EditableSessionTitle: View {
    @EnvironmentObject var state: AppState
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let label = "SESSION ·"
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(state.palette.muted)
            if editing {
                TextField("", text: $draft)
                    .focused($focused)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(state.palette.text)
                    .frame(width: 140, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(state.accentColor).frame(height: 1.5)
                    }
                    .onSubmit { commit() }
                    .onAppear {
                        draft = state.sessionTitle
                        focused = true
                    }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
            } else {
                HStack(spacing: 4) {
                    Text(state.sessionTitle.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(state.palette.text)
                        .overlay(alignment: .bottom) {
                            DottedUnderline(color: state.palette.faint)
                                .frame(height: 1)
                                .padding(.top, 2)
                        }
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 9))
                        .foregroundStyle(state.palette.muted)
                        .opacity(0.6)
                }
                .contentShape(.rect)
                .onTapGesture {
                    draft = state.sessionTitle
                    editing = true
                }
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmed
        state.sessionTitle = trimmed.isEmpty ? state.sessionTitle : trimmed
        editing = false
    }
}

struct DottedUnderline: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: geo.size.width, y: 0))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5]))
        }
        .frame(height: 1)
    }
}
