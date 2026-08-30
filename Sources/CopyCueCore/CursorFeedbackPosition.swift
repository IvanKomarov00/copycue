import CoreGraphics
import Foundation

public enum CursorFeedbackPosition: String, CaseIterable, Identifiable {
    case below
    case left
    case above
    case right

    public static let defaultsKey = "cursorFeedbackPosition"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .below:
            return "Below"
        case .left:
            return "Left"
        case .above:
            return "Above"
        case .right:
            return "Right"
        }
    }

    public static var current: CursorFeedbackPosition {
        resolve(UserDefaults.standard.string(forKey: defaultsKey))
    }

    public static func resolve(_ rawValue: String?) -> CursorFeedbackPosition {
        rawValue.flatMap(CursorFeedbackPosition.init(rawValue:)) ?? .below
    }

    fileprivate var opposite: CursorFeedbackPosition {
        switch self {
        case .below:
            return .above
        case .left:
            return .right
        case .above:
            return .below
        case .right:
            return .left
        }
    }
}

public struct CursorFeedbackSideLayout: Equatable {
    public let length: CGFloat
    public let thickness: CGFloat
    public let centerOffset: CGFloat
    public let distance: CGFloat

    public init(
        length: CGFloat,
        thickness: CGFloat,
        centerOffset: CGFloat,
        distance: CGFloat
    ) {
        self.length = length
        self.thickness = thickness
        self.centerOffset = centerOffset
        self.distance = distance
    }

    public static func cursorSideIndicator(
        baseLength: CGFloat,
        thickness: CGFloat,
        distance: CGFloat
    ) -> CursorFeedbackSideLayout {
        CursorFeedbackSideLayout(
            length: max(baseLength - 2, thickness * 2),
            thickness: thickness,
            centerOffset: -2,
            distance: distance
        )
    }
}

public struct CursorFeedbackLayout: Equatable {
    public let below: CursorFeedbackSideLayout
    public let left: CursorFeedbackSideLayout
    public let above: CursorFeedbackSideLayout
    public let right: CursorFeedbackSideLayout

    public init(
        below: CursorFeedbackSideLayout,
        left: CursorFeedbackSideLayout,
        above: CursorFeedbackSideLayout,
        right: CursorFeedbackSideLayout
    ) {
        self.below = below
        self.left = left
        self.above = above
        self.right = right
    }

    public func capsuleFrame(
        at pointer: CGPoint,
        position: CursorFeedbackPosition
    ) -> CGRect {
        switch position {
        case .below:
            return CGRect(
                x: pointer.x + below.centerOffset - below.length / 2,
                y: pointer.y - below.distance - below.thickness,
                width: below.length,
                height: below.thickness
            )
        case .left:
            return CGRect(
                x: pointer.x - left.distance - left.thickness,
                y: pointer.y + left.centerOffset - left.length / 2,
                width: left.thickness,
                height: left.length
            )
        case .above:
            return CGRect(
                x: pointer.x + above.centerOffset - above.length / 2,
                y: pointer.y + above.distance,
                width: above.length,
                height: above.thickness
            )
        case .right:
            return CGRect(
                x: pointer.x + right.distance,
                y: pointer.y + right.centerOffset - right.length / 2,
                width: right.thickness,
                height: right.length
            )
        }
    }
}

public struct CursorFeedbackPlacement {
    public let position: CursorFeedbackPosition
    public let panelFrame: CGRect
    public let capsuleFrame: CGRect
}

public enum CursorFeedbackGeometry {
    public static func placement(
        pointer: CGPoint,
        requestedPosition: CursorFeedbackPosition,
        layout: CursorFeedbackLayout,
        shadowMargin: CGFloat,
        screenFrame: CGRect?
    ) -> CursorFeedbackPlacement {
        var position = requestedPosition
        var capsuleFrame = layout.capsuleFrame(at: pointer, position: position)
        var panelFrame = capsuleFrame.insetBy(dx: -shadowMargin, dy: -shadowMargin)

        if let screenFrame, !fitsPrimaryEdge(panelFrame, position: position, in: screenFrame) {
            let opposite = position.opposite
            let oppositeCapsuleFrame = layout.capsuleFrame(at: pointer, position: opposite)
            let oppositePanelFrame = oppositeCapsuleFrame.insetBy(
                dx: -shadowMargin,
                dy: -shadowMargin
            )

            if fitsPrimaryEdge(oppositePanelFrame, position: opposite, in: screenFrame) {
                position = opposite
                capsuleFrame = oppositeCapsuleFrame
                panelFrame = oppositePanelFrame
            }
        }

        if let screenFrame {
            panelFrame = clamp(panelFrame, to: screenFrame)
        }

        return CursorFeedbackPlacement(
            position: position,
            panelFrame: panelFrame,
            capsuleFrame: CGRect(
                x: shadowMargin,
                y: shadowMargin,
                width: capsuleFrame.width,
                height: capsuleFrame.height
            )
        )
    }

    private static func fitsPrimaryEdge(
        _ panelFrame: CGRect,
        position: CursorFeedbackPosition,
        in screenFrame: CGRect
    ) -> Bool {
        switch position {
        case .below:
            return panelFrame.minY >= screenFrame.minY
        case .left:
            return panelFrame.minX >= screenFrame.minX
        case .above:
            return panelFrame.maxY <= screenFrame.maxY
        case .right:
            return panelFrame.maxX <= screenFrame.maxX
        }
    }

    private static func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        guard !bounds.isEmpty else {
            return frame
        }

        var result = frame
        if result.width <= bounds.width {
            result.origin.x = min(
                max(result.origin.x, bounds.minX),
                bounds.maxX - result.width
            )
        } else {
            result.origin.x = bounds.minX
        }

        if result.height <= bounds.height {
            result.origin.y = min(
                max(result.origin.y, bounds.minY),
                bounds.maxY - result.height
            )
        } else {
            result.origin.y = bounds.minY
        }

        return result
    }
}
