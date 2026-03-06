import AppKit

@MainActor
final class TextInjector {
    func type(_ text: String) {
        let trusted = AXIsProcessTrusted()
        VELog.write("TextInjector.type called: trusted=\(trusted), text=\(text.prefix(30))")
        guard trusted else {
            VELog.write("TextInjector: NOT trusted, skipping injection")
            return
        }
        let cleaned = text
            .replacingOccurrences(of: "<end>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        VELog.write("TextInjector injecting: \(cleaned.prefix(50))")
        typeText(cleaned)
    }

    private func typeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V to paste
        let vKeyCode: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            VELog.write("TextInjector: failed to create paste CGEvent")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Restore previous clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }

    static func promptAccessibilityIfNeeded() {
        if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
