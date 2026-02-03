import AppKit

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsContentView(frame: NSRect(x: 0, y: 0, width: 380, height: 750))
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 750),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "VoiceEverywhere Settings"
        w.contentView = contentView
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    func highlightApiKey() {
        showWindow()
        if let view = window?.contentView as? SettingsContentView {
            view.highlightApiKey()
        }
    }
}

// MARK: - Settings Content View

@MainActor
private final class SettingsContentView: NSView {
    private let apiKeyField: NSSecureTextField
    private let llmToggle: NSButton
    private let xaiKeyField: NSSecureTextField
    private let xaiModelField: NSTextField
    private let outputLanguagePopup: NSPopUpButton
    private let formatPresetPopup: NSPopUpButton
    private let addPresetButton: NSButton
    private let removePresetButton: NSButton
    private let editPresetButton: NSButton
    private let saveButton: NSButton

    // Enrollment UI
    private let enrollmentStatusLabel: NSTextField
    private let recordButton: NSButton
    private let progressLabel: NSTextField
    private let enrollWithServiceButton: NSButton
    private let clearEnrollmentButton: NSButton
    private let verificationToggle: NSButton

    private var _termsTV: NSTextView!
    private var _generalTV: NSTextView!

    // Enrollment state
    private var enrollmentManager = EnrollmentManager()
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    private var currentSampleNumber = 1
    private let maxSamples = 5
    private let maxDuration: TimeInterval = 5.0

    private var formatPresets: [LLMProcessor.FormatPreset] = []

    private static let outputLanguageOptions = ["As spoken (no LLM)", "English", "Vietnamese"]

    override init(frame: NSRect) {
        apiKeyField = NSSecureTextField()
        llmToggle = NSButton(checkboxWithTitle: "Enable LLM post-processing", target: nil, action: nil)
        xaiKeyField = NSSecureTextField()
        xaiModelField = NSTextField()
        outputLanguagePopup = NSPopUpButton()
        formatPresetPopup = NSPopUpButton()
        addPresetButton = NSButton(title: "+", target: nil, action: nil)
        removePresetButton = NSButton(title: "−", target: nil, action: nil)
        editPresetButton = NSButton(title: "Edit", target: nil, action: nil)
        saveButton = NSButton(title: "Save", target: nil, action: nil)

        enrollmentStatusLabel = NSTextField(labelWithString: "")
        recordButton = NSButton(title: "Record Sample", target: nil, action: nil)
        progressLabel = NSTextField(labelWithString: "")
        enrollWithServiceButton = NSButton(title: "Enroll with Python Service", target: nil, action: nil)
        clearEnrollmentButton = NSButton(title: "Clear & Re-enroll", target: nil, action: nil)
        verificationToggle = NSButton(checkboxWithTitle: "Enable speaker verification", target: nil, action: nil)

        super.init(frame: frame)

        let m: CGFloat = 20
        let iw = frame.width - m * 2
        var y = frame.height - 20

        // ── Soniox API Key ──
        y = addLabel("Soniox API Key", at: y, margin: m, width: iw)

        apiKeyField.frame = NSRect(x: m, y: y - 24, width: iw, height: 24)
        apiKeyField.placeholderString = "Enter Soniox API key"
        apiKeyField.stringValue = UserDefaults.standard.string(forKey: "soniox_api_key") ?? ""
        apiKeyField.bezelStyle = .roundedBezel
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addSubview(apiKeyField)
        y -= 34

        // ── Context Terms ──
        y = addLabel("Context Terms (comma-separated)", at: y, margin: m, width: iw)

        let (ts, ttv) = makeTextArea(
            frame: NSRect(x: m, y: y - 60, width: iw, height: 60),
            content: UserDefaults.standard.string(forKey: "soniox_context_terms") ?? "",
            placeholder: "SwiftUI, Soniox, macOS, CoreML"
        )
        addSubview(ts)
        _termsTV = ttv
        y -= 68

        // ── General Context ──
        y = addLabel("General Context", at: y, margin: m, width: iw)

        let (gs, gtv) = makeTextArea(
            frame: NSRect(x: m, y: y - 60, width: iw, height: 60),
            content: UserDefaults.standard.string(forKey: "soniox_context_general") ?? "",
            placeholder: "iOS development discussion"
        )
        addSubview(gs)
        _generalTV = gtv
        y -= 68

        // ── Separator ──
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: m, y: y - 1, width: iw, height: 1)
        addSubview(separator)
        y -= 16

