import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture Screen:", name: .screenCapture)
            KeyboardShortcuts.Recorder("OCR Clipboard:", name: .clipboardOCR)
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 160)
        .padding()
    }
}
