public struct ClipboardHistory: Equatable, Sendable {
    /// Avoids retaining unexpectedly large clipboard values indefinitely. CopyCue
    /// still confirms larger clipboard changes, but does not add them to history.
    public static let maximumRetainedTextUTF8Bytes = 1_048_576

    public private(set) var current: String?
    public private(set) var previous: String?

    public init(current: String? = nil, previous: String? = nil) {
        self.current = current
        self.previous = previous
    }

    /// Captures a new text value while retaining only the current and previous
    /// distinct values. Returns true when the history changed.
    @discardableResult
    public mutating func capture(_ text: String) -> Bool {
        guard !text.isEmpty,
              text != current,
              text.utf8.count <= Self.maximumRetainedTextUTF8Bytes else {
            return false
        }

        previous = current
        current = text
        return true
    }

    /// Promotes the previous value and keeps the displaced current value so the
    /// user can toggle back if needed.
    public mutating func restorePrevious() -> String? {
        guard let previous else {
            return nil
        }

        let displacedCurrent = current
        current = previous
        self.previous = displacedCurrent
        return previous
    }

    public mutating func clear() {
        current = nil
        previous = nil
    }
}
