import UIKit

final class OverviewView: UIView, UIScrollViewDelegate {
    struct PeriodItem: Equatable {
        let period: PayCalculationPeriod
        let title: String
        let isSelected: Bool
    }

    struct ShiftCard: Equatable {
        let id: UUID
        let date: String
        let timeRange: String
        let expectedAmount: String
        let paidDuration: String
        let unpaidBreak: String?
        let isSelected: Bool
        let accessibilityLabel: String
    }

    var onPreviousPeriodTapped: (() -> Void)?
    var onNextPeriodTapped: (() -> Void)?
    var onPeriodTapped: ((PayCalculationPeriod) -> Void)?
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
    private let shiftCardsStack = UIStackView()
    private let shiftHistoryEmptyLabel = UILabel()
    private var shiftCardViews: [UUID: OverviewShiftCardView] = [:]

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
        guard !periodRailScrollView.isHidden,
              !periodRailScrollView.isDragging,
              !periodRailScrollView.isDecelerating,
              let selected = periodRailStack.arrangedSubviews.first(where: {
                  $0.accessibilityTraits.contains(.selected)
              }) as? OverviewPeriodRailItem else { return }
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

    func focusShiftCard(with id: UUID) {
        guard let card = shiftCardViews[id] else {
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

        mainStack.axis = .vertical
        mainStack.spacing = 16

        contentCard.backgroundColor = ShiftLedgerColors.accentPrimary
        contentCard.layer.cornerCurve = .continuous
        contentCard.layer.cornerRadius = 28
        configureCard(emptyCard)
        configureCard(errorCard)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        expectedGrossLabel.text = OverviewStrings.expectedGross
        configureLabel(
            expectedGrossLabel,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.textOnAccent
        )
        expectedGrossLabel.accessibilityIdentifier = "overview.expectedGross.label"

        configureLabel(
            expectedGrossAmountLabel,
            font: ShiftLedgerTypography.expectedGrossDisplay,
            color: ShiftLedgerColors.textOnAccent
        )
        expectedGrossAmountLabel.accessibilityIdentifier = "overview.expectedGross.amount"

        navigationStack.axis = .horizontal
        navigationStack.alignment = .center
        navigationStack.distribution = .equalSpacing
        navigationStack.spacing = 8
        periodRailContainer.axis = .vertical
        periodRailContainer.spacing = 8
        periodRailScrollView.showsHorizontalScrollIndicator = false
        periodRailScrollView.alwaysBounceHorizontal = true
        periodRailScrollView.delegate = self
        periodRailScrollView.accessibilityIdentifier = "overview.period.rail"
        periodRailStack.axis = .horizontal
        periodRailStack.spacing = 8
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
        periodLabel.accessibilityIdentifier = "overview.period.label"
        periodLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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

        shiftCardsStack.axis = .vertical
        shiftCardsStack.spacing = 12
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
            shiftCardsStack,
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

        [periodLabel, periodRailScrollView, navigationStack].forEach(periodRailContainer.addArrangedSubview)
        navigationStack.addArrangedSubview(previousButton)
        navigationStack.addArrangedSubview(nextButton)
        periodRailScrollView.addSubview(periodRailStack)

        contentCard.addSubview(contentStack)
        [expectedGrossLabel, expectedGrossAmountLabel]
            .forEach(contentStack.addArrangedSubview)
        [shiftCountLabel, shiftCountValueLabel].forEach(shiftCountStack.addArrangedSubview)

        [shiftCountStack, shiftCardsStack, shiftHistoryEmptyLabel]
            .forEach(shiftHistoryStack.addArrangedSubview)

        emptyCard.addSubview(emptyStack)
        [emptyTitleLabel, emptyMessageLabel].forEach(emptyStack.addArrangedSubview)

        errorCard.addSubview(errorStack)
        [errorTitleLabel, errorMessageLabel, retryButton].forEach(errorStack.addArrangedSubview)

        contentCard.accessibilityElements = [expectedGrossLabel, expectedGrossAmountLabel]
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: contentCard.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: contentCard.bottomAnchor, constant: -20),

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
            : UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .large
        if isPrimary {
            configuration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        } else {
            configuration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        }
        button.configuration = configuration
        button.tintColor = ShiftLedgerColors.accentPrimary
        button.titleLabel?.font = ShiftLedgerTypography.button
        button.titleLabel?.adjustsFontForContentSizeCategory = true
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
        shiftCardViews.removeAll()
        shiftCardsStack.arrangedSubviews.forEach { view in
            shiftCardsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for card in cards {
            let cardView = OverviewShiftCardView(card: card)
            shiftCardsStack.addArrangedSubview(cardView)
            shiftCardViews[card.id] = cardView
        }

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
            itemView.widthAnchor.constraint(equalTo: periodRailScrollView.frameLayoutGuide.widthAnchor, multiplier: 0.72).isActive = true
        }
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
        periodRailScrollView.isHidden = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        periodLabel.isHidden = !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        needsPeriodCentering = true
        setNeedsLayout()
    }
}

