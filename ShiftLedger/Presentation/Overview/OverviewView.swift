import UIKit

final class OverviewView: UIView, UIScrollViewDelegate {
    struct PeriodItem: Equatable {
        let period: PayCalculationPeriod
        let title: String
        let isSelected: Bool
    }

    struct ShiftCard: Equatable {
        let id: UUID
        let frontDate: String
        let timeRange: String
        let endpoints: OverviewFormatting.ShiftEndpoints
        let expectedAmount: String
        let paidDuration: String
        let unpaidBreak: String?
        let unpaidBreakTimeRange: String?
        let appliedRate: String
        let payBasis: String
        let isSelected: Bool
        let isExpanded: Bool
        let accessibilityLabel: String
    }

    var onPreviousPeriodTapped: (() -> Void)?
    var onNextPeriodTapped: (() -> Void)?
    var onPeriodTapped: ((PayCalculationPeriod) -> Void)?
    var onShiftCardTapped: ((UUID) -> Void)?
    var onEditShiftTapped: ((UUID) -> Void)?
    var onCheckPaycheckTapped: (() -> Void)?
    var onAddShiftTapped: (() -> Void)?
    var onRetryTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()

    private let periodRailContainer = UIStackView()
    private let periodRailScrollView = UIScrollView()
    private let periodRailStack = UIStackView()
    private var needsPeriodCentering = false
    private let contentCard = UIView()
    private let contentStack = UIStackView()
    private let expectedGrossLabel = UILabel()
    private let expectedGrossAmountLabel = UILabel()
    private let navigationStack = UIStackView()
    private let previousButton = UIButton(type: .system)
    private let periodLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let shiftCountStack = UIStackView()
    private let shiftCountLabel = UILabel()
    private let shiftCountValueLabel = UILabel()

    private let shiftHistoryStack = UIStackView()
    private let shiftStack = OverviewShiftStackView()
    private let shiftHistoryEmptyLabel = UILabel()

    private let checkPaycheckButton = UIButton(type: .system)
    private let addShiftButton = UIButton(type: .system)

    private let emptyCard = UIView()
    private let emptyStack = UIStackView()
    private let emptyTitleLabel = UILabel()
    private let emptyMessageLabel = UILabel()

