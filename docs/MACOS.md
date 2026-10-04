# Lumen for Mac MVP

This fork adds a separate native macOS recorder while preserving the original Omarchy application.

## Included now

- Native SwiftUI interface
- Display selection through ScreenCaptureKit
- H.264 MP4 screen capture at up to 60 fps
- Optional system audio
- Local recordings in `~/Movies/Lumen`
- Safe unique filenames and Finder reveal

The Mac app does not yet include Lumen Studio editing, replay, window/region capture, microphone/webcam, captions, MCP control, or the Linux GTK interface.

## Requirements

- macOS 15 or newer
- Xcode 16 or newer
- Screen & System Audio Recording permission

## Build

```sh
swift test
./scripts/build-macos.sh
open "dist/Lumen for Mac.app"
```

The first recording attempt may cause macOS to request screen-capture access. If access was denied, enable **Lumen for Mac** under **System Settings → Privacy & Security → Screen & System Audio Recording**, then reopen the app.

Recordings remain local. The app captures the selected display and, when enabled, system audio. It does not upload media or run a network service.
