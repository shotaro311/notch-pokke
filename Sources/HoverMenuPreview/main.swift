import AppKit
import Combine
import QuartzCore
import SwiftUI

private enum Layout {
    static let pillHeight: CGFloat = 33
    static let topEdgeOverfill: CGFloat = 3
    static let notchHandleWidth: CGFloat = 54
    static let fallbackNotchWidth: CGFloat = 185
    static var defaultPillWidth: CGFloat {
        notchHandleWidth + fallbackNotchWidth
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let pillSize = NSSize(width: Layout.defaultPillWidth, height: Layout.pillHeight)
    private let previewSize = NSSize(width: 472, height: 312)
    private let previewGap: CGFloat = 0
    private let previewOpenDuration: TimeInterval = 0.32
    private let previewCloseDelay: TimeInterval = 0.06
    private let previewCloseDuration: TimeInterval = 0.32

    private var pillWindow: NSPanel?
    private var previewWindow: NSPanel?
    private var closeTask: DispatchWorkItem?
    private var revealTask: DispatchWorkItem?
    private var previewAnimationToken = 0
    private let previewMotion = PreviewMotionModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configurePillWindow()
        configurePreviewWindow()
        positionWindows()
        pillWindow?.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func configurePillWindow() {
        let panel = makePanel(size: pillSize)
        panel.hasShadow = false
        panel.contentViewController = NSHostingController(
            rootView: HoverPill(
                onEnter: { [weak self] in self?.showPreview() },
                onExit: { [weak self] in self?.scheduleClose() },
                onTap: { [weak self] in self?.togglePreview() }
            )
        )
        pillWindow = panel
    }

    private func configurePreviewWindow() {
        let hoverState = HoverState(
            onEnter: { [weak self] in self?.cancelClose() },
            onExit: { [weak self] in self?.scheduleClose() }
        )

        let panel = makePanel(size: previewSize)
        panel.hasShadow = true
        panel.contentViewController = NSHostingController(
            rootView: HoverPanel(hoverState: hoverState, motion: previewMotion)
        )
        previewWindow = panel
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        return panel
    }

    @objc private func screenParametersChanged() {
        positionWindows()
    }

    private func positionWindows() {
        guard let screen = targetScreen() else { return }

        let frames = windowFrames(on: screen)
        pillWindow?.setFrame(frames.pill, display: true)

        if previewWindow?.isVisible == true {
            previewWindow?.setFrame(frames.preview, display: true)
        } else {
            previewWindow?.setFrame(frames.preview, display: false)
        }
    }

    private func togglePreview() {
        if previewWindow?.isVisible == true {
            closePreview()
        } else {
            showPreview()
        }
    }

    private func showPreview() {
        cancelClose()

        guard let screen = targetScreen(), let previewWindow else { return }
        let frames = windowFrames(on: screen)
        pillWindow?.setFrame(frames.pill, display: true)

        previewAnimationToken += 1
        let token = previewAnimationToken
        revealTask?.cancel()

        if previewWindow.isVisible, previewWindow.alphaValue > 0.98 {
            previewWindow.ignoresMouseEvents = false
            previewWindow.setFrame(frames.preview, display: true)
            setPreviewContentVisible(true, animated: true)
            return
        }

        setPreviewContentVisible(false, animated: false)
        previewWindow.alphaValue = shouldReduceMotion ? 1 : 0.9
        previewWindow.ignoresMouseEvents = true
        previewWindow.setFrame(shouldReduceMotion ? frames.preview : frames.collapsedPreview, display: true)
        previewWindow.orderFrontRegardless()

        if shouldReduceMotion {
            previewWindow.ignoresMouseEvents = false
            setPreviewContentVisible(true, animated: false)
            return
        }

        revealPreviewContent(after: 0.08)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = previewOpenDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.96, 0.28, 1.0)
            previewWindow.animator().setFrame(frames.preview, display: true)
            previewWindow.animator().alphaValue = 1
        } completionHandler: { [weak self, weak previewWindow] in
            Task { @MainActor in
                guard let self, let previewWindow, self.previewAnimationToken == token else { return }
                previewWindow.setFrame(frames.preview, display: true)
                previewWindow.alphaValue = 1
                previewWindow.ignoresMouseEvents = false
            }
        }
    }

    private func scheduleClose() {
        closeTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, !self.isMouseInsideHoverRegion() else { return }
            self.closePreview()
        }
        closeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + previewCloseDelay, execute: task)
    }

    private func cancelClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    private func closePreview() {
        revealTask?.cancel()
        guard let previewWindow, previewWindow.isVisible else { return }

        previewAnimationToken += 1
        let token = previewAnimationToken

        guard !shouldReduceMotion, let screen = previewWindow.screen ?? targetScreen() else {
            setPreviewContentVisible(false, animated: false)
            previewWindow.orderOut(nil)
            previewWindow.alphaValue = 1
            return
        }

        let frames = windowFrames(on: screen)
        previewWindow.ignoresMouseEvents = true
        hidePreviewContent(after: previewCloseDuration - 0.08, token: token)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = previewCloseDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.72, 0.0, 0.82, 0.04)
            previewWindow.animator().setFrame(frames.collapsedPreview, display: true)
            previewWindow.animator().alphaValue = 0
        } completionHandler: { [weak self, weak previewWindow] in
            Task { @MainActor in
                guard let self, let previewWindow, self.previewAnimationToken == token else { return }
                self.setPreviewContentVisible(false, animated: false)
                previewWindow.orderOut(nil)
                previewWindow.alphaValue = 1
                previewWindow.ignoresMouseEvents = false
                previewWindow.setFrame(frames.preview, display: false)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + previewCloseDuration + 0.03) { [weak self, weak previewWindow] in
            Task { @MainActor in
                guard let self, let previewWindow, self.previewAnimationToken == token else { return }
                self.setPreviewContentVisible(false, animated: false)
                previewWindow.orderOut(nil)
                previewWindow.alphaValue = 1
                previewWindow.ignoresMouseEvents = false
                previewWindow.setFrame(frames.preview, display: false)
            }
        }
    }

    private func isMouseInsideHoverRegion() -> Bool {
        let location = NSEvent.mouseLocation
        let pillContainsMouse = pillWindow?.frame.insetBy(dx: -4, dy: -4).contains(location) ?? false
        let previewContainsMouse = previewWindow?.frame.insetBy(dx: -4, dy: -4).contains(location) ?? false
        return pillContainsMouse || previewContainsMouse
    }

    private func targetScreen() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }

    private func windowFrames(on screen: NSScreen) -> (
        pill: NSRect,
        preview: NSRect,
        collapsedPreview: NSRect
    ) {
        let notch = notchMetrics(on: screen)
        let pillWidth = Layout.notchHandleWidth + notch.width
        let pillX = notch.minX - Layout.notchHandleWidth
        let pillY = screen.frame.maxY - pillSize.height
        let pillFrame = NSRect(x: pillX, y: pillY, width: pillWidth, height: pillSize.height)

        let previewX = screen.frame.midX - previewSize.width / 2
        let previewY = pillFrame.minY - previewSize.height - previewGap
        let previewFrame = NSRect(x: previewX, y: previewY, width: previewSize.width, height: previewSize.height)

        let collapsedSize = NSSize(width: 72, height: 12)
        let collapsedFrame = NSRect(
            x: notch.centerX - collapsedSize.width / 2,
            y: pillFrame.midY - collapsedSize.height / 2,
            width: collapsedSize.width,
            height: collapsedSize.height
        )

        return (pillFrame, previewFrame, collapsedFrame)
    }

    private func notchMetrics(on screen: NSScreen) -> (minX: CGFloat, width: CGFloat, centerX: CGFloat) {
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           rightArea.minX > leftArea.maxX {
            let minX = leftArea.maxX
            let width = rightArea.minX - leftArea.maxX
            return (minX, width, minX + width / 2)
        }

        let minX = screen.frame.midX - Layout.fallbackNotchWidth / 2
        return (minX, Layout.fallbackNotchWidth, screen.frame.midX)
    }

    private var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func revealPreviewContent(after delay: TimeInterval) {
        let task = DispatchWorkItem { [weak self] in
            self?.setPreviewContentVisible(true, animated: true)
        }
        revealTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func hidePreviewContent(after delay: TimeInterval, token: Int) {
        let task = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.previewAnimationToken == token else { return }
                self.setPreviewContentVisible(false, animated: true)
            }
        }
        revealTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func setPreviewContentVisible(_ isVisible: Bool, animated: Bool) {
        guard animated else {
            previewMotion.contentVisible = isVisible
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            previewMotion.contentVisible = isVisible
        }
    }
}