        // ── LLM Post-Processing Header ──
        let llmHeader = NSTextField(labelWithString: "LLM Post-Processing (xAI)")
        llmHeader.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        llmHeader.textColor = .labelColor
        llmHeader.frame = NSRect(x: m, y: y - 18, width: iw, height: 18)
        addSubview(llmHeader)
        y -= 26

        // ── Enable Toggle ──
        llmToggle.frame = NSRect(x: m, y: y - 20, width: iw, height: 20)
        llmToggle.font = NSFont.systemFont(ofSize: 12)
        llmToggle.state = UserDefaults.standard.bool(forKey: "llm_enabled") ? .on : .off
        llmToggle.target = self
        llmToggle.action = #selector(llmToggleChanged)
        addSubview(llmToggle)
        y -= 30

        // ── xAI API Key ──
        y = addLabel("xAI API Key", at: y, margin: m, width: iw)

        xaiKeyField.frame = NSRect(x: m, y: y - 24, width: iw, height: 24)
        xaiKeyField.placeholderString = "Enter xAI API key"
        xaiKeyField.stringValue = UserDefaults.standard.string(forKey: "xai_api_key") ?? ""
        xaiKeyField.bezelStyle = .roundedBezel
        xaiKeyField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addSubview(xaiKeyField)
        y -= 34

        // ── Model ──
        y = addLabel("Model", at: y, margin: m, width: iw)

        xaiModelField.frame = NSRect(x: m, y: y - 24, width: iw, height: 24)
        xaiModelField.placeholderString = "grok-3-mini-fast"
        xaiModelField.stringValue = UserDefaults.standard.string(forKey: "xai_model") ?? "grok-3-mini-fast"
        xaiModelField.bezelStyle = .roundedBezel
        xaiModelField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addSubview(xaiModelField)
        y -= 34

        // ── Output Language ──
        y = addLabel("Output Language", at: y, margin: m, width: iw)

        outputLanguagePopup.frame = NSRect(x: m, y: y - 26, width: iw, height: 26)
        outputLanguagePopup.removeAllItems()
        outputLanguagePopup.addItems(withTitles: Self.outputLanguageOptions)
        let savedLang = UserDefaults.standard.string(forKey: "output_language") ?? "As spoken (no LLM)"
        if let idx = Self.outputLanguageOptions.firstIndex(of: savedLang) {
            outputLanguagePopup.selectItem(at: idx)
        }
        outputLanguagePopup.font = NSFont.systemFont(ofSize: 12)
        addSubview(outputLanguagePopup)
        y -= 36

        // ── Format Preset ──
        y = addLabel("Format Preset", at: y, margin: m, width: iw)

        // Load presets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "format_presets"),
           let decoded = try? JSONDecoder().decode([LLMProcessor.FormatPreset].self, from: data) {
            formatPresets = decoded
        }

        let btnSize: CGFloat = 26
        let editW: CGFloat = 46
        let btnGap: CGFloat = 2   // tight grouping between buttons
        let popGap: CGFloat = 8   // breathing room between popup and buttons
        let btnGroupW = btnSize * 2 + editW + btnGap * 2
        let popupW = iw - btnGroupW - popGap
        let btnGroupX = m + popupW + popGap

        formatPresetPopup.frame = NSRect(x: m, y: y - 26, width: popupW, height: 26)
        formatPresetPopup.font = NSFont.systemFont(ofSize: 12)
        addSubview(formatPresetPopup)

        addPresetButton.frame = NSRect(x: btnGroupX, y: y - 26, width: btnSize, height: 26)
        addPresetButton.bezelStyle = .rounded
        addPresetButton.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        addPresetButton.target = self
        addPresetButton.action = #selector(didAddPreset)
        addSubview(addPresetButton)

        removePresetButton.frame = NSRect(x: btnGroupX + btnSize + btnGap, y: y - 26, width: btnSize, height: 26)
        removePresetButton.bezelStyle = .rounded
        removePresetButton.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        removePresetButton.target = self
        removePresetButton.action = #selector(didRemovePreset)
        addSubview(removePresetButton)

        editPresetButton.frame = NSRect(x: btnGroupX + (btnSize + btnGap) * 2, y: y - 26, width: editW, height: 26)
        editPresetButton.bezelStyle = .rounded
        editPresetButton.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        editPresetButton.target = self
        editPresetButton.action = #selector(didEditPreset)
        addSubview(editPresetButton)

        reloadPresetPopup()
        y -= 36