    private let errorCard = UIView()
    private let errorStack = UIStackView()
    private let errorTitleLabel = UILabel()
    private let errorMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.updatePeriodRailForContentSizeCategory()
            self.updateActionButtonsForContentSizeCategory()
        }
        renderIdle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func renderContent(
        expectedGross: String,
        expectedGrossContext: String,
        period: String,
        periodItems: [PeriodItem],
        shiftCount: Int,
        shiftCards: [ShiftCard],
        canNavigatePrevious: Bool,
        canNavigateNext: Bool,
        canCheckPaycheck: Bool
    ) {
        expectedGrossAmountLabel.text = expectedGross
        expectedGrossAmountLabel.accessibilityLabel = "\(expectedGrossContext), \(expectedGross)"
        expectedGrossLabel.text = expectedGrossContext
        periodLabel.text = period
        periodLabel.accessibilityLabel = period
        renderPeriodRail(periodItems)
        shiftCountValueLabel.text = String(shiftCount)
        shiftCountStack.accessibilityLabel = "\(OverviewStrings.shiftSectionPrefix) \(shiftCount)"
        previousButton.isEnabled = canNavigatePrevious
        nextButton.isEnabled = canNavigateNext
        checkPaycheckButton.isEnabled = canCheckPaycheck
        renderShiftHistory(shiftCards)
        applyAddShiftEmphasis(isPrimary: false)
        setVisible(
            content: true,
            shiftHistory: true,
            checkPaycheck: true,
            addShift: true,
            empty: false,
            error: false
        )
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        periodRailContainer.layoutIfNeeded()
        periodRailScrollView.layoutIfNeeded()
        periodRailStack.layoutIfNeeded()
        if !periodRailScrollView.isHidden,
           !periodRailScrollView.isDragging,
           !periodRailScrollView.isDecelerating,
           let selected = periodRailStack.arrangedSubviews.first(where: {
               $0.accessibilityTraits.contains(.selected)
           }) as? OverviewPeriodRailItem {
            let inset = max(0, (periodRailScrollView.bounds.width - selected.bounds.width) / 2)
            let changed = periodRailScrollView.contentInset.left != inset
            periodRailScrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
            if needsPeriodCentering || changed {
                periodRailScrollView.setContentOffset(
                    CGPoint(x: horizontalOffset(centering: selected), y: 0), animated: false
                )
                needsPeriodCentering = false
            }
        }
    }

    func focusShiftCard(with id: UUID) {
        guard let card = shiftStack.cardView(with: id) else {
            return
        }

        layoutIfNeeded()
        let visibleRect = card.convert(card.bounds, to: scrollView).insetBy(dx: 0, dy: -16)
        scrollView.scrollRectToVisible(visibleRect, animated: false)

        if card.window != nil {
            UIAccessibility.post(notification: .layoutChanged, argument: card)
        }
    }

    func renderEmpty() {
        applyAddShiftEmphasis(isPrimary: true)
        setVisible(
            content: false,
            shiftHistory: false,
            checkPaycheck: false,
            addShift: true,
            empty: true,
            error: false
        )
    }

    func renderFailure(title: String, message: String) {
        errorTitleLabel.text = title
        errorMessageLabel.text = message
        setVisible(
            content: false,
            shiftHistory: false,
            checkPaycheck: false,
            addShift: false,
            empty: false,
            error: true
        )
    }

    func renderIdle() {
        setVisible(
            content: false,
            shiftHistory: false,
            checkPaycheck: false,
            addShift: false,
            empty: false,
            error: false
        )
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "overview.screen"
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        scrollView.accessibilityIdentifier = "overview.pageScroll"

        mainStack.axis = .vertical
        mainStack.spacing = 24

        contentCard.backgroundColor = ShiftLedgerColors.backgroundSecondary
        contentCard.layer.cornerCurve = .continuous
        contentCard.layer.cornerRadius = 28
        contentCard.accessibilityIdentifier = "overview.expectedGross.hero"
        configureCard(emptyCard)
        configureCard(errorCard)

        contentStack.axis = .vertical
        contentStack.spacing = 8
        expectedGrossLabel.text = OverviewStrings.expectedGross
        configureLabel(
            expectedGrossLabel,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.textSecondary
        )
        expectedGrossLabel.accessibilityIdentifier = "overview.expectedGross.label"

        configureLabel(
            expectedGrossAmountLabel,
            font: ShiftLedgerTypography.expectedGrossDisplay,
            color: ShiftLedgerColors.textPrimary
        )
        expectedGrossAmountLabel.accessibilityIdentifier = "overview.expectedGross.amount"

        navigationStack.axis = .horizontal
        navigationStack.alignment = .center
        navigationStack.distribution = .fill
        navigationStack.spacing = 4
        periodRailContainer.axis = .vertical
        periodRailContainer.spacing = 8
        periodRailScrollView.showsHorizontalScrollIndicator = false
        periodRailScrollView.alwaysBounceHorizontal = true
        periodRailScrollView.delegate = self
        periodRailScrollView.accessibilityIdentifier = "overview.period.rail"
        periodRailScrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        periodRailStack.axis = .horizontal
        periodRailStack.spacing = 12
        configureNavigationButton(
            previousButton,
            systemImageName: "chevron.left",
            accessibilityLabel: OverviewStrings.previousPeriod,
            identifier: "overview.period.previous"
        )
        configureNavigationButton(
            nextButton,
            systemImageName: "chevron.right",
            accessibilityLabel: OverviewStrings.nextPeriod,
            identifier: "overview.period.next"
        )
        configureLabel(periodLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        periodLabel.textAlignment = .center
        periodLabel.lineBreakMode = .byWordWrapping
        periodLabel.accessibilityIdentifier = "overview.period.label"
        periodLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        periodLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        shiftCountStack.axis = .horizontal
        shiftCountStack.alignment = .firstBaseline
        shiftCountStack.spacing = 4
        shiftCountStack.isAccessibilityElement = true
        shiftCountStack.accessibilityTraits = .header
        shiftCountStack.accessibilityIdentifier = "overview.shiftHistory.title"
        shiftCountLabel.text = OverviewStrings.shiftSectionPrefix
        configureLabel(
            shiftCountLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftCountLabel.accessibilityIdentifier = "overview.shiftCount.label"
        shiftCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        configureLabel(
            shiftCountValueLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftCountValueLabel.textAlignment = .left
        shiftCountValueLabel.accessibilityIdentifier = "overview.shiftCount.value"

        shiftHistoryStack.axis = .vertical
        shiftHistoryStack.spacing = 12

        shiftStack.accessibilityIdentifier = "overview.shiftStack"
        shiftHistoryEmptyLabel.text = OverviewStrings.shiftHistoryEmpty
        configureLabel(
            shiftHistoryEmptyLabel,
            font: ShiftLedgerTypography.body,
            color: ShiftLedgerColors.textSecondary
        )
        shiftHistoryEmptyLabel.accessibilityIdentifier = "overview.shiftHistory.empty"

        configureActionButton(
            checkPaycheckButton,
            title: OverviewStrings.checkPaycheck,
            identifier: "overview.checkPaycheck",
            isPrimary: true
        )
        configureActionButton(
            addShiftButton,
            title: OverviewStrings.addShift,
            identifier: "overview.addShift",
            isPrimary: false
        )

        emptyStack.axis = .vertical
        emptyStack.spacing = 8
        emptyTitleLabel.text = OverviewStrings.emptyTitle
        configureLabel(emptyTitleLabel, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        emptyTitleLabel.accessibilityIdentifier = "overview.empty.title"
        emptyMessageLabel.text = OverviewStrings.emptyMessage
        configureLabel(emptyMessageLabel, font: ShiftLedgerTypography.body, color: ShiftLedgerColors.textSecondary)
        emptyMessageLabel.accessibilityIdentifier = "overview.empty.message"
        emptyCard.accessibilityIdentifier = "overview.empty.container"

        errorStack.axis = .vertical
        errorStack.spacing = 12
        configureLabel(errorTitleLabel, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        errorTitleLabel.accessibilityIdentifier = "overview.error.title"
        configureLabel(errorMessageLabel, font: ShiftLedgerTypography.body, color: ShiftLedgerColors.textSecondary)
        errorMessageLabel.accessibilityIdentifier = "overview.error.message"
        configureActionButton(
            retryButton,
            title: OverviewStrings.retry,
            identifier: "overview.error.retry",
            isPrimary: false
        )
        errorCard.accessibilityIdentifier = "overview.error.container"
    }

    private func configureHierarchy() {
        [
            scrollView,
            contentView,
            mainStack,
            periodRailContainer,
            periodRailScrollView,
            periodRailStack,
            contentStack,
            shiftHistoryStack,
            shiftStack,
            emptyStack,
            errorStack
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)
        [periodRailContainer, contentCard, shiftHistoryStack, checkPaycheckButton, emptyCard, errorCard, addShiftButton]
            .forEach(mainStack.addArrangedSubview)

        periodRailContainer.addArrangedSubview(periodLabel)
        periodRailContainer.addArrangedSubview(navigationStack)
        navigationStack.addArrangedSubview(previousButton)
        navigationStack.addArrangedSubview(periodRailScrollView)
        navigationStack.addArrangedSubview(nextButton)
        periodRailScrollView.addSubview(periodRailStack)

        contentCard.addSubview(contentStack)
        [expectedGrossLabel, expectedGrossAmountLabel]
            .forEach(contentStack.addArrangedSubview)
        [shiftCountLabel, shiftCountValueLabel].forEach(shiftCountStack.addArrangedSubview)

        [shiftCountStack, shiftStack, shiftHistoryEmptyLabel]
            .forEach(shiftHistoryStack.addArrangedSubview)

        emptyCard.addSubview(emptyStack)
        [emptyTitleLabel, emptyMessageLabel].forEach(emptyStack.addArrangedSubview)

        errorCard.addSubview(errorStack)
        [errorTitleLabel, errorMessageLabel, retryButton].forEach(errorStack.addArrangedSubview)

        contentCard.accessibilityElements = [expectedGrossLabel, expectedGrossAmountLabel]

        mainStack.setCustomSpacing(16, after: periodRailContainer)
        mainStack.setCustomSpacing(24, after: contentCard)
        mainStack.setCustomSpacing(12, after: checkPaycheckButton)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: contentCard.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentCard.bottomAnchor, constant: -24),

            periodRailScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            periodRailScrollView.heightAnchor.constraint(equalTo: periodRailStack.heightAnchor),
            periodRailStack.leadingAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.leadingAnchor),
            periodRailStack.trailingAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.trailingAnchor),
            periodRailStack.topAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.topAnchor),
            periodRailStack.bottomAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.bottomAnchor),

            emptyStack.topAnchor.constraint(equalTo: emptyCard.topAnchor, constant: 20),
            emptyStack.leadingAnchor.constraint(equalTo: emptyCard.leadingAnchor, constant: 20),
            emptyStack.trailingAnchor.constraint(equalTo: emptyCard.trailingAnchor, constant: -20),
            emptyStack.bottomAnchor.constraint(equalTo: emptyCard.bottomAnchor, constant: -20),

            errorStack.topAnchor.constraint(equalTo: errorCard.topAnchor, constant: 20),
            errorStack.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            errorStack.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),
            errorStack.bottomAnchor.constraint(equalTo: errorCard.bottomAnchor, constant: -20),

            previousButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            previousButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            checkPaycheckButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            addShiftButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])

        updatePeriodRailForContentSizeCategory()
    }

    private func configureInteractions() {
        previousButton.addAction(UIAction { [weak self] _ in self?.onPreviousPeriodTapped?() }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.onNextPeriodTapped?() }, for: .touchUpInside)
        checkPaycheckButton.addAction(UIAction { [weak self] _ in self?.onCheckPaycheckTapped?() }, for: .touchUpInside)
        addShiftButton.addAction(UIAction { [weak self] _ in self?.onAddShiftTapped?() }, for: .touchUpInside)
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetryTapped?() }, for: .touchUpInside)
    }

    private func configureCard(_ card: UIView) {
        card.backgroundColor = ShiftLedgerColors.surfacePrimary
        card.layer.cornerCurve = .continuous
        card.layer.cornerRadius = 20
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private func configureNavigationButton(
        _ button: UIButton,
        systemImageName: String,
        accessibilityLabel: String,
        identifier: String
    ) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImageName)
        configuration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        button.configuration = configuration
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityIdentifier = identifier
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func configureActionButton(
        _ button: UIButton,
        title: String,
        identifier: String,
        isPrimary: Bool
    ) {
        var configuration = isPrimary
            ? UIButton.Configuration.filled()
            : UIButton.Configuration.plain()
        configuration.title = title
        configuration.cornerStyle = .large
        if isPrimary {
            configuration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        } else {
            configuration.baseForegroundColor = ShiftLedgerColors.accentPrimary
            configuration.background.backgroundColor = ShiftLedgerColors.backgroundSecondary
        }
        button.configuration = configuration
        button.tintColor = ShiftLedgerColors.accentPrimary
        button.titleLabel?.font = ShiftLedgerTypography.button
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .center
        button.accessibilityLabel = title
        button.accessibilityIdentifier = identifier
    }

    private func applyAddShiftEmphasis(isPrimary: Bool) {
        configureActionButton(
            addShiftButton,
            title: OverviewStrings.addShift,
            identifier: "overview.addShift",
            isPrimary: isPrimary
        )
    }

    private func setVisible(
        content: Bool,
        shiftHistory: Bool,
        checkPaycheck: Bool,
        addShift: Bool,
        empty: Bool,
        error: Bool
    ) {
        periodRailContainer.isHidden = !content
        contentCard.isHidden = !content
        shiftHistoryStack.isHidden = !shiftHistory
        checkPaycheckButton.isHidden = !checkPaycheck
        addShiftButton.isHidden = !addShift
        emptyCard.isHidden = !empty
        errorCard.isHidden = !error
    }

    private func renderShiftHistory(_ cards: [ShiftCard]) {
        shiftStack.render(
            cards,
            onCardTapped: onShiftCardTapped,
            onEditTapped: onEditShiftTapped
        )

        shiftHistoryEmptyLabel.isHidden = cards.isEmpty == false
    }

    private func renderPeriodRail(_ items: [PeriodItem]) {
        periodRailStack.arrangedSubviews.forEach { view in
            periodRailStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, item) in items.enumerated() {
            let itemView = OverviewPeriodRailItem(item: item)
            itemView.accessibilityIdentifier = "overview.period.item.\(index)"
            itemView.addAction(UIAction { [weak self] _ in
                self?.onPeriodTapped?(item.period)
            }, for: .touchUpInside)
            periodRailStack.addArrangedSubview(itemView)
            itemView.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        }
        periodRailScrollView.alwaysBounceHorizontal = items.count > 1
        needsPeriodCentering = true
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollView === periodRailScrollView,
              let item = nearestPeriodItem(to: targetContentOffset.pointee.x) else {
            return
        }

        targetContentOffset.pointee.x = horizontalOffset(centering: item)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === periodRailScrollView,
              let item = nearestPeriodItem(to: scrollView.contentOffset.x) else { return }
        onPeriodTapped?(item.period)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidEndDecelerating(scrollView)
        }
    }

    private func nearestPeriodItem(to offset: CGFloat) -> OverviewPeriodRailItem? {
        let visibleMidX = offset + periodRailScrollView.bounds.width / 2
        return periodRailStack.arrangedSubviews
            .compactMap { $0 as? OverviewPeriodRailItem }
            .min { abs($0.frame.midX - visibleMidX) < abs($1.frame.midX - visibleMidX) }
    }

    private func horizontalOffset(centering item: OverviewPeriodRailItem) -> CGFloat {
        let centeredOffset = item.frame.midX - periodRailScrollView.bounds.width / 2
        let minimumOffset = -periodRailScrollView.contentInset.left
        let maximumOffset = max(minimumOffset, periodRailScrollView.contentSize.width
            - periodRailScrollView.bounds.width + periodRailScrollView.contentInset.right)
        return min(max(minimumOffset, centeredOffset), maximumOffset)
    }

    private func updatePeriodRailForContentSizeCategory() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        periodRailScrollView.isHidden = usesAccessibilityLayout
        periodLabel.isHidden = !usesAccessibilityLayout
        navigationStack.distribution = usesAccessibilityLayout ? .equalSpacing : .fill
        shiftStack.usesAccessibleListLayout = usesAccessibilityLayout
        needsPeriodCentering = true
        setNeedsLayout()
    }

    private func updateActionButtonsForContentSizeCategory() {
        [checkPaycheckButton, addShiftButton, retryButton].forEach { button in
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.invalidateIntrinsicContentSize()
            button.invalidateIntrinsicContentSize()
            button.setNeedsLayout()
        }
        mainStack.setNeedsLayout()
        setNeedsLayout()
    }
}

