import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var startStopItem: NSMenuItem!
    private var partialItem: NSMenuItem!
    private var hotKeyManager: HotKeyManager?
    private var controller: VoiceController?
    private let settingsController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        TextInjector.promptAccessibilityIfNeeded()
        buildStatusItem()
        configureVoiceController()
        registerHotKey()
    }

    private func configureVoiceController() {
        controller = VoiceController(languageHints: ["vi", "en"])

        controller?.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateUI(for: state)
            }
        }

        controller?.onPartial = { [weak self] text in
            DispatchQueue.main.async {
                self?.partialItem.title = "Preview: \(text.prefix(60))"
            }
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setMenuBarIcon("mic")
        statusItem.button?.appearsDisabled = false

        let menu = NSMenu()

        startStopItem = NSMenuItem(title: "Start (⌃⌥Space)", action: #selector(toggle), keyEquivalent: "")
        startStopItem.target = self
        menu.addItem(startStopItem)

        partialItem = NSMenuItem(title: "Preview: –", action: nil, keyEquivalent: "")
        partialItem.isEnabled = false
        menu.addItem(partialItem)

        menu.addItem(NSMenuItem.separator())

        let configureItem = NSMenuItem(title: "Configure…", action: #selector(openSettings), keyEquivalent: ",")
        configureItem.target = self
        menu.addItem(configureItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Request Accessibility Access…", action: #selector(openAccessibilityPane), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func registerHotKey() {
        hotKeyManager = HotKeyManager()
        hotKeyManager?.onHotKey = { [weak self] in
            self?.toggle()
        }
    }

    @objc private func openSettings() {
        settingsController.showWindow()
    }

    @objc private func toggle() {
        let savedKey = UserDefaults.standard.string(forKey: "soniox_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if savedKey.isEmpty {
            settingsController.highlightApiKey()
            return
        }
        controller?.toggle()
    }

    private func updateUI(for state: VoiceController.State) {
        switch state {
        case .idle:
            startStopItem.title = "Start (⌃⌥Space)"
            setMenuBarIcon("mic")
        case .connecting:
            startStopItem.title = "Connecting…"
            setMenuBarIcon("mic.badge.xmark")
        case .listening:
            startStopItem.title = "Stop"
            setMenuBarIcon("mic.fill")
        case .finishing:
            startStopItem.title = "Finishing…"
        case .error(let message):
            startStopItem.title = "Start (⌃⌥Space)"
            setMenuBarIcon("mic")
            showError(message)
        }
    }

    private func setMenuBarIcon(_ symbolName: String) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoiceEverywhere") {
            let configured = image.withSymbolConfiguration(config) ?? image
            configured.isTemplate = true
            statusItem.button?.image = configured
        }
    }

    @objc private func openAccessibilityPane() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "VoiceEverywhere"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
