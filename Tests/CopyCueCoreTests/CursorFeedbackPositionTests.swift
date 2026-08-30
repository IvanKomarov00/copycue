import CoreGraphics
import Foundation
import Testing
@testable import CopyCueCore

@Test
func cursorFeedbackPositionHasStableValuesAndFallback() {
    #expect(CursorFeedbackPosition.allCases.map(\.rawValue) == [
        "below",
        "left",
        "above",
        "right"
    ])
    #expect(CursorFeedbackPosition.resolve(nil) == .below)
    #expect(CursorFeedbackPosition.resolve("unknown") == .below)
    #expect(CursorFeedbackPosition.resolve("right") == .right)
}

@Test
func cursorFeedbackLayoutPlacesAndRotatesTheLine() {
    let pointer = CGPoint(x: 100, y: 100)
    let layout = CursorFeedbackLayout(
        below: CursorFeedbackSideLayout(
            length: 16,
            thickness: 4,
            centerOffset: 2,
            distance: 20
        ),
        left: CursorFeedbackSideLayout(
            length: 22,
            thickness: 4,
            centerOffset: -6,
            distance: 4
        ),
        above: CursorFeedbackSideLayout(
            length: 16,
            thickness: 4,
            centerOffset: 3,
            distance: 5
        ),
        right: CursorFeedbackSideLayout(
            length: 22,
            thickness: 4,
            centerOffset: -6,
            distance: 18
        )
    )

    #expect(layout.capsuleFrame(at: pointer, position: .below) == CGRect(
        x: 94,
        y: 76,
        width: 16,
        height: 4
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .left) == CGRect(
        x: 92,
        y: 83,
        width: 4,
        height: 22
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .above) == CGRect(
        x: 95,
        y: 105,
        width: 16,
        height: 4
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .right) == CGRect(
        x: 118,
        y: 83,
        width: 4,
        height: 22
    ))
}

@Test
func cursorFeedbackSideIndicatorsAreShorterAndLower() {
    let pointer = CGPoint(x: 100, y: 100)
    let below = CursorFeedbackSideLayout(
        length: 16,
        thickness: 4,
        centerOffset: 2,
        distance: 20
    )
    let above = CursorFeedbackSideLayout(
        length: 16,
        thickness: 4,
        centerOffset: 3,
        distance: 5
    )
    let left = CursorFeedbackSideLayout.cursorSideIndicator(
        baseLength: 22,
        thickness: 4,
        distance: 4
    )
    let right = CursorFeedbackSideLayout.cursorSideIndicator(
        baseLength: 22,
        thickness: 4,
        distance: 18
    )
    let layout = CursorFeedbackLayout(
        below: below,
        left: left,
        above: above,
        right: right
    )

    #expect(left == CursorFeedbackSideLayout(
        length: 20,
        thickness: 4,
        centerOffset: -2,
        distance: 4
    ))
    #expect(right == CursorFeedbackSideLayout(
        length: 20,
        thickness: 4,
        centerOffset: -2,
        distance: 18
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .below) == CGRect(
        x: 94,
        y: 76,
        width: 16,
        height: 4
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .left) == CGRect(
        x: 92,
        y: 88,
        width: 4,
        height: 20
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .above) == CGRect(
        x: 95,
        y: 105,
        width: 16,
        height: 4
    ))
    #expect(layout.capsuleFrame(at: pointer, position: .right) == CGRect(
        x: 118,
        y: 88,
        width: 4,
        height: 20
    ))
}

@Test
func cursorFeedbackLayoutPreservesTheTunedBelowFrames() {
    let arrowBelow = CursorFeedbackSideLayout(
        length: 15,
        thickness: 3.5,
        centerOffset: 4.5,
        distance: 18
    )
    let arrowLayout = CursorFeedbackLayout(
        below: arrowBelow,
        left: arrowBelow,
        above: arrowBelow,
        right: arrowBelow
    )
    let iBeamBelow = CursorFeedbackSideLayout(
        length: 16,
        thickness: 3,
        centerOffset: 0,
        distance: 13
    )
    let iBeamLayout = CursorFeedbackLayout(
        below: iBeamBelow,
        left: iBeamBelow,
        above: iBeamBelow,
        right: iBeamBelow
    )
    let pointer = CGPoint(x: 100, y: 100)

    #expect(arrowLayout.capsuleFrame(
        at: pointer,
        position: .below
    ) == CGRect(x: 97, y: 78.5, width: 15, height: 3.5))
    #expect(iBeamLayout.capsuleFrame(
        at: pointer,
        position: .below
    ) == CGRect(x: 92, y: 84, width: 16, height: 3))
}

@Test
func cursorFeedbackPlacementFlipsAtEachPrimaryScreenEdge() {
    let screen = CGRect(x: 0, y: 0, width: 200, height: 200)
    let side = CursorFeedbackSideLayout(
        length: 16,
        thickness: 4,
        centerOffset: 0,
        distance: 20
    )
    let layout = CursorFeedbackLayout(
        below: side,
        left: side,
        above: side,
        right: side
    )

    let cases: [(CGPoint, CursorFeedbackPosition, CursorFeedbackPosition)] = [
        (CGPoint(x: 100, y: 10), .below, .above),
        (CGPoint(x: 10, y: 100), .left, .right),
        (CGPoint(x: 100, y: 190), .above, .below),
        (CGPoint(x: 190, y: 100), .right, .left)
    ]

    for (pointer, requestedPosition, expectedPosition) in cases {
        let placement = CursorFeedbackGeometry.placement(
            pointer: pointer,
            requestedPosition: requestedPosition,
            layout: layout,
            shadowMargin: 6,
            screenFrame: screen
        )

        #expect(placement.position == expectedPosition)
        #expect(screen.contains(placement.panelFrame))
        #expect(placement.capsuleFrame.origin == CGPoint(x: 6, y: 6))
    }
}

@Test
func cursorFeedbackPlacementClampsSecondaryAxisOnNegativeOriginScreen() {
    let screen = CGRect(x: -200, y: 0, width: 200, height: 200)
    let side = CursorFeedbackSideLayout(
        length: 16,
        thickness: 4,
        centerOffset: 0,
        distance: 20
    )
    let layout = CursorFeedbackLayout(
        below: side,
        left: side,
        above: side,
        right: side
    )
    let placement = CursorFeedbackGeometry.placement(
        pointer: CGPoint(x: -198, y: 100),
        requestedPosition: .below,
        layout: layout,
        shadowMargin: 6,
        screenFrame: screen
    )

    #expect(placement.position == .below)
    #expect(placement.panelFrame.minX == screen.minX)
    #expect(screen.contains(placement.panelFrame))
}