        // ── Save button ──
        saveButton.frame = NSRect(x: m, y: y - 30, width: iw, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        saveButton.target = self
        saveButton.action = #selector(didSave)
        addSubview(saveButton)
        y -= 40

        // ── Separator ──
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.frame = NSRect(x: m, y: y - 1, width: iw, height: 1)
        addSubview(separator2)
        y -= 16

        // ── Voice Enrollment Header ──
        let enrollmentHeader = NSTextField(labelWithString: "Voice Enrollment")
        enrollmentHeader.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        enrollmentHeader.textColor = .labelColor
        enrollmentHeader.frame = NSRect(x: m, y: y - 18, width: iw, height: 18)
        addSubview(enrollmentHeader)
        y -= 26

        // ── Enrollment Status ──
        enrollmentStatusLabel.font = NSFont.systemFont(ofSize: 12)
        enrollmentStatusLabel.textColor = .secondaryLabelColor
        enrollmentStatusLabel.frame = NSRect(x: m, y: y - 16, width: iw, height: 16)
        addSubview(enrollmentStatusLabel)
        y -= 24

        // ── Record Button ──
        recordButton.frame = NSRect(x: m, y: y - 32, width: iw, height: 32)
        recordButton.bezelStyle = .rounded
        recordButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        recordButton.target = self
        recordButton.action = #selector(didRecord)
        addSubview(recordButton)
        y -= 40

        // ── Progress Label ──
        progressLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        progressLabel.textColor = .secondaryLabelColor
        progressLabel.alignment = .center
        progressLabel.frame = NSRect(x: m, y: y - 14, width: iw, height: 14)
        addSubview(progressLabel)
        y -= 22

        // ── Enroll with Python Service Button ──
        enrollWithServiceButton.frame = NSRect(x: m, y: y - 32, width: iw, height: 32)
        enrollWithServiceButton.bezelStyle = .rounded
        enrollWithServiceButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        enrollWithServiceButton.target = self
        enrollWithServiceButton.action = #selector(didEnrollWithService)
        addSubview(enrollWithServiceButton)
        y -= 40

        // ── Clear Button ──
        clearEnrollmentButton.frame = NSRect(x: m, y: y - 28, width: iw, height: 28)
        clearEnrollmentButton.bezelStyle = .rounded
        clearEnrollmentButton.font = NSFont.systemFont(ofSize: 12)
        clearEnrollmentButton.target = self
        clearEnrollmentButton.action = #selector(didClearEnrollment)
        addSubview(clearEnrollmentButton)
        y -= 36

        // ── Verification Toggle ──
        verificationToggle.frame = NSRect(x: m, y: y - 20, width: iw, height: 20)
        verificationToggle.font = NSFont.systemFont(ofSize: 12)
        verificationToggle.state = UserDefaults.standard.bool(forKey: "speaker_verification_enabled") ? .on : .off
        verificationToggle.target = self
        verificationToggle.action = #selector(verificationToggleChanged)
        addSubview(verificationToggle)

        // Set initial enabled state of LLM fields
        llmToggleChanged()

        // Update enrollment UI
        updateEnrollmentUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func highlightApiKey() {
        window?.makeFirstResponder(apiKeyField)
        apiKeyField.wantsLayer = true
        apiKeyField.layer?.borderColor = NSColor.systemRed.cgColor
        apiKeyField.layer?.borderWidth = 2
        apiKeyField.layer?.cornerRadius = 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.apiKeyField.layer?.borderWidth = 0
        }
    }

    @objc private func llmToggleChanged() {
        let enabled = llmToggle.state == .on
        xaiKeyField.isEnabled = enabled
        xaiModelField.isEnabled = enabled
        outputLanguagePopup.isEnabled = enabled
        formatPresetPopup.isEnabled = enabled
        addPresetButton.isEnabled = enabled
        removePresetButton.isEnabled = enabled
        editPresetButton.isEnabled = enabled
    }