@MainActor
final class PreviewMotionModel: ObservableObject {
    @Published var contentVisible = false
}

struct TopDockedPillShape: InsettableShape {
    var radius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(radius, rect.height / 2, rect.width / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> TopDockedPillShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct HoverPill: View {
    let onEnter: () -> Void
    let onExit: () -> Void
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            TopDockedPillShape(radius: 10)
                .fill(Color.black.opacity(0.94))

            TopDockedPillShape(radius: 10)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.94))
                    .frame(height: Layout.topEdgeOverfill)

                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            ZStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(width: Layout.notchHandleWidth, height: Layout.pillHeight)
        }
        .frame(minWidth: Layout.notchHandleWidth, idealWidth: Layout.defaultPillWidth, maxWidth: .infinity)
        .frame(height: Layout.pillHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { inside in
            inside ? onEnter() : onExit()
        }
    }
}

struct HoverState {
    let onEnter: () -> Void
    let onExit: () -> Void
}

private enum PanelMode {
    case sessions
    case usage
}

struct HoverPanel: View {
    let hoverState: HoverState
    @ObservedObject var motion: PreviewMotionModel
    @State private var mode: PanelMode = .sessions

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.025))

            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))

                if mode == .sessions {
                    sessions
                } else {
                    usage
                }
            }
            .opacity(motion.contentVisible ? 1 : 0)
            .scaleEffect(motion.contentVisible ? 1 : 0.92, anchor: .top)
            .offset(y: motion.contentVisible ? 0 : -14)
            .blur(radius: motion.contentVisible ? 0 : 3)
        }
        .frame(width: 472, height: 312)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { inside in
            inside ? hoverState.onEnter() : hoverState.onExit()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("3 Sessions")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button {
                mode = .sessions
            } label: {
                Image(systemName: "rectangle.stack")
            }
            .buttonStyle(IconButtonStyle(selected: mode == .sessions))
            .help("Sessions")

            Button {
                mode = .usage
            } label: {
                Image(systemName: "chart.bar.xaxis")
            }
            .buttonStyle(IconButtonStyle(selected: mode == .usage))
            .help("Usage")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle(selected: false))
            .help("Quit demo")
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
    }

    private var sessions: some View {
        VStack(spacing: 10) {
            SessionRow(
                title: "AgentPeek",
                status: "Codex is waiting for your input",
                meta: "13  14  +232  -78",
                age: "21m",
                selected: false
            )
            SessionRow(
                title: "AgentPeek",
                status: "Claude is waiting for your input",
                meta: "3  14  +60  -40",
                age: "20m",
                selected: false
            )
            SessionRow(
                title: "AgentPeek",
                status: "Codex is waiting for your input",
                meta: "3  52  +276  -94",
                age: "20m",
                selected: true
            )
        }
        .padding(14)
    }

    private var usage: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                Text("Back to Sessions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Button {
                    mode = .sessions
                } label: {
                    Image(systemName: "arrow.uturn.left")
                }
                .buttonStyle(IconButtonStyle(selected: false))
            }

            UsageBlock(
                name: "Claude",
                symbol: "car.fill",
                color: .orange,
                primary: 0.07,
                secondary: 0.01,
                resetText: "resets in 3h 57m"
            )
            UsageBlock(
                name: "Codex",
                symbol: "hexagon.fill",
                color: .cyan,
                primary: 0.36,
                secondary: 0.08,
                resetText: "resets in 3h 30m"
            )
        }
        .padding(18)
    }
}

struct SessionRow: View {
    let title: String
    let status: String
    let meta: String
    let age: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                        .foregroundStyle(.white)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.28))

                    Text(status)
                        .foregroundStyle(Color(red: 0.92, green: 0.78, blue: 0.28))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }

                Text(meta)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            Text(age)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))

            Text("Cursor")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 12)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Color.white.opacity(0.11) : Color.white.opacity(0.035))
        )
    }
}

struct UsageBlock: View {
    let name: String
    let symbol: String
    let color: Color
    let primary: Double
    let secondary: Double
    let resetText: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                }

                Meter(label: "5H", value: primary, color: color, trailing: resetText)
                Meter(label: "7D", value: secondary, color: color, trailing: "refills Sun")
            }
        }
    }
}

struct Meter: View {
    let label: String
    let value: Double
    let color: Color
    let trailing: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(trailing)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(color)
                            .frame(width: max(10, proxy.size.width * value))
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.34))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
