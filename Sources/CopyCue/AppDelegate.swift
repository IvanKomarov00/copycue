import AppKit
import CopyCueCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ClipboardMonitorDelegate, NSMenuDelegate {
    private let clipboardMonitor = ClipboardMonitor()
    private let cursorFeedbackController = CursorFeedbackController()
    private var history = ClipboardHistory()

    private let menu = NSMenu()
    private var statusItem: NSStatusItem?
    private var iconResetGeneration = 0
    private lazy var settingsWindowController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            FeedbackDurationOption.defaultsKey: FeedbackDurationOption.medium.rawValue,
            CursorFeedbackPosition.defaultsKey: CursorFeedbackPosition.below.rawValue
        ])
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        clipboardMonitor.delegate = self
        clipboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }

    func clipboardMonitor(_ monitor: ClipboardMonitor, detectedText text: String?) {
        if let text {
            history.capture(text)
        }

        showConfirmation(style: .copied)
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc
    private func restorePrevious() {
        guard let text = history.restorePrevious() else {
            return
        }

        clipboardMonitor.replaceClipboardText(with: text)
        showConfirmation(style: .restored)
        rebuildMenu()
    }

    @objc
    private func clearHistory() {
        history.clear()
        rebuildMenu()
    }

    @objc
    private func showSettings() {
        settingsWindowController.present()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = statusImage(named: "doc.on.doc")
        item.button?.toolTip = "CopyCue"
        item.menu = menu
        statusItem = item

        menu.delegate = self
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let title = NSMenuItem(title: "CopyCue", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let current = NSMenuItem(
            title: history.current.map { "Current: \(preview($0))" } ?? "Current: No text copied yet",
            action: nil,
            keyEquivalent: ""
        )
        current.isEnabled = false
        menu.addItem(current)

        let previous = NSMenuItem(
            title: history.previous.map { "Restore previous: \(preview($0))" } ?? "Previous: Not available",
            action: history.previous == nil ? nil : #selector(restorePrevious),
            keyEquivalent: ""
        )
        previous.target = self
        previous.isEnabled = history.previous != nil
        menu.addItem(previous)

        menu.addItem(.separator())

        let clear = NSMenuItem(
            title: "Clear Text History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clear.target = self
        clear.isEnabled = history.current != nil || history.previous != nil
        menu.addItem(clear)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit CopyCue",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    private func showConfirmation(style: CursorFeedbackController.Style) {
        cursorFeedbackController.show(style: style)
        pulseStatusIcon(style: style)
    }

    private func pulseStatusIcon(style: CursorFeedbackController.Style) {
        iconResetGeneration += 1
        let generation = iconResetGeneration
        guard let button = statusItem?.button else {
            return
        }

        button.alphaValue = 0
        let symbolName = style == .copied ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill"
        button.image = whiteStatusImage(named: symbolName)
        button.contentTintColor = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, generation == self.iconResetGeneration else {
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                button.animator().alphaValue = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, generation == self.iconResetGeneration else {
                    return
                }

                button.image = self.statusImage(named: "doc.on.doc")
                button.contentTintColor = nil

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    button.animator().alphaValue = 1
                }
            }
        }
    }

    private func statusImage(named symbolName: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "CopyCue"
        )
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let configuredImage = image?.withSymbolConfiguration(configuration) ?? image
        configuredImage?.isTemplate = true
        return configuredImage
    }

    private func whiteStatusImage(named symbolName: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Copy confirmed"
        )
        let pointConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: .white)
        let configuration = pointConfiguration.applying(colorConfiguration)
        let configuredImage = image?.withSymbolConfiguration(configuration) ?? image
        configuredImage?.isTemplate = false
        return configuredImage
    }

    private func preview(_ text: String) -> String {
        let limit = 38
        let sample = text.prefix(limit + 1)
        var singleLine = ""
        singleLine.reserveCapacity(sample.utf8.count)

        for scalar in sample.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                singleLine.append(" ")
            } else {
                singleLine.append(Character(String(scalar)))
            }
        }
        singleLine = singleLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard singleLine.count > limit else {
            return singleLine
        }

        return String(singleLine.prefix(limit - 1)) + "…"
    }
}