    @objc private func didSave() {
        let key = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(key, forKey: "soniox_api_key")

        let termsVal = _termsTV.textColor == .placeholderTextColor ? "" : _termsTV.string
        UserDefaults.standard.set(termsVal, forKey: "soniox_context_terms")

        let generalVal = _generalTV.textColor == .placeholderTextColor ? "" : _generalTV.string
        UserDefaults.standard.set(generalVal, forKey: "soniox_context_general")

        UserDefaults.standard.set(llmToggle.state == .on, forKey: "llm_enabled")

        let xaiKey = xaiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(xaiKey, forKey: "xai_api_key")

        let model = xaiModelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(model.isEmpty ? "grok-3-mini-fast" : model, forKey: "xai_model")

        UserDefaults.standard.set(outputLanguagePopup.titleOfSelectedItem ?? "As spoken (no LLM)", forKey: "output_language")

        savePresets()

        // Save verification setting
        UserDefaults.standard.set(verificationToggle.state == .on, forKey: "speaker_verification_enabled")

        saveButton.title = "Saved!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.saveButton.title = "Save"
        }
    }

    @objc private func verificationToggleChanged() {
        // Toggle state changed - no immediate action needed
        // Will be saved when user clicks Save button
    }

    // MARK: - Preset Management

    private func reloadPresetPopup() {
        formatPresetPopup.removeAllItems()
        formatPresetPopup.addItem(withTitle: "(None)")
        for preset in formatPresets {
            formatPresetPopup.addItem(withTitle: preset.name)
        }
        let activeName = UserDefaults.standard.string(forKey: "active_format_preset") ?? ""
        if let idx = formatPresets.firstIndex(where: { $0.name == activeName }) {
            formatPresetPopup.selectItem(at: idx + 1) // +1 for "(None)"
        } else {
            formatPresetPopup.selectItem(at: 0)
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(formatPresets) {
            UserDefaults.standard.set(data, forKey: "format_presets")
        }
        let selected = formatPresetPopup.titleOfSelectedItem ?? "(None)"
        UserDefaults.standard.set(selected == "(None)" ? "" : selected, forKey: "active_format_preset")
    }

    @objc private func didAddPreset() {
        showPresetAlert(title: "New Format Preset", name: "", instructions: "") { [weak self] name, instructions in
            guard let self else { return }
            self.formatPresets.append(LLMProcessor.FormatPreset(name: name, instructions: instructions))
            self.reloadPresetPopup()
            self.formatPresetPopup.selectItem(withTitle: name)
            self.savePresets()
        }
    }

    @objc private func didRemovePreset() {
        let idx = formatPresetPopup.indexOfSelectedItem
        guard idx > 0 else { return } // Can't remove "(None)"
        formatPresets.remove(at: idx - 1)
        reloadPresetPopup()
        savePresets()
    }

    @objc private func didEditPreset() {
        let idx = formatPresetPopup.indexOfSelectedItem
        guard idx > 0 else { return } // Can't edit "(None)"
        let preset = formatPresets[idx - 1]
        showPresetAlert(title: "Edit Format Preset", name: preset.name, instructions: preset.instructions) { [weak self] name, instructions in
            guard let self else { return }
            self.formatPresets[idx - 1] = LLMProcessor.FormatPreset(name: name, instructions: instructions)
            self.reloadPresetPopup()
            self.formatPresetPopup.selectItem(withTitle: name)
            self.savePresets()
        }
    }

    private func showPresetAlert(title: String, name: String, instructions: String, onSave: @escaping (String, String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let cw: CGFloat = 320
        let instrH: CGFloat = 80
        let containerH: CGFloat = 16 + 24 + 12 + 16 + instrH + 4 // label+field+gap+label+textarea+pad
        let container = NSView(frame: NSRect(x: 0, y: 0, width: cw, height: containerH))

        var cy = containerH

        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .secondaryLabelColor
        cy -= 16
        nameLabel.frame = NSRect(x: 0, y: cy, width: cw, height: 16)
        container.addSubview(nameLabel)

        cy -= 26
        let nameField = NSTextField(frame: NSRect(x: 0, y: cy, width: cw, height: 24))
        nameField.stringValue = name
        nameField.placeholderString = "Preset name"
        nameField.bezelStyle = .roundedBezel
        nameField.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(nameField)

        cy -= 16
        let instrLabel = NSTextField(labelWithString: "Instructions:")
        instrLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        instrLabel.textColor = .secondaryLabelColor
        instrLabel.frame = NSRect(x: 0, y: cy, width: cw, height: 16)
        container.addSubview(instrLabel)

        cy -= (instrH + 2)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: cy, width: cw, height: instrH))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: cw - 4, height: instrH))
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .textBackgroundColor
        textView.string = instructions
        scrollView.documentView = textView
        container.addSubview(scrollView)

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        guard let parentWindow = self.window else { return }
        alert.beginSheetModal(for: parentWindow) { response in
            guard response == .alertFirstButtonReturn else { return }
            let newName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { return }
            let newInstr = textView.string
            onSave(newName, newInstr)
        }
    }

    // MARK: - Enrollment Management

    private func updateEnrollmentUI() {
        let status = EnrollmentManager.getEnrollmentStatus()
        enrollmentStatusLabel.stringValue = status.displayText

        if status.isEnrolled {
            let count = if case .enrolled(let c) = status { c } else { 0 }
            currentSampleNumber = count + 1
        } else {
            currentSampleNumber = 1
        }

        recordButton.title = "Record Sample \(currentSampleNumber)/\(maxSamples)"
        recordButton.isEnabled = currentSampleNumber <= maxSamples
        enrollWithServiceButton.isEnabled = status.isEnrolled
        clearEnrollmentButton.isEnabled = status.isEnrolled
        progressLabel.stringValue = ""

        // Update Python service enrollment status
        updateServiceEnrollmentStatus()
    }

    @objc private func didRecord() {
        if recordingStartTime == nil {
            // Start recording
            startRecording()
        } else {
            // Stop recording
            stopRecording()
        }
    }

    private func startRecording() {
        do {
            try enrollmentManager.startRecording()
            recordingStartTime = Date()

            // Update UI for recording state
            recordButton.title = "Stop Recording"
            enrollWithServiceButton.isEnabled = false
            clearEnrollmentButton.isEnabled = false
            saveButton.isEnabled = false
            progressLabel.stringValue = "Recording: 0.0s / \(Int(maxDuration)).0s"

            // Start timer for progress updates
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRecordingProgress()
                }
            }

            // Play sound feedback
            NSSound.beep()

        } catch {
            showError(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        do {
            _ = try enrollmentManager.stopRecording(sampleNumber: currentSampleNumber)

            // Play sound feedback
            NSSound.beep()

            // Reset UI
            recordingStartTime = nil
            updateEnrollmentUI()
            saveButton.isEnabled = true

            // Show success message
            let status = EnrollmentManager.getEnrollmentStatus()
            if case .enrolled(let count) = status, count >= 3 {
                progressLabel.stringValue = "✓ \(count) samples recorded"
            }

        } catch {
            showError(message: "Failed to save recording: \(error.localizedDescription)")
            enrollmentManager.cancelRecording()
            recordingStartTime = nil
            updateEnrollmentUI()
            saveButton.isEnabled = true
        }
    }

    private func updateRecordingProgress() {
        guard let startTime = recordingStartTime else {
            recordingTimer?.invalidate()
            recordingTimer = nil
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        progressLabel.stringValue = String(format: "Recording: %.1fs / %.1fs", elapsed, maxDuration)

        // Auto-stop after max duration
        if elapsed >= maxDuration {
            stopRecording()
        }
    }

    @objc private func didEnrollWithService() {
        // Disable button during enrollment
        enrollWithServiceButton.isEnabled = false
        progressLabel.stringValue = "Enrolling with Python service..."

        Task {
            do {
                let verifier = SpeakerVerifier()
                let result = try await verifier.enroll()

                await MainActor.run {
                    progressLabel.stringValue = "✅ Enrolled! \(result.samplesProcessed) samples processed in \(String(format: "%.1f", result.processingTimeS))s"
                    enrollWithServiceButton.isEnabled = true

                    // Update enrollment status from service
                    updateServiceEnrollmentStatus()
                }
            } catch VerificationError.noEnrollmentSamples {
                await MainActor.run {
                    showError(message: "No enrollment samples found. Please record 3-5 voice samples first.")
                    progressLabel.stringValue = ""
                    enrollWithServiceButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    showError(message: "Enrollment failed: \(error.localizedDescription)")
                    progressLabel.stringValue = "Enrollment failed"
                    enrollWithServiceButton.isEnabled = true
                }
            }
        }
    }

    @objc private func didClearEnrollment() {
        let alert = NSAlert()
        alert.messageText = "Clear Voice Enrollment?"
        alert.informativeText = "This will delete all recorded voice samples. You will need to re-enroll."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard let parentWindow = self.window else { return }
        alert.beginSheetModal(for: parentWindow) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }

            do {
                try EnrollmentManager.clearEnrollment()
                self?.updateEnrollmentUI()
                self?.progressLabel.stringValue = "Enrollment cleared"
            } catch {
                self?.showError(message: "Failed to clear enrollment: \(error.localizedDescription)")
            }
        }
    }

    private func updateServiceEnrollmentStatus() {
        Task {
            do {
                let verifier = SpeakerVerifier()
                let status = try await verifier.getStatus()
                await MainActor.run {
                    if status.isEnrolled {
                        enrollmentStatusLabel.stringValue = "✅ Enrolled with Python service (\(status.sampleCount) samples)"
                    }
                }
            } catch {
                // Silently fail - service may not be running
            }
        }
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        guard let parentWindow = self.window else { return }
        alert.beginSheetModal(for: parentWindow, completionHandler: nil)
    }

    // MARK: - Helpers

    private func addLabel(_ text: String, at y: CGFloat, margin: CGFloat, width: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: margin, y: y - 14, width: width, height: 14)
        addSubview(label)
        return y - 22
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
        tv.font = NSFont.systemFont(ofSize: 12)
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
