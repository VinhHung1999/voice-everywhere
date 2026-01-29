import AppKit

@MainActor
final class MenuSettingsView: NSView {
    private let apiKeyField: NSSecureTextField
    private let termsTextView: NSTextView
    private let generalTextView: NSTextView
    private let saveButton: NSButton

    init(width: CGFloat) {
        let w: CGFloat = max(width, 300)
        let m: CGFloat = 16
        let iw = w - m * 2

        apiKeyField = NSSecureTextField()
        termsTextView = NSTextView()
        generalTextView = NSTextView()
        saveButton = NSButton(title: "Save", target: nil, action: nil)

        // Calculate total height bottom-up
        let totalHeight: CGFloat = 310
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: totalHeight))

        var y = totalHeight - 8

        // ── API Key ──
        let keyLabel = makeLabel("API Key", size: 11, weight: .medium, color: .secondaryLabelColor)
        keyLabel.frame = NSRect(x: m, y: y - 14, width: iw, height: 14)
        addSubview(keyLabel)
        y -= 22

        apiKeyField.frame = NSRect(x: m, y: y - 24, width: iw, height: 24)
        apiKeyField.placeholderString = "Enter Soniox API key"
        apiKeyField.stringValue = UserDefaults.standard.string(forKey: "soniox_api_key") ?? ""
        apiKeyField.bezelStyle = .roundedBezel
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        addSubview(apiKeyField)
        y -= 34

        // ── Terms ──
        let termsLabel = makeLabel("Context Terms (comma-separated)", size: 11, weight: .medium, color: .secondaryLabelColor)
        termsLabel.frame = NSRect(x: m, y: y - 14, width: iw, height: 14)
        addSubview(termsLabel)
        y -= 22

        let (ts, ttv) = makeTextArea(
            frame: NSRect(x: m, y: y - 60, width: iw, height: 60),
            content: UserDefaults.standard.string(forKey: "soniox_context_terms") ?? "",
            placeholder: "SwiftUI, Soniox, macOS, CoreML"
        )
        addSubview(ts)
        y -= 70

        // ── General Context ──
        let generalLabel = makeLabel("General Context", size: 11, weight: .medium, color: .secondaryLabelColor)
        generalLabel.frame = NSRect(x: m, y: y - 14, width: iw, height: 14)
        addSubview(generalLabel)
        y -= 22

        let (gs, gtv) = makeTextArea(
            frame: NSRect(x: m, y: y - 60, width: iw, height: 60),
            content: UserDefaults.standard.string(forKey: "soniox_context_general") ?? "",
            placeholder: "iOS development discussion"
        )
        addSubview(gs)
        y -= 70

        // ── Save button ──
        saveButton.frame = NSRect(x: m, y: y - 26, width: iw, height: 26)
        saveButton.bezelStyle = .rounded
        saveButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        saveButton.target = self
        saveButton.action = #selector(didSave)
        addSubview(saveButton)

        // Store references properly
        // We need to re-assign because the makeTextArea created new instances
        reassignTextViews(terms: ttv, general: gtv)
    }

    required init?(coder: NSCoder) { fatalError() }

    // We can't use setValue forKey on private lets, so use a workaround
    private var _termsTV: NSTextView!
    private var _generalTV: NSTextView!

    private func reassignTextViews(terms: NSTextView, general: NSTextView) {
        _termsTV = terms
        _generalTV = general
    }

    func highlightApiKey() {
        apiKeyField.becomeFirstResponder()
        // Flash border
        apiKeyField.wantsLayer = true
        apiKeyField.layer?.borderColor = NSColor.systemRed.cgColor
        apiKeyField.layer?.borderWidth = 2
        apiKeyField.layer?.cornerRadius = 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.apiKeyField.layer?.borderWidth = 0
        }
    }

    @objc private func didSave() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(key, forKey: "soniox_api_key")

        let termsVal = _termsTV.textColor == .placeholderTextColor ? "" : _termsTV.string
        UserDefaults.standard.set(termsVal, forKey: "soniox_context_terms")

        let generalVal = _generalTV.textColor == .placeholderTextColor ? "" : _generalTV.string
        UserDefaults.standard.set(generalVal, forKey: "soniox_context_general")

        // Visual feedback
        saveButton.title = "Saved!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.saveButton.title = "Save"
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    private func makeTextArea(frame: NSRect, content: String, placeholder: String) -> (NSScrollView, NSTextView) {
        let sv = NSScrollView(frame: frame)
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .bezelBorder
        sv.drawsBackground = true

        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: frame.width - 4, height: frame.height))
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.isRichText = false
        tv.font = NSFont.systemFont(ofSize: 11)
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.autoresizingMask = [.width]
        tv.backgroundColor = .textBackgroundColor

        if content.isEmpty {
            tv.string = placeholder
            tv.textColor = .placeholderTextColor
        } else {
            tv.string = content
            tv.textColor = .textColor
        }
        tv.delegate = PlaceholderTextViewDelegate.shared

        sv.documentView = tv
        return (sv, tv)
    }
}

// MARK: - Placeholder delegate

@MainActor
private final class PlaceholderTextViewDelegate: NSObject, NSTextViewDelegate {
    static let shared = PlaceholderTextViewDelegate()

    func textDidBeginEditing(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView,
              tv.textColor == .placeholderTextColor else { return }
        tv.string = ""
        tv.textColor = .textColor
    }

    func textDidEndEditing(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView,
              tv.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        tv.textColor = .placeholderTextColor
        tv.string = ""
    }
}
