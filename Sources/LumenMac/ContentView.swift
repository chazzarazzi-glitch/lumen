import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: RecorderController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lumen for Mac")
                        .font(.largeTitle.bold())
                    Text("Native local screen recording with ScreenCaptureKit")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await controller.refreshDisplays() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh displays")
                .disabled(controller.isBusy)
            }

            GroupBox("Capture") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Display", selection: $controller.selectedDisplayID) {
                        if controller.displays.isEmpty {
                            Text("No displays available").tag(Optional<UInt32>.none)
                        }
                        ForEach(controller.displays) { display in
                            Text(display.name).tag(Optional(display.id))
                        }
                    }
                    .disabled(controller.isBusy || controller.displays.isEmpty)

                    Toggle("Include system audio", isOn: $controller.includeSystemAudio)
                        .disabled(controller.isBusy)

                    Text("Recordings are saved locally in Movies/Lumen as H.264 MP4 files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await controller.startRecording() }
                } label: {
                    Label("Record", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!controller.canStart)

                Button {
                    Task { await controller.stopRecording() }
                } label: {
                    Label("Stop & Save", systemImage: "stop.circle")
                }
                .disabled(!controller.canStop)

                Spacer()
                Text(controller.elapsedText)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: controller.statusSymbol)
                    .foregroundStyle(controller.statusColor)
                Text(controller.statusMessage)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let url = controller.lastRecordingURL {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(url.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 560)
        .task {
            await controller.refreshDisplays()
        }
    }
}
