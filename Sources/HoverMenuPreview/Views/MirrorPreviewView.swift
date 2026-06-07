@preconcurrency import AVFoundation
import OSLog
import SwiftUI

struct MirrorPreviewView: View {
    let isActive: Bool
    @StateObject private var camera = MirrorCameraModel.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)

            CameraPreviewView(
                session: camera.session,
                onReady: {
                    camera.markPreviewReady()
                }
            )
            .scaleEffect(x: -1, y: 1)
            .opacity(camera.shouldShowPreview ? 1 : 0)
            .animation(.easeOut(duration: 0.06), value: camera.shouldShowPreview)

            LinearGradient(
                colors: [
                    .black.opacity(0.18),
                    .clear,
                    .black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            statusOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .onAppear {
            camera.setActive(isActive)
        }
        .onDisappear {
            camera.setActive(false)
        }
        .onChange(of: isActive) { _, newValue in
            camera.setActive(newValue)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch camera.status {
        case .idle:
            if isActive {
                loadingOverlay(text: "Starting camera")
            }
        case .requestingPermission:
            loadingOverlay(text: "Camera permission")
        case .starting:
            loadingOverlay(text: "Starting camera")
        case .running:
            EmptyView()
        case .denied:
            messageOverlay(
                symbol: "camera.fill",
                title: "Camera access is off",
                message: "Enable camera access in System Settings."
            )
        case .restricted:
            messageOverlay(
                symbol: "lock.fill",
                title: "Camera is restricted",
                message: "macOS is blocking camera access."
            )
        case .unavailable:
            messageOverlay(
                symbol: "video.slash.fill",
                title: "Camera not found",
                message: "No available Mac camera was detected."
            )
        case let .failed(message):
            messageOverlay(
                symbol: "exclamationmark.triangle.fill",
                title: "Camera failed",
                message: message
            )
        }
    }

    private func loadingOverlay(text: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.78))

            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
    }

    private func messageOverlay(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(18)
        .frame(maxWidth: 280)
        .background(Color.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 14))
    }
}

@MainActor
final class MirrorCameraModel: ObservableObject {
    private static let logger = Logger(subsystem: "local.codex.hover-menu-preview", category: "mirror-camera")
    static let shared = MirrorCameraModel()

    let session: AVCaptureSession
    @Published private(set) var status: MirrorCameraStatus = .idle

    private let sessionBox = CameraSessionBox()
    private let sessionQueue = DispatchQueue(label: "local.codex.hover-menu-preview.camera")
    private let stopGrace: TimeInterval = 4
    private var isPreparing = false
    private var isSessionPrepared = false
    private var isRequestingPermission = false
    private var isStarting = false
    private var isSessionRunning = false
    private var isPreviewReady = false
    private var wantsCamera = false
    private var pendingStopTask: DispatchWorkItem?

    init() {
        self.session = sessionBox.session
        prepareIfAuthorized()
    }

    var shouldShowPreview: Bool {
        switch status {
        case .starting, .running:
            return true
        default:
            return false
        }
    }

    func setActive(_ active: Bool) {
        guard wantsCamera != active else {
            if active {
                pendingStopTask?.cancel()
                pendingStopTask = nil
                activate()
            }
            return
        }

        wantsCamera = active

        if active {
            pendingStopTask?.cancel()
            pendingStopTask = nil
            prepareIfAuthorized()
            activate()
        } else {
            updateStatus(.idle)
            scheduleStopSession()
        }
    }

    func markPreviewReady() {
        isPreviewReady = true
        prepareIfAuthorized()

        if wantsCamera {
            activate()
        }
    }

