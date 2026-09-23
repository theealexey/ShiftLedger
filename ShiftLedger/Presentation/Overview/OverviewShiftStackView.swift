import UIKit

final class OverviewShiftStackView: UIView {
    private enum Layout {
        static let accessibilitySpacing: CGFloat = 8
        static let collapsedCardReveal: CGFloat = 72
    }

    var usesAccessibleListLayout = false {
        didSet {
            guard usesAccessibleListLayout != oldValue else { return }
            rebuildLayout()
        }
    }

    private var cards: [OverviewView.ShiftCard] = []
    private var cardViews: [UUID: OverviewShiftCardView] = [:]
    private var activeLayoutConstraints: [NSLayoutConstraint] = []

    func render(
        _ cards: [OverviewView.ShiftCard],
        onCardTapped: ((UUID) -> Void)?,
        onEditTapped: ((UUID) -> Void)?
    ) {
        let previousIDs = Set(self.cards.map(\.id))
        self.cards = cards
        let currentIDs = Set(cards.map(\.id))
        for id in previousIDs.subtracting(currentIDs) {
            cardViews.removeValue(forKey: id)?.removeFromSuperview()
        }

        let surfaceRoles = ShiftLedgerColors.shiftSurfaceRoles(for: cards.map(\.id))
        let frontCardID = cards.first(where: \.isSelected)?.id ?? cards.first?.id
        for (card, surfaceRole) in zip(cards, surfaceRoles) {
            let isDeckFront = card.id == frontCardID
            if let view = cardViews[card.id] {
                view.update(
                    with: card,
                    surfaceRole: surfaceRole,
                    isDeckFront: isDeckFront,
                    onEditTapped: onEditTapped
                )
            } else {
                let view = OverviewShiftCardView(
                    card: card,
                    surfaceRole: surfaceRole,
                    isDeckFront: isDeckFront,
                    onEditTapped: onEditTapped
                )
                view.addAction(UIAction { _ in onCardTapped?(card.id) }, for: .touchUpInside)
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
                cardViews[card.id] = view
            }
        }

        rebuildLayout(animated: UIAccessibility.isReduceMotionEnabled == false)
    }

    func cardView(with id: UUID) -> UIView? {
        cardViews[id]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCardAccessibilityFrames()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard usesAccessibleListLayout == false else {
            return super.hitTest(point, with: event)
        }
        guard bounds.contains(point) else { return nil }

        let views = visualCardViews
        for (index, view) in views.enumerated() {
            guard visibleRegion(for: view, at: index, in: views).contains(point) else { continue }

            let pointInCard = convert(point, to: view)
            return view.hitTest(pointInCard, with: event)
        }

        return nil
    }

    private func rebuildLayout(animated: Bool = false) {
        NSLayoutConstraint.deactivate(activeLayoutConstraints)
        activeLayoutConstraints.removeAll()

        guard cards.isEmpty == false else { return }
        let views = cards.compactMap { cardViews[$0.id] }
        guard views.count == cards.count else { return }
        guard let frontCard = cards.first(where: \.isSelected) ?? cards.first else {
            return
        }
        let visualCards = cards.reversed().filter { $0.id != frontCard.id } + [frontCard]
        let visualViews = usesAccessibleListLayout
            ? views
            : visualCards.compactMap { cardViews[$0.id] }

        for (index, view) in visualViews.enumerated() {
            activeLayoutConstraints += [
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor)
            ]

            if index == 0 {
                activeLayoutConstraints.append(view.topAnchor.constraint(equalTo: topAnchor))
            } else if usesAccessibleListLayout {
                activeLayoutConstraints.append(
                    view.topAnchor.constraint(
                        equalTo: visualViews[index - 1].bottomAnchor,
                        constant: Layout.accessibilitySpacing
                    )
                )
            } else {
                activeLayoutConstraints.append(
                    view.topAnchor.constraint(
                        equalTo: visualViews[index - 1].topAnchor,
                        constant: Layout.collapsedCardReveal
                    )
                )
            }

            activeLayoutConstraints.append(bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor))
        }

        if let front = visualViews.last {
            let frontBottom = front.bottomAnchor.constraint(equalTo: bottomAnchor)
            frontBottom.priority = .defaultHigh
            activeLayoutConstraints.append(frontBottom)
        }

        visualViews.forEach(bringSubviewToFront)
        accessibilityElements = views
        NSLayoutConstraint.activate(activeLayoutConstraints)

        guard animated, window != nil else { return }
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut, .allowUserInteraction]
        ) { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
    }

    private var visualCardViews: [OverviewShiftCardView] {
        subviews.compactMap { $0 as? OverviewShiftCardView }
    }

    private func visibleRegion(
        for view: OverviewShiftCardView,
        at index: Int,
        in views: [OverviewShiftCardView]
    ) -> CGRect {
        let lowerEdge = index + 1 < views.count
            ? min(view.frame.maxY, views[index + 1].frame.minY)
            : view.frame.maxY
        return CGRect(
            x: view.frame.minX,
            y: view.frame.minY,
            width: view.frame.width,
            height: max(0, lowerEdge - view.frame.minY)
        )
    }

    private func updateCardAccessibilityFrames() {
        let views = visualCardViews
        for (index, view) in views.enumerated() {
            let region = usesAccessibleListLayout
                ? view.frame
                : visibleRegion(for: view, at: index, in: views)
            view.updateAccessibilityFrame(for: region, in: self)
        }
    }

}
