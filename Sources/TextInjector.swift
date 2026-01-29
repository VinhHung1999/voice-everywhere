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
        for character in text where !character.isNewline {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { continue }

            var units = Array(String(character).utf16)
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    static func promptAccessibilityIfNeeded() {
        if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
