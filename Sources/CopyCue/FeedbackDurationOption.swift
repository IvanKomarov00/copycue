import Foundation

enum FeedbackDurationOption: String, CaseIterable, Identifiable {
    case short
    case medium
    case long

    static let defaultsKey = "cursorFeedbackDuration"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .short:
            return "Short"
        case .medium:
            return "Medium"
        case .long:
            return "Long"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .short:
            return 0.5
        case .medium:
            return 1.0
        case .long:
            return 2.0
        }
    }

    var durationLabel: String {
        switch self {
        case .short:
            return "0.5 s"
        case .medium:
            return "1 s"
        case .long:
            return "2 s"
        }
    }

    static var current: FeedbackDurationOption {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey)
        return rawValue.flatMap(FeedbackDurationOption.init(rawValue:)) ?? .medium
    }
}
