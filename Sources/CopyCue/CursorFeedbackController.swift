import AppKit
import CopyCueCore
import QuartzCore

@MainActor
final class CursorFeedbackController: NSObject {
    enum Style {
        case copied
        case restored

        var cursorColor: NSColor {
            .systemBlue
        }

    }

    private let initialSize = NSSize(width: 30, height: 20)
    private let shadowMargin: CGFloat = 6
    private let panel: NSPanel
    private let feedbackView: CursorFeedbackView
    private var animationGeneration = 0
    private var cursorFollowTimer: Timer?
    private var activePosition = CursorFeedbackPosition.below

    override init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        feedbackView = CursorFeedbackView(frame: NSRect(origin: .zero, size: initialSize))
        super.init()

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient
        ]
        panel.contentView = feedbackView
    }

    func show(style: Style) {
        animationGeneration += 1
        let generation = animationGeneration
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        activePosition = CursorFeedbackPosition.current

        startFollowingCursor()
        panel.orderFrontRegardless()
        let animationDuration = FeedbackDurationOption.current.seconds
        feedbackView.animate(
            color: style.cursorColor,
            reduceMotion: reduceMotion,
            duration: animationDuration
        )

        let visibleDuration = animationDuration + 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) { [weak self] in
            guard let self, generation == self.animationGeneration else {
                return
            }
            self.cursorFollowTimer?.invalidate()
            self.cursorFollowTimer = nil
            self.panel.orderOut(nil)
        }
    }

    private func startFollowingCursor() {
        cursorFollowTimer?.invalidate()
        updatePanelPosition()

        let timer = Timer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(updatePanelPosition),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        cursorFollowTimer = timer
    }

    @objc
    private func updatePanelPosition() {
        let pointer = NSEvent.mouseLocation
        let layout = currentLayout()
        let placement = CursorFeedbackGeometry.placement(
            pointer: pointer,
            requestedPosition: activePosition,
            layout: layout,
            shadowMargin: shadowMargin,
            screenFrame: screenFrame(containing: pointer)
        )
        panel.setFrame(placement.panelFrame, display: false)
        feedbackView.updateCapsuleFrame(placement.capsuleFrame)
    }

    private func screenFrame(containing point: NSPoint) -> NSRect? {
        NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        }?.frame ?? NSScreen.main?.frame
    }

    private func currentLayout() -> CursorFeedbackLayout {
        guard let cursor = NSCursor.currentSystem else {
            return arrowLayout
        }

        let matchesColumnResize: Bool
        let matchesRowResize: Bool
        if #available(macOS 15.0, *) {
            matchesColumnResize = cursorMatches(cursor, NSCursor.columnResize)
            matchesRowResize = cursorMatches(cursor, NSCursor.rowResize)
        } else {
            matchesColumnResize = false
            matchesRowResize = false
        }

        if cursorMatches(cursor, NSCursor.iBeam)
            || cursorMatches(cursor, NSCursor.iBeamCursorForVerticalLayout) {
            return cursorLayout(
                for: cursor,
                length: 16,
                thickness: 3,
                horizontalCenterOffset: 0,
                belowDistance: 13
            )
        }

        if cursorMatches(cursor, NSCursor.resizeLeftRight)
            || cursorMatches(cursor, NSCursor.resizeLeft)
            || cursorMatches(cursor, NSCursor.resizeRight)
            || matchesColumnResize {
            return cursorLayout(
                for: cursor,
                length: 26,
                thickness: 3.5,
                horizontalCenterOffset: 0,
                belowDistance: 15
            )
        }

        if cursorMatches(cursor, NSCursor.resizeUpDown)
            || cursorMatches(cursor, NSCursor.resizeUp)
            || cursorMatches(cursor, NSCursor.resizeDown)
            || matchesRowResize {
            return cursorLayout(
                for: cursor,
                length: 8,
                thickness: 3,
                horizontalCenterOffset: 0,
                belowDistance: 17
            )
        }

        if cursorMatches(cursor, NSCursor.pointingHand)
            || cursorMatches(cursor, NSCursor.openHand)
            || cursorMatches(cursor, NSCursor.closedHand) {
            return cursorLayout(
                for: cursor,
                length: 18,
                thickness: 3.5,
                horizontalCenterOffset: 3,
                belowDistance: 26
            )
        }

        if cursorMatches(cursor, NSCursor.crosshair) {
            return cursorLayout(
                for: cursor,
                length: 13,
                thickness: 3.5,
                horizontalCenterOffset: 0,
                belowDistance: 15
            )
        }

        if cursorMatches(cursor, NSCursor.arrow) {
            return arrowLayout(for: cursor)
        }

        return fallbackLayout(for: cursor)
    }

    private var arrowLayout: CursorFeedbackLayout {
        arrowLayout(for: nil)
    }

    private func arrowLayout(for cursor: NSCursor?) -> CursorFeedbackLayout {
        cursorLayout(
            for: cursor,
            length: 15,
            thickness: 3.5,
            horizontalCenterOffset: 4.5,
            belowDistance: 18
        )
    }

    private func cursorMatches(_ cursor: NSCursor, _ reference: NSCursor) -> Bool {
        let size = cursor.image.size
        let referenceSize = reference.image.size
        let hotSpot = cursor.hotSpot
        let referenceHotSpot = reference.hotSpot

        return abs(size.width - referenceSize.width) < 0.75
            && abs(size.height - referenceSize.height) < 0.75
            && abs(hotSpot.x - referenceHotSpot.x) < 0.75
            && abs(hotSpot.y - referenceHotSpot.y) < 0.75
    }

    private func fallbackLayout(for cursor: NSCursor) -> CursorFeedbackLayout {
        let size = cursor.image.size
        let hotSpot = cursor.hotSpot

        guard size.width > 0, size.height > 0 else {
            return arrowLayout
        }

        let width = min(max(size.width * 0.65, 10), 24)
        let cursorCenterOffset = size.width / 2 - hotSpot.x
        let downExtent = max(size.height - hotSpot.y, 0)
        let topDistance = min(max(downExtent + 2, 14), 30)

        return cursorLayout(
            for: cursor,
            length: width,
            thickness: 3.5,
            horizontalCenterOffset: cursorCenterOffset,
            belowDistance: topDistance
        )
    }

    private func cursorLayout(
        for cursor: NSCursor?,
        length: CGFloat,
        thickness: CGFloat,
        horizontalCenterOffset: CGFloat,
        belowDistance: CGFloat
    ) -> CursorFeedbackLayout {
        let centeredOnHotSpot: CGFloat = 0
        let below = CursorFeedbackSideLayout(
            length: length,
            thickness: thickness,
            centerOffset: horizontalCenterOffset,
            distance: belowDistance
        )
        let fallbackAbove = CursorFeedbackSideLayout(
            length: length,
            thickness: thickness,
            centerOffset: centeredOnHotSpot,
            distance: belowDistance
        )
        let fallbackSide = CursorFeedbackSideLayout.cursorSideIndicator(
            baseLength: length,
            thickness: thickness,
            distance: belowDistance
        )
        let fallbackLayout = CursorFeedbackLayout(
            below: below,
            left: fallbackSide,
            above: fallbackAbove,
            right: fallbackSide
        )

        guard let cursor else {
            return fallbackLayout
        }

        let size = cursor.image.size
        let hotSpot = cursor.hotSpot
        let metrics = [size.width, size.height, hotSpot.x, hotSpot.y]
        let hasUsableMetrics = metrics.allSatisfy(\.isFinite)
            && size.width > 0
            && size.height > 0
            && hotSpot.x >= 0
            && hotSpot.y >= 0
            && hotSpot.x <= size.width
            && hotSpot.y <= size.height

        guard hasUsableMetrics else {
            return fallbackLayout
        }

        let edgeGap: CGFloat = 2
        let verticalBaseLength = min(max(size.height * 0.65, 10), 24)
        return CursorFeedbackLayout(
            below: below,
            left: CursorFeedbackSideLayout.cursorSideIndicator(
                baseLength: verticalBaseLength,
                thickness: thickness,
                distance: hotSpot.x + edgeGap
            ),
            above: CursorFeedbackSideLayout(
                length: length,
                thickness: thickness,
                centerOffset: centeredOnHotSpot,
                distance: hotSpot.y + edgeGap
            ),
            right: CursorFeedbackSideLayout.cursorSideIndicator(
                baseLength: verticalBaseLength,
                thickness: thickness,
                distance: size.width - hotSpot.x + edgeGap
            )
        )
    }
}

