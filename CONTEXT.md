# TextLens — Context

## Glossary

| Term | Definition |
|------|-----------|
| **TextLens** | macOS menu bar app for OCR text extraction from screen, clipboard, and images. Open source alternative to Text Lens. |
| **Capture** | The act of selecting a screen region (or sourcing from clipboard/file) and running OCR to extract text. |
| **Overlay Window** | Borderless full-screen NSWindow with drag-to-select for picking a screen region to capture. |
| **OCR Result** | The text string produced by Apple Vision Framework from a captured image. |

## Architecture Decisions

- **Language:** Swift
- **UI Framework:** SwiftUI + AppKit bridge
- **OCR Engine:** Apple Vision Framework (`VNRecognizeTextRequest`)
- **Screen Capture:** Custom overlay window (borderless NSWindow) + `CGWindowListCreateImage`
- **Global Hotkey:** `KeyboardShortcuts` SPM package
- **Distribution:** Open source, build locally, not on App Store
- **Bundle ID:** `dev.dtmkeng.textlens`
- **After-Capture:** Copy to clipboard only (no preview window)
- **Clipboard OCR:** Manual trigger (shortcut-based)
- **Language Detection:** Auto-detect (VNDetectTextRecognitionLevel accurate, revision 3+)
- **Min Deployment:** macOS 13 Ventura
- **Privacy:** No network entitlement (enforced via macOS entitlement)

## v1 Features

- [x] Screen capture → OCR → copy to clipboard
- [x] Global keyboard shortcut to activate screen capture OCR (`⌃⇧X`)
- [x] Global keyboard shortcut to activate clipboard image OCR (`⌘⇧C`)
- [x] Clipboard image OCR (manual trigger)
- [x] No network entitlement

## Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Screen Capture OCR | `⌃⇧X` (Ctrl+Shift+X) |
| Clipboard OCR | `⌘⇧C` (Cmd+Shift+C) |
