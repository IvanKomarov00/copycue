import AppKit
import QuartzCore

@MainActor
final class CursorFeedbackController: NSObject {
    private struct Layout {
        let width: CGFloat
        let height: CGFloat
        let xOffset: CGFloat
        let topDistance: CGFloat
    }

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
        let capsuleBottom = pointer.y - layout.topDistance - layout.height
        let panelFrame = NSRect(
            x: pointer.x + layout.xOffset - shadowMargin,
            y: capsuleBottom - shadowMargin,
            width: layout.width + shadowMargin * 2,
            height: layout.height + shadowMargin * 2
        )
        panel.setFrame(panelFrame, display: false)
        feedbackView.updateCapsuleFrame(
            CGRect(
                x: shadowMargin,
                y: shadowMargin,
                width: layout.width,
                height: layout.height
            )
        )
    }

    private func currentLayout() -> Layout {
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
            return Layout(width: 16, height: 3, xOffset: -8, topDistance: 13)
        }

        if cursorMatches(cursor, NSCursor.resizeLeftRight)
            || cursorMatches(cursor, NSCursor.resizeLeft)
            || cursorMatches(cursor, NSCursor.resizeRight)
            || matchesColumnResize {
            return Layout(width: 26, height: 3.5, xOffset: -13, topDistance: 15)
        }

        if cursorMatches(cursor, NSCursor.resizeUpDown)
            || cursorMatches(cursor, NSCursor.resizeUp)
            || cursorMatches(cursor, NSCursor.resizeDown)
            || matchesRowResize {
            return Layout(width: 8, height: 3, xOffset: -4, topDistance: 17)
        }

        if cursorMatches(cursor, NSCursor.pointingHand)
            || cursorMatches(cursor, NSCursor.openHand)
            || cursorMatches(cursor, NSCursor.closedHand) {
            return Layout(width: 18, height: 3.5, xOffset: -6, topDistance: 26)
        }

        if cursorMatches(cursor, NSCursor.crosshair) {
            return Layout(width: 13, height: 3.5, xOffset: -6.5, topDistance: 15)
        }

        if cursorMatches(cursor, NSCursor.arrow) {
            return arrowLayout
        }

        return fallbackLayout(for: cursor)
    }

    private var arrowLayout: Layout {
        Layout(width: 15, height: 3.5, xOffset: -3, topDistance: 18)
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

    private func fallbackLayout(for cursor: NSCursor) -> Layout {
        let size = cursor.image.size
        let hotSpot = cursor.hotSpot

        guard size.width > 0, size.height > 0 else {
            return arrowLayout
        }

        let width = min(max(size.width * 0.65, 10), 24)
        let cursorCenterOffset = size.width / 2 - hotSpot.x
        let downExtent = max(size.height - hotSpot.y, 0)
        let topDistance = min(max(downExtent + 2, 14), 30)

        return Layout(
            width: width,
            height: 3.5,
            xOffset: cursorCenterOffset - width / 2,
            topDistance: topDistance
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

        let path = CGPath(
            roundedRect: capsuleFrame,
            cornerWidth: capsuleFrame.height / 2,
            cornerHeight: capsuleFrame.height / 2,
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