@MainActor
private final class CursorFeedbackView: NSView {
    private let capsuleLayer = CAShapeLayer()
    private var capsuleFrame = CGRect(x: 6, y: 6, width: 15, height: 3.5)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        capsuleLayer.frame = bounds

        let cornerRadius = min(capsuleFrame.width, capsuleFrame.height) / 2
        let path = CGPath(
            roundedRect: capsuleFrame,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        capsuleLayer.path = path
        capsuleLayer.shadowPath = path
    }

    func updateCapsuleFrame(_ frame: CGRect) {
        capsuleFrame = frame
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func animate(
        color: NSColor,
        reduceMotion: Bool,
        duration: CFTimeInterval
    ) {
        layoutSubtreeIfNeeded()
        capsuleLayer.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        capsuleLayer.fillColor = color.withAlphaComponent(0.92).cgColor
        capsuleLayer.shadowColor = color.cgColor
        capsuleLayer.opacity = 0
        capsuleLayer.transform = CATransform3DIdentity
        CATransaction.commit()

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1, 0]
        opacity.keyTimes = [0, 0.16, 0.68, 1]
        opacity.duration = duration
        opacity.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeIn)
        ]

        var animations: [CAAnimation] = [opacity]

        if !reduceMotion {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.72, 1.04, 1, 1, 1.05]
            scale.keyTimes = [0, 0.18, 0.3, 0.68, 1]
            scale.duration = duration
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .linear),
                CAMediaTimingFunction(name: .easeIn)
            ]
            animations.append(scale)
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.isRemovedOnCompletion = true
        capsuleLayer.add(group, forKey: "copyCueCapsule")
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.masksToBounds = false

        capsuleLayer.shadowOffset = CGSize(width: 0, height: -0.5)
        capsuleLayer.shadowRadius = 1.5
        capsuleLayer.shadowOpacity = 0.22
        layer?.addSublayer(capsuleLayer)
    }
}