private final class OverviewPeriodRailItem: UIControl {
    let period: PayCalculationPeriod

    init(item: OverviewView.PeriodItem) {
        period = item.period
        super.init(frame: .zero)
        backgroundColor = item.isSelected ? ShiftLedgerColors.backgroundSecondary : .clear
        layer.cornerCurve = .continuous
        layer.cornerRadius = 14
        accessibilityLabel = item.title
        accessibilityTraits = item.isSelected ? [.button, .selected] : .button

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = item.isSelected ? ShiftLedgerTypography.headline : ShiftLedgerTypography.callout
        titleLabel.textColor = item.isSelected ? ShiftLedgerColors.textPrimary : ShiftLedgerColors.textSecondary
        titleLabel.numberOfLines = 1
        titleLabel.accessibilityIdentifier = "overview.period.item.title"
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private final class OverviewShiftStackView: UIView {
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

private final class OverviewShiftCardView: UIControl {
    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 12
        static let headerToMetadataSpacing: CGFloat = 20
        static let frontContentInset: CGFloat = 12
        static let frontHeaderSpacing: CGFloat = 12
        static let frontEndpointsSpacing: CGFloat = 24
    }

    private let coveredDateLabel = UILabel()
    private let timeRangeLabel = UILabel()
    private let expectedAmountLabel = UILabel()
    private let frontContentStack = UIStackView()
    private let frontHeaderRow = UIStackView()
    private let frontDateLabel = UILabel()
    private let frontHeaderSpacer = UIView()
    private let frontExpectedAmountLabel = UILabel()
    private var endpointsView: OverviewShiftEndpointsView?
    private let paidDurationLabel = UILabel()
    private let unpaidBreakLabel = UILabel()
    private let contentStack = UIStackView()
    private let headerStack = UIStackView()
    private let headerTopRow = UIStackView()
    private let headerSpacer = UIView()
    private let metadataStack = UIStackView()
    private let detailStack = UIStackView()
    private let paidTimeDetailTitleLabel = UILabel()
    private let paidTimeDetailLabel = UILabel()
    private let unpaidBreakDetailTitleLabel = UILabel()
    private let unpaidBreakDetailLabel = UILabel()
    private let rateDetailTitleLabel = UILabel()
    private let rateDetailLabel = UILabel()
    private let payBasisDetailTitleLabel = UILabel()
    private let payBasisDetailLabel = UILabel()
    private let paidTimeDetailGroup = UIStackView()
    private let unpaidBreakDetailGroup = UIStackView()
    private let rateDetailGroup = UIStackView()
    private let payBasisDetailGroup = UIStackView()
    private let editButton = UIButton(type: .system)
    private var onEditTapped: (() -> Void)?
    init(
        card: OverviewView.ShiftCard,
        surfaceRole: ShiftSurfaceRole,
        isDeckFront: Bool,
        onEditTapped: ((UUID) -> Void)?
    ) {
        super.init(frame: .zero)
        configureHierarchy()
        configureLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.updateEditButtonForContentSizeCategory()
        }
        update(
            with: card,
            surfaceRole: surfaceRole,
            isDeckFront: isDeckFront,
            onEditTapped: onEditTapped
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeaderAxis()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else {
            return nil
        }
        if editButton.isHidden == false {
            let buttonPoint = editButton.convert(point, from: self)
            if editButton.point(inside: buttonPoint, with: event) {
                return editButton.hitTest(buttonPoint, with: event) ?? editButton
            }
        }
        return self
    }

    func update(
        with card: OverviewView.ShiftCard,
        surfaceRole: ShiftSurfaceRole,
        isDeckFront: Bool,
        onEditTapped: ((UUID) -> Void)?
    ) {
        self.onEditTapped = { onEditTapped?(card.id) }
        backgroundColor = ShiftLedgerColors.shiftSurface(for: surfaceRole)
        layer.cornerCurve = .continuous
        layer.cornerRadius = 28
        accessibilityIdentifier = "overview.shift.\(card.id.uuidString)"
        isAccessibilityElement = true
        let expandedDetails = card.isExpanded
            ? [
                "\(PaycheckResultStrings.paidTime): \(card.paidDuration)",
                card.unpaidBreak.map { duration in
                    let interval = card.unpaidBreakTimeRange.map { "\($0) · " } ?? ""
                    return "\(AddShiftStrings.unpaidBreak): \(interval)\(duration)"
                },
                "\(PaycheckResultStrings.rate): \(card.appliedRate)",
                "\(OverviewStrings.payBasis): \(card.payBasis)"
            ].compactMap { $0 }
            : []
        accessibilityLabel = ([card.accessibilityLabel] + expandedDetails).joined(separator: ", ")
        accessibilityHint = card.isExpanded ? OverviewStrings.collapseShift : OverviewStrings.expandShift
        accessibilityTraits = card.isSelected ? [.button, .selected] : .button
        accessibilityValue = card.isExpanded ? OverviewStrings.expanded : OverviewStrings.collapsed
        accessibilityCustomActions = card.isExpanded
            ? [UIAccessibilityCustomAction(
                name: OverviewStrings.editShift,
                target: self,
                selector: #selector(editAccessibilityAction)
            )]
            : nil

        let foreground = ShiftLedgerColors.shiftForeground(for: surfaceRole)
        let secondaryForeground = foreground.withAlphaComponent(0.78)
        let tertiaryForeground = foreground.withAlphaComponent(0.68)

        headerStack.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).header"
        headerStack.isHidden = isDeckFront
        frontContentStack.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).frontContent"
        frontContentStack.isHidden = isDeckFront == false

        coveredDateLabel.text = card.frontDate
        configureLabel(coveredDateLabel, font: ShiftLedgerTypography.headline, color: secondaryForeground)
        coveredDateLabel.numberOfLines = 1
        coveredDateLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).date"
        coveredDateLabel.isAccessibilityElement = false
        coveredDateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timeRangeLabel.text = card.timeRange
        configureLabel(timeRangeLabel, font: ShiftLedgerTypography.caption, color: secondaryForeground)
        timeRangeLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).time"
        timeRangeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        expectedAmountLabel.text = card.expectedAmount
        configureLabel(expectedAmountLabel, font: ShiftLedgerTypography.basePayAmount, color: foreground)
        expectedAmountLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).expected"
        expectedAmountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        frontDateLabel.text = card.frontDate
        configureLabel(frontDateLabel, font: ShiftLedgerTypography.headline, color: secondaryForeground)
        frontDateLabel.numberOfLines = 1
        frontDateLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).frontDate"
        frontDateLabel.isAccessibilityElement = false
        frontDateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        frontExpectedAmountLabel.text = card.expectedAmount
        configureLabel(frontExpectedAmountLabel, font: ShiftLedgerTypography.basePayAmount, color: foreground)
        frontExpectedAmountLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).frontExpected"
        frontExpectedAmountLabel.isAccessibilityElement = false
        frontExpectedAmountLabel.textAlignment = .right
        frontExpectedAmountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        if isDeckFront {
            let view = endpointsView ?? OverviewShiftEndpointsView()
            if endpointsView == nil {
                frontContentStack.addArrangedSubview(view)
                endpointsView = view
            }
            view.update(
                endpoints: card.endpoints,
                foreground: foreground,
                identifierPrefix: "overview.shift.\(card.id.uuidString).endpoints"
            )
        } else if let view = endpointsView {
            frontContentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
            endpointsView = nil
        }

        paidDurationLabel.text = isDeckFront ? OverviewStrings.paidDuration(card.paidDuration) : card.paidDuration
        configureLabel(paidDurationLabel, font: ShiftLedgerTypography.callout, color: secondaryForeground)
        paidDurationLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).duration"

        unpaidBreakLabel.text = card.unpaidBreak.map { "\(AddShiftStrings.unpaidBreak): \($0)" }
        configureLabel(unpaidBreakLabel, font: ShiftLedgerTypography.caption, color: tertiaryForeground)
        unpaidBreakLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).break"
        unpaidBreakLabel.isHidden = card.unpaidBreak == nil
        metadataStack.isHidden = card.isExpanded
        paidDurationLabel.textAlignment = isDeckFront ? .center : .natural
        unpaidBreakLabel.textAlignment = isDeckFront ? .center : .natural
        metadataStack.isLayoutMarginsRelativeArrangement = isDeckFront
        metadataStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0, leading: 0, bottom: isDeckFront ? 4 : 0, trailing: 0
        )

        paidTimeDetailTitleLabel.text = PaycheckResultStrings.paidTime
        paidTimeDetailLabel.text = card.paidDuration
        unpaidBreakDetailTitleLabel.text = AddShiftStrings.unpaidBreak
        unpaidBreakDetailLabel.text = card.unpaidBreak.map { duration in
            let interval = card.unpaidBreakTimeRange.map { "\($0) · " } ?? ""
            return "\(interval)\(duration)"
        }
        rateDetailTitleLabel.text = PaycheckResultStrings.rate
        rateDetailLabel.text = card.appliedRate
        payBasisDetailTitleLabel.text = OverviewStrings.payBasis
        payBasisDetailLabel.text = card.payBasis
        [
            paidTimeDetailTitleLabel,
            unpaidBreakDetailTitleLabel,
            rateDetailTitleLabel,
            payBasisDetailTitleLabel
        ].forEach {
            configureLabel($0, font: ShiftLedgerTypography.caption, color: tertiaryForeground)
        }
        [paidTimeDetailLabel, unpaidBreakDetailLabel, rateDetailLabel, payBasisDetailLabel].forEach {
            configureLabel($0, font: ShiftLedgerTypography.callout, color: secondaryForeground)
        }
        paidTimeDetailLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).detail.paidTime"
        unpaidBreakDetailLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).detail.break"
        rateDetailLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).detail.rate"
        payBasisDetailLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).detail.payBasis"
        unpaidBreakDetailGroup.isHidden = card.unpaidBreak == nil
        detailStack.isHidden = card.isExpanded == false
        editButton.isHidden = card.isExpanded == false
        editButton.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).edit"
    }

    private func configureHierarchy() {
        contentStack.axis = .vertical
        contentStack.isUserInteractionEnabled = true
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        headerTopRow.axis = .horizontal
        headerTopRow.alignment = .firstBaseline
        headerTopRow.spacing = 12
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [coveredDateLabel, headerSpacer, expectedAmountLabel].forEach(headerTopRow.addArrangedSubview)

        headerStack.axis = .vertical
        headerStack.alignment = .fill
        headerStack.spacing = 4
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 2,
            leading: 4,
            bottom: 0,
            trailing: 4
        )
        [headerTopRow, timeRangeLabel].forEach(headerStack.addArrangedSubview)

        frontHeaderRow.axis = .horizontal
        frontHeaderRow.alignment = .firstBaseline
        frontHeaderRow.spacing = Layout.frontHeaderSpacing
        frontHeaderSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        frontHeaderSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [frontDateLabel, frontHeaderSpacer, frontExpectedAmountLabel]
            .forEach(frontHeaderRow.addArrangedSubview)

        frontContentStack.axis = .vertical
        frontContentStack.spacing = Layout.frontEndpointsSpacing
        frontContentStack.isLayoutMarginsRelativeArrangement = true
        frontContentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Layout.frontContentInset,
            leading: 4,
            bottom: 4,
            trailing: 4
        )
        frontContentStack.addArrangedSubview(frontHeaderRow)

        metadataStack.axis = .vertical
        metadataStack.spacing = 4
        [paidDurationLabel, unpaidBreakLabel].forEach(metadataStack.addArrangedSubview)

        detailStack.axis = .vertical
        detailStack.spacing = 14
        configureDetailGroup(paidTimeDetailGroup, title: paidTimeDetailTitleLabel, value: paidTimeDetailLabel)
        configureDetailGroup(unpaidBreakDetailGroup, title: unpaidBreakDetailTitleLabel, value: unpaidBreakDetailLabel)
        configureDetailGroup(rateDetailGroup, title: rateDetailTitleLabel, value: rateDetailLabel)
        configureDetailGroup(payBasisDetailGroup, title: payBasisDetailTitleLabel, value: payBasisDetailLabel)
        [paidTimeDetailGroup, unpaidBreakDetailGroup, rateDetailGroup, payBasisDetailGroup]
            .forEach(detailStack.addArrangedSubview)

        var editConfiguration = UIButton.Configuration.plain()
        editConfiguration.title = OverviewStrings.editShift
        editConfiguration.image = UIImage(systemName: "pencil")
        editConfiguration.imagePlacement = .leading
        editConfiguration.imagePadding = 8
        editConfiguration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        editConfiguration.contentInsets = .zero
        editButton.configuration = editConfiguration
        editButton.contentHorizontalAlignment = .leading
        editButton.titleLabel?.adjustsFontForContentSizeCategory = true
        editButton.titleLabel?.numberOfLines = 0
        editButton.titleLabel?.lineBreakMode = .byWordWrapping
        editButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        editButton.addAction(UIAction { [weak self] _ in self?.onEditTapped?() }, for: .touchUpInside)

        addSubview(contentStack)
        [headerStack, frontContentStack, metadataStack, detailStack, editButton]
            .forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(Layout.headerToMetadataSpacing, after: headerStack)
        contentStack.setCustomSpacing(Layout.headerToMetadataSpacing, after: frontContentStack)
        contentStack.setCustomSpacing(18, after: metadataStack)
        contentStack.setCustomSpacing(18, after: detailStack)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalInset),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.horizontalInset)
        ])
    }

    private func configureDetailGroup(_ group: UIStackView, title: UILabel, value: UILabel) {
        group.axis = .vertical
        group.spacing = 2
        [title, value].forEach(group.addArrangedSubview)
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private func updateHeaderAxis() {
        let availableWidth = bounds.width - (Layout.horizontalInset * 2)
        let headerTopRowWidth = coveredDateLabel.intrinsicContentSize.width
            + expectedAmountLabel.intrinsicContentSize.width
            + headerTopRow.spacing * 2
        let usesVerticalTopRow = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || headerTopRowWidth > availableWidth
        let topRowAxis: NSLayoutConstraint.Axis = usesVerticalTopRow ? .vertical : .horizontal
        if headerTopRow.axis != topRowAxis {
            headerTopRow.axis = topRowAxis
            headerTopRow.alignment = usesVerticalTopRow ? .fill : .firstBaseline
            headerTopRow.spacing = usesVerticalTopRow ? 4 : 12
        }
        headerSpacer.isHidden = usesVerticalTopRow

        let frontHeaderWidth = frontDateLabel.intrinsicContentSize.width
            + frontExpectedAmountLabel.intrinsicContentSize.width
            + (Layout.frontHeaderSpacing * 2)
        let usesVerticalFrontHeader = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || frontHeaderWidth > availableWidth
        let frontHeaderAxis: NSLayoutConstraint.Axis = usesVerticalFrontHeader ? .vertical : .horizontal
        if frontHeaderRow.axis != frontHeaderAxis {
            frontHeaderRow.axis = frontHeaderAxis
            frontHeaderRow.alignment = usesVerticalFrontHeader ? .fill : .firstBaseline
            frontHeaderRow.spacing = usesVerticalFrontHeader ? 4 : Layout.frontHeaderSpacing
        }
        frontHeaderSpacer.isHidden = usesVerticalFrontHeader
    }

    private func updateEditButtonForContentSizeCategory() {
        editButton.titleLabel?.numberOfLines = 0
        editButton.titleLabel?.lineBreakMode = .byWordWrapping
        editButton.titleLabel?.invalidateIntrinsicContentSize()
        editButton.invalidateIntrinsicContentSize()
        editButton.setNeedsLayout()
        contentStack.setNeedsLayout()
        setNeedsLayout()
    }

    func updateAccessibilityFrame(for region: CGRect, in container: UIView) {
        accessibilityFrame = container.convert(region, to: nil)
        accessibilityActivationPoint = container.convert(
            CGPoint(x: region.midX, y: region.midY),
            to: nil
        )
    }

    @objc private func editAccessibilityAction() -> Bool {
        onEditTapped?()
        return true
    }
}

