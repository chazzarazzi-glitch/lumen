@preconcurrency import ScreenCaptureKit
import AVFoundation
import AppKit
import CoreMedia
import CoreVideo
import SwiftUI
import LumenMacCore

struct DisplayOption: Identifiable, Equatable {
    let id: UInt32
    let name: String
}

@MainActor
final class RecorderController: NSObject, ObservableObject {
    @Published var displays: [DisplayOption] = []
    @Published var selectedDisplayID: UInt32?
    @Published var includeSystemAudio = true
    @Published private(set) var isRecording = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var statusMessage = "Choose a display, then press Record."
    @Published private(set) var elapsedText = "00:00"
    @Published private(set) var lastRecordingURL: URL?
    @Published private(set) var hasError = false

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var pendingURL: URL?
    private var elapsedTask: Task<Void, Never>?

    var isBusy: Bool { isRecording || isFinalizing || stream != nil }
    var canStart: Bool { selectedDisplayID != nil && !isBusy && !displays.isEmpty }
    var canStop: Bool { isRecording && !isFinalizing }
    var statusSymbol: String { hasError ? "exclamationmark.triangle.fill" : (isRecording ? "record.circle.fill" : "checkmark.circle") }
    var statusColor: Color { hasError ? .orange : (isRecording ? .red : .green) }

    func refreshDisplays() async {
        guard !isBusy else { return }
        do {
            let content = try await SCShareableContent.current
            let options = content.displays.enumerated().map { index, display in
                let width = Int(display.width)
                let height = Int(display.height)
                let mainLabel = CGDisplayIsMain(display.displayID) != 0 ? " (Main)" : ""
                return DisplayOption(
                    id: display.displayID,
                    name: "Display \(index + 1)\(mainLabel) — \(width) × \(height)"
                )
            }
            displays = options
            if selectedDisplayID == nil || !options.contains(where: { $0.id == selectedDisplayID }) {
                selectedDisplayID = options.first?.id
            }
            hasError = false
            statusMessage = options.isEmpty
                ? "No recordable displays were found."
                : "Ready to record. Screen access is requested by macOS on first use."
        } catch {
            fail(permissionMessage(for: error))
        }
    }

    func startRecording() async {
        guard let displayID = selectedDisplayID, !isBusy else { return }
        do {
            hasError = false
            statusMessage = "Preparing capture…"
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw RecorderError.displayUnavailable
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = evenPixelDimension(filter.contentRect.width * CGFloat(filter.pointPixelScale))
            configuration.height = evenPixelDimension(filter.contentRect.height * CGFloat(filter.pointPixelScale))
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            configuration.queueDepth = 5
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = true
            configuration.capturesAudio = includeSystemAudio
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2

            let outputURL = try RecordingPath.nextURL()
            let outputConfiguration = SCRecordingOutputConfiguration()
            outputConfiguration.outputURL = outputURL
            outputConfiguration.outputFileType = .mp4
            outputConfiguration.videoCodecType = .h264

            let output = SCRecordingOutput(configuration: outputConfiguration, delegate: self)
            let captureStream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try captureStream.addRecordingOutput(output)

            stream = captureStream
            recordingOutput = output
            pendingURL = outputURL
            lastRecordingURL = nil
            elapsedText = "00:00"
            isFinalizing = false
            statusMessage = "Starting recording…"
            try await captureStream.startCapture()
        } catch {
            fail(permissionMessage(for: error))
            clearSession()
        }
    }

    func stopRecording() async {
        guard let stream, isRecording, !isFinalizing else { return }
        isFinalizing = true
        statusMessage = "Finalizing MP4…"
        do {
            try await stream.stopCapture()
        } catch {
            fail("The recording could not be finalized: \(error.localizedDescription)")
            clearSession()
        }
    }

    private func beginElapsedUpdates() {
        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.updateElapsed()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func updateElapsed() {
        guard let seconds = recordingOutput?.recordedDuration.seconds,
              seconds.isFinite, seconds >= 0 else { return }
        let total = Int(seconds.rounded(.down))
        elapsedText = String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func completeSuccessfully() {
        updateElapsed()
        if let url = pendingURL, FileManager.default.fileExists(atPath: url.path) {
            lastRecordingURL = url
            statusMessage = "Recording saved successfully."
            hasError = false
        } else {
            fail("Capture ended, but the MP4 file was not created.")
        }
        clearSession()
    }

    private func fail(_ message: String) {
        hasError = true
        statusMessage = message
    }

    private func clearSession() {
        elapsedTask?.cancel()
        elapsedTask = nil
        stream = nil
        recordingOutput = nil
        pendingURL = nil
        isRecording = false
        isFinalizing = false
    }

    private func permissionMessage(for error: Error) -> String {
        "\(error.localizedDescription) If access was denied, open System Settings → Privacy & Security → Screen & System Audio Recording, enable Lumen for Mac, then reopen the app."
    }

    private func evenPixelDimension(_ value: CGFloat) -> Int {
        max(2, (Int(value.rounded(.down)) / 2) * 2)
    }
}

extension RecorderController: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRecording = true
            self.isFinalizing = false
            self.statusMessage = "Recording…"
            self.beginElapsedUpdates()
        }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.fail("Recording failed: \(message)")
            self?.clearSession()
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor [weak self] in
            self?.completeSuccessfully()
        }
    }
}

extension RecorderController: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, !self.isFinalizing else { return }
            self.fail("Capture stopped unexpectedly: \(message)")
            self.clearSession()
        }
    }
}

private enum RecorderError: LocalizedError {
    case displayUnavailable

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            return "The selected display is no longer available. Refresh the display list and try again."
        }
    }
}
