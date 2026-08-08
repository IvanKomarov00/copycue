import AppKit

@MainActor
protocol ClipboardMonitorDelegate: AnyObject {
    func clipboardMonitor(_ monitor: ClipboardMonitor, detectedText text: String?)
}

@MainActor
final class ClipboardMonitor: NSObject {
    weak var delegate: ClipboardMonitorDelegate?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    override init() {
        lastChangeCount = pasteboard.changeCount
        super.init()
    }

    func start() {
        guard timer == nil else {
            return
        }

        let timer = Timer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(pollPasteboard),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Writes without reporting the app's own update as a new external copy.
    func replaceClipboardText(with text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    @objc
    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = changeCount
        let text = pasteboard.string(forType: .string)
        delegate?.clipboardMonitor(self, detectedText: text)
    }
}