private final class OverviewShiftEndpointsView: UIView {
    private let startCaption = UILabel()
    private let startTime = UILabel()
    private let startDate = UILabel()
    private let endCaption = UILabel()
    private let endTime = UILabel()
    private let endDate = UILabel()
    private let startGroup = UIStackView()
    private let endGroup = UIStackView()
    private let columns = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        startCaption.text = AddShiftStrings.start
        endCaption.text = AddShiftStrings.end
        for (group, labels) in [
            (startGroup, [startCaption, startTime, startDate]),
            (endGroup, [endCaption, endTime, endDate])
        ] {
            group.axis = .vertical
            group.spacing = 6
            labels.forEach {
                $0.numberOfLines = 0
                $0.adjustsFontForContentSizeCategory = true
                $0.isAccessibilityElement = false
                group.addArrangedSubview($0)
            }
        }
        columns.spacing = 24
        columns.translatesAutoresizingMaskIntoConstraints = false
        [startGroup, endGroup].forEach(columns.addArrangedSubview)
        addSubview(columns)
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: topAnchor),
            columns.leadingAnchor.constraint(equalTo: leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
            (view: OverviewShiftEndpointsView, _: UITraitCollection) in
            view.updateLayout()
        }
        updateLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    func update(
        endpoints: OverviewFormatting.ShiftEndpoints,
        foreground: UIColor,
        identifierPrefix: String
    ) {
        accessibilityIdentifier = identifierPrefix
        for (label, text, suffix) in [
            (startTime, Optional(endpoints.startTime), "start"),
            (endTime, Optional(endpoints.endTime), "end"),
            (startDate, endpoints.startDate, "startDate"),
            (endDate, endpoints.endDate, "endDate")
        ] {
            label.text = text
            label.isHidden = text == nil
            label.accessibilityIdentifier = "\(identifierPrefix).\(suffix)"
        }
        [startTime, endTime].forEach { $0.textColor = foreground }
        [startCaption, endCaption, startDate, endDate].forEach {
            $0.textColor = foreground.withAlphaComponent(0.78)
        }
        updateLayout()
    }

    private func updateLayout() {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        [startTime, endTime].forEach {
            $0.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: font, compatibleWith: traitCollection)
        }
        [startCaption, endCaption, startDate, endDate].forEach {
            $0.font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traitCollection)
        }
        let requiredColumnWidth = max(
            startGroup.arrangedSubviews.map { $0.intrinsicContentSize.width }.max() ?? 0,
            endGroup.arrangedSubviews.map { $0.intrinsicContentSize.width }.max() ?? 0
        )
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || (bounds.width > 0 && requiredColumnWidth * 2 + columns.spacing > bounds.width)
        columns.axis = vertical ? .vertical : .horizontal
        columns.distribution = vertical ? .fill : .fillEqually
        startGroup.alignment = .leading
        endGroup.alignment = vertical ? .leading : .trailing
        [endCaption, endTime, endDate].forEach { $0.textAlignment = vertical ? .left : .right }
    }
}