    func prepareIfAuthorized() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        prepareSessionIfNeeded()
    }

    private func prepareSessionIfNeeded() {
        guard !isPreparing, !isSessionPrepared else { return }

        isPreparing = true
        Self.logger.notice("camera session prepare requested")

        sessionQueue.async { [weak self, sessionBox] in
            do {
                try sessionBox.configureIfNeeded()
            } catch {
                Task { @MainActor in
                    guard let self else { return }
                    self.isPreparing = false
                    if self.wantsCamera {
                        self.updateStatus(Self.status(for: error))
                    }
                }
                return
            }

            Task { @MainActor in
                guard let self else { return }
                self.isPreparing = false
                self.isSessionPrepared = true
                Self.logger.notice("camera session prepared")
            }
        }
    }

    private func activate() {
        guard isPreviewReady else {
            updateStatus(.starting)
            return
        }

        if isSessionRunning {
            updateStatus(.running)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            requestPermission()
        case .denied:
            updateStatus(.denied)
        case .restricted:
            updateStatus(.restricted)
        @unknown default:
            updateStatus(.failed("Unknown camera permission state."))
        }
    }

    private func requestPermission() {
        guard !isRequestingPermission else { return }

        isRequestingPermission = true
        updateStatus(.requestingPermission)
        Self.logger.notice("camera permission requested")

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }

                self.isRequestingPermission = false
                Self.logger.notice("camera permission result: \(granted ? "granted" : "denied", privacy: .public)")
                guard self.wantsCamera else {
                    self.updateStatus(.idle)
                    return
                }

                granted ? self.startSession() : self.updateStatus(.denied)
            }
        }
    }

    private func startSession() {
        guard !isStarting else { return }

        isStarting = true
        updateStatus(.starting)
        Self.logger.notice("camera session start requested")

        sessionQueue.async { [weak self, sessionBox] in
            do {
                try sessionBox.configureIfNeeded()

                if !sessionBox.session.isRunning {
                    sessionBox.session.startRunning()
                }
            } catch {
                Task { @MainActor in
                    guard let self else { return }
                    self.isStarting = false
                    self.updateStatus(Self.status(for: error))
                }
                return
            }

            Task { @MainActor in
                guard let self else { return }

                self.isStarting = false
                guard self.wantsCamera else {
                    self.scheduleStopSession()
                    return
                }

                self.isSessionPrepared = true
                self.isSessionRunning = sessionBox.session.isRunning
                if self.isSessionRunning {
                    Self.logger.notice("camera session running")
                }
                self.updateStatus(self.isSessionRunning ? .running : .failed("Camera did not start."))
            }
        }
    }

    private func scheduleStopSession() {
        pendingStopTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.stopSessionNow()
        }

        pendingStopTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + stopGrace, execute: task)
    }

    private func stopSessionNow() {
        guard !wantsCamera else { return }
        isStarting = false
        pendingStopTask = nil

        sessionQueue.async { [weak self, sessionBox] in
            let wasRunning = sessionBox.session.isRunning
            if sessionBox.session.isRunning {
                sessionBox.session.stopRunning()
            }

            Task { @MainActor in
                guard let self else { return }
                self.isSessionRunning = false
                if wasRunning {
                    Self.logger.notice("camera session stopped")
                }
                if !self.wantsCamera, self.status != .denied, self.status != .restricted {
                    self.updateStatus(.idle)
                }
            }
        }
    }

    private func updateStatus(_ newStatus: MirrorCameraStatus) {
        guard status != newStatus else { return }
        status = newStatus
    }

    private static func status(for error: Error) -> MirrorCameraStatus {
        if let mirrorError = error as? MirrorCameraError {
            switch mirrorError {
            case .noCamera:
                return .unavailable
            case .inputUnavailable:
                return .failed(mirrorError.localizedDescription)
            }
        }

        return .failed(error.localizedDescription)
    }
}

enum MirrorCameraStatus: Equatable {
    case idle
    case requestingPermission
    case starting
    case running
    case denied
    case restricted
    case unavailable
    case failed(String)
}

enum MirrorCameraError: LocalizedError {
    case noCamera
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .noCamera:
            "No available camera was detected."
        case .inputUnavailable:
            "The selected camera input cannot be used."
        }
    }
}

final class CameraSessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
    private var isConfigured = false

    func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            throw MirrorCameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw MirrorCameraError.inputUnavailable
        }

        session.addInput(input)
        session.commitConfiguration()
        isConfigured = true
    }
}