private final class OverviewPeriodRailItem: UIControl {
    let period: PayCalculationPeriod

    init(item: OverviewView.PeriodItem) {
        period = item.period
        super.init(frame: .zero)
        backgroundColor = item.isSelected ? ShiftLedgerColors.backgroundSecondary : ShiftLedgerColors.surfacePrimary
        layer.cornerCurve = .continuous
        layer.cornerRadius = 18
        accessibilityLabel = item.title
        accessibilityTraits = item.isSelected ? [.button, .selected] : .button

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = item.isSelected ? ShiftLedgerTypography.headline : ShiftLedgerTypography.callout
        titleLabel.textColor = item.isSelected ? ShiftLedgerColors.textPrimary : ShiftLedgerColors.textSecondary
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "overview.period.item.title"
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private final class OverviewShiftCardView: UIView {
    private let dateLabel = UILabel()
    private let selectedIndicator = UIImageView()
    private let timeRangeLabel = UILabel()
    private let expectedAmountLabel = UILabel()
    private let paidDurationLabel = UILabel()
    private let unpaidBreakLabel = UILabel()

    init(card: OverviewView.ShiftCard) {
        super.init(frame: .zero)
        configureAppearance(card: card)
        configureHierarchy()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configureAppearance(card: OverviewView.ShiftCard) {
        backgroundColor = ShiftLedgerColors.surfacePrimary
        layer.cornerCurve = .continuous
        layer.cornerRadius = 20
        layer.borderWidth = card.isSelected ? 2 : 0
        layer.borderColor = ShiftLedgerColors.accentPrimary.cgColor
        accessibilityIdentifier = "overview.shift.\(card.id.uuidString)"
        isAccessibilityElement = true
        accessibilityLabel = card.accessibilityLabel
        accessibilityTraits = card.isSelected ? .selected : []

        dateLabel.text = card.date
        configureLabel(dateLabel, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        dateLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).date"

        selectedIndicator.image = UIImage(systemName: "checkmark.circle.fill")
        selectedIndicator.tintColor = ShiftLedgerColors.accentPrimary
        selectedIndicator.isHidden = card.isSelected == false
        selectedIndicator.isAccessibilityElement = false
        selectedIndicator.setContentHuggingPriority(.required, for: .horizontal)
        selectedIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        timeRangeLabel.text = card.timeRange
        configureLabel(timeRangeLabel, font: ShiftLedgerTypography.body, color: ShiftLedgerColors.textSecondary)
        timeRangeLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).time"

        expectedAmountLabel.text = card.expectedAmount
        configureLabel(expectedAmountLabel, font: ShiftLedgerTypography.basePayAmount, color: ShiftLedgerColors.textPrimary)
        expectedAmountLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).expected"

        paidDurationLabel.text = card.paidDuration
        configureLabel(paidDurationLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        paidDurationLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).duration"

        unpaidBreakLabel.text = card.unpaidBreak.map { "\(AddShiftStrings.unpaidBreak): \($0)" }
        configureLabel(unpaidBreakLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        unpaidBreakLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).break"
        unpaidBreakLabel.isHidden = card.unpaidBreak == nil
    }

    private func configureHierarchy() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = UIStackView(arrangedSubviews: [dateLabel, selectedIndicator])
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 8
        dateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(stack)
        [header, timeRangeLabel, expectedAmountLabel, paidDurationLabel, unpaidBreakLabel]
            .forEach(stack.addArrangedSubview)
    }

    private func configureLayout() {
        guard let stack = subviews.first else {
            return
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            selectedIndicator.widthAnchor.constraint(equalToConstant: 20),
            selectedIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }
}
