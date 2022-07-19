//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalUI

public class CVComponentGiftBadge: CVComponentBase, CVComponent {

    public var componentKey: CVComponentKey { .giftBadge }

    private let giftBadge: CVComponentState.GiftBadge

    private let viewState: ViewState

    // Component state objects are derived from TSInteractions, and they're
    // only updated when the underlying interaction changes. The "N days
    // remaining" label depends on the current time, so we need to use
    // CVItemViewState, which is refreshed even when the underlying interaction
    // hasn't changed. This is similar to how the time in the footer works.
    struct ViewState: Equatable {
        let timeRemainingText: String
        let profileBadge: ProfileBadge?
    }

    static func buildViewState(_ giftBadge: CVComponentState.GiftBadge) -> ViewState {
        ViewState(
            timeRemainingText: GiftBadgeView.timeRemainingText(for: giftBadge.expirationDate),
            profileBadge: giftBadge.cachedBadge.profileBadge
        )
    }

    private var state: GiftBadgeView.State {
        let stateBadge: GiftBadgeView.State.Badge
        if let profileBadge = self.viewState.profileBadge {
            stateBadge = .loaded(profileBadge)
        } else {
            let cachedBadge = self.giftBadge.cachedBadge
            stateBadge = .notLoaded({ cachedBadge.fetchIfNeeded().asVoid() })
        }
        return GiftBadgeView.State(
            badge: stateBadge,
            messageUniqueId: self.giftBadge.messageUniqueId,
            timeRemainingText: self.viewState.timeRemainingText,
            redemptionState: self.giftBadge.redemptionState,
            isIncoming: self.isIncoming,
            conversationStyle: self.conversationStyle
        )
    }

    init(itemModel: CVItemModel, giftBadge: CVComponentState.GiftBadge, viewState: ViewState) {
        self.giftBadge = giftBadge
        self.viewState = viewState
        super.init(itemModel: itemModel)
    }

    public func buildComponentView(componentDelegate: CVComponentDelegate) -> CVComponentView {
        CVComponentViewGiftBadge(componentDelegate: componentDelegate)
    }

    public func configureForRendering(
        componentView: CVComponentView,
        cellMeasurement: CVCellMeasurement,
        componentDelegate: CVComponentDelegate
    ) {
        guard let componentView = componentView as? CVComponentViewGiftBadge else {
            owsFailDebug("unexpected componentView")
            componentView.reset()
            return
        }

        componentView.messageUniqueId = self.giftBadge.messageUniqueId
        componentView.giftBadgeView.configureForRendering(
            state: self.state,
            cellMeasurement: cellMeasurement,
            componentDelegate: componentDelegate
        )
    }

    public func measure(maxWidth: CGFloat, measurementBuilder: CVCellMeasurement.Builder) -> CGSize {
        return GiftBadgeView.measurement(for: self.state, maxWidth: maxWidth, measurementBuilder: measurementBuilder)
    }

    public func configureGiftWrapIfNeeded(componentView: CVComponentView) -> (ManualLayoutView, OWSBubbleViewPartner)? {
        guard let componentView = componentView as? CVComponentViewGiftBadge else {
            owsFailDebug("unexpected componentView")
            return nil
        }
        guard let giftWrap = componentView.giftBadgeView.giftWrap else {
            return nil
        }
        return (giftWrap.rootView, giftWrap.bubbleViewPartner)
    }

    public override func handleTap(
        sender: UITapGestureRecognizer,
        componentDelegate: CVComponentDelegate,
        componentView: CVComponentView,
        renderItem: CVRenderItem
    ) -> Bool {

        guard let componentView = componentView as? CVComponentViewGiftBadge else {
            owsFailDebug("unexpected componentView")
            return false
        }
        let itemViewModel = CVItemViewModelImpl(renderItem: renderItem)
        let giftBadgeView = componentView.giftBadgeView

        if giftBadgeView.giftWrap != nil {
            componentDelegate.cvc_willUnwrapGift(itemViewModel)
            giftBadgeView.animateUnwrap()
            return true
        }

        let profileBadge: ProfileBadge
        switch renderItem.componentState.giftBadge?.cachedBadge.profileBadge {
        case .some(let value):
            profileBadge = value
        default:
            // If there's not a badge, it's still showing the loading indicator.
            return false
        }

        let buttonView = giftBadgeView.buttonStack
        guard buttonView.bounds.contains(sender.location(in: buttonView)) else {
            return false
        }

        componentDelegate.cvc_didTapGiftBadge(itemViewModel, profileBadge: profileBadge)
        return true
    }

    public class CVComponentViewGiftBadge: NSObject, CVComponentView {
        fileprivate let giftBadgeView = GiftBadgeView(name: "GiftBadgeView")

        fileprivate var messageUniqueId: String?

        private weak var componentDelegate: CVComponentDelegate?

        public var isDedicatedCellView = false

        public var rootView: UIView { giftBadgeView }

        init(componentDelegate: CVComponentDelegate) {
            self.componentDelegate = componentDelegate
        }

        public func setIsCellVisible(_ isCellVisible: Bool) {
            guard
                isCellVisible,
                let giftWrap = self.giftBadgeView.giftWrap,
                let componentDelegate = self.componentDelegate,
                let messageUniqueId = self.messageUniqueId,
                componentDelegate.cvc_willShakeGift(messageUniqueId)
            else {
                return
            }

            _ = componentDelegate.cvc_beginCellAnimation(maximumDuration: GiftWrap.shakeAnimationDuration)
            giftWrap.animateShake()
        }

        public func reset() {
            self.messageUniqueId = nil
            giftBadgeView.reset()
        }
    }
}
