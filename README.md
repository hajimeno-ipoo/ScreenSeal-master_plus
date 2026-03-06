<img src="ScreenSeal/Resources/Assets.xcassets/icon.appiconset/icon_385x385.png" width="128" alt="ScreenSeal Icon">

# ScreenSeal_plus

A macOS menu bar app for hiding sensitive information on screen with mosaic overlays.

Place ScreenSeal's mosaic windows over passwords, personal data, or other sensitive content during screen recordings and screenshots. The mosaic window itself is invisible to screenshots and screen sharing — only the mosaic effect is captured.

[日本語版 README はこちら](README.ja.md)

## Features

- **Real-time Mosaic** - Captures and pixelates the screen content behind the window in real time
- **3 Filter Types** - Pixellate / Gaussian Blur / Crystallize
- **Intensity Control** - Adjust via right-click menu slider or scroll wheel
- **Multiple Windows** - Place multiple mosaic regions simultaneously
- **Menu Bar Management** - List all windows, toggle visibility
- **Multi-Display Support** - Works across multiple monitors
- **Layout Presets** - Save and instantly recall window arrangements (multiple presets supported)
- **Persistent Settings** - Mosaic type and intensity are preserved across app restarts
- **Still Screenshot Capture** - Save a single PNG with mosaics applied from the menu bar
- **Screen Recording** - Record a single display to MP4 from the menu bar
- **Save Preview Overlay** - Show a thumbnail on screen after saving a screenshot or recording
- **Open Action Selection** - Choose Finder / Preview for screenshots, Finder / QuickTime for recordings
- **Recording Countdown** - Shows a 3-second countdown before recording starts
- **Recording Target Modes** - Capture a full display, a selected window, or a selected region
- **Click Zoom** - While the primary mouse button is pressed, zooms toward the cursor (1.8x with smooth easing)
- **Custom Cursor Colors** - Pick separate colors and opacity for cursor highlight and click ring

## Requirements

- macOS 14.0 or later
- Screen Recording permission (a system dialog will appear on first launch)
- Screen recording feature requires macOS 15.0 or later

## Installation

Download the latest `ScreenSeal.zip` from the [Releases](https://github.com/nyanko3141592/ScreenSeal/releases) page, extract it, and move `ScreenSeal.app` to your Applications folder.

## Usage

1. Launch the app — an icon appears in the menu bar
2. Click **New Mosaic Window** from the menu to create a mosaic window
3. Drag the window to cover the area you want to hide; drag the edges to resize
4. **Right-click** to open the context menu and change the filter type or intensity
5. Use the **scroll wheel** to quickly adjust intensity
6. Toggle window visibility from the menu bar
7. Choose **Capture Mode**: **Record** or **Screenshot**
8. Choose **Capture Target**: **Full Display**, **Window**, or **Select Region...**
9. In **Record** mode, click **Start Recording** to save MP4 to `~/Movies/ScreenSeal/`
10. In **Screenshot** mode, click the side menu bar button or **Take Screenshot** to save PNG to `~/Pictures/ScreenSeal/`
11. Pick **Screenshot Click Action**: **Finder** or **Preview**
12. Pick **Recording Click Action**: **Finder** or **QuickTime**
13. After saving, a thumbnail preview appears on screen; click it to open the saved file with the selected app
14. A 3-second countdown appears before recording starts
15. Hold primary click while recording to trigger click-zoom
16. Set **Cursor Highlight Color** and **Click Ring Color** before recording to customize the overlay look

## Build

```bash
xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release build
```

## Tech Stack

- Swift / SwiftUI / AppKit
- ScreenCaptureKit (screen capture)
- Core Image (mosaic filter processing)
- Metal (GPU acceleration)

## License

MIT
