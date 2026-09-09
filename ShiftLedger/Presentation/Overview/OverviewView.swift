import UIKit

final class OverviewView: UIView {
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
    var onCheckPaycheckTapped: (() -> Void)?
    var onAddShiftTapped: (() -> Void)?
    var onRetryTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()

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
    private let shiftHistoryTitleLabel = UILabel()
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
        renderIdle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func renderContent(
        expectedGross: String,
        period: String,
        shiftCount: Int,
        shiftCards: [ShiftCard],
        canNavigatePrevious: Bool,
        canNavigateNext: Bool,
        canCheckPaycheck: Bool
    ) {
        expectedGrossAmountLabel.text = expectedGross
        expectedGrossAmountLabel.accessibilityLabel = expectedGross
        periodLabel.text = period
        periodLabel.accessibilityLabel = period
        shiftCountValueLabel.text = String(shiftCount)
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

        configureCard(contentCard)
        configureCard(emptyCard)
        configureCard(errorCard)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        expectedGrossLabel.text = OverviewStrings.expectedGross
        configureLabel(
            expectedGrossLabel,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.textSecondary
        )
        expectedGrossLabel.accessibilityIdentifier = "overview.expectedGross.label"

        configureLabel(
            expectedGrossAmountLabel,
            font: ShiftLedgerTypography.display,
            color: ShiftLedgerColors.textPrimary
        )
        expectedGrossAmountLabel.accessibilityIdentifier = "overview.expectedGross.amount"

        navigationStack.axis = .horizontal
        navigationStack.alignment = .center
        navigationStack.spacing = 8
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
        configureLabel(periodLabel, font: ShiftLedgerTypography.body, color: ShiftLedgerColors.textPrimary)
        periodLabel.textAlignment = .center
        periodLabel.accessibilityIdentifier = "overview.period.label"
        periodLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        shiftCountStack.axis = .horizontal
        shiftCountStack.alignment = .firstBaseline
        shiftCountStack.spacing = 12
        shiftCountLabel.text = OverviewStrings.shiftsInPeriod
        configureLabel(
            shiftCountLabel,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.textSecondary
        )
        shiftCountLabel.accessibilityIdentifier = "overview.shiftCount.label"
        configureLabel(
            shiftCountValueLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftCountValueLabel.textAlignment = .right
        shiftCountValueLabel.accessibilityIdentifier = "overview.shiftCount.value"
        shiftCountValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        shiftHistoryStack.axis = .vertical
        shiftHistoryStack.spacing = 12
        shiftHistoryTitleLabel.text = OverviewStrings.shiftsInPeriod
        configureLabel(
            shiftHistoryTitleLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftHistoryTitleLabel.accessibilityIdentifier = "overview.shiftHistory.title"

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
        [contentCard, shiftHistoryStack, checkPaycheckButton, emptyCard, errorCard, addShiftButton]
            .forEach(mainStack.addArrangedSubview)

        contentCard.addSubview(contentStack)
        [expectedGrossLabel, expectedGrossAmountLabel, navigationStack, shiftCountStack]
            .forEach(contentStack.addArrangedSubview)
        [previousButton, periodLabel, nextButton].forEach(navigationStack.addArrangedSubview)
        [shiftCountLabel, shiftCountValueLabel].forEach(shiftCountStack.addArrangedSubview)

        [shiftHistoryTitleLabel, shiftCardsStack, shiftHistoryEmptyLabel]
            .forEach(shiftHistoryStack.addArrangedSubview)

        emptyCard.addSubview(emptyStack)
        [emptyTitleLabel, emptyMessageLabel].forEach(emptyStack.addArrangedSubview)

        errorCard.addSubview(errorStack)
        [errorTitleLabel, errorMessageLabel, retryButton].forEach(errorStack.addArrangedSubview)

        contentCard.accessibilityElements = [
            expectedGrossLabel,
            expectedGrossAmountLabel,
            periodLabel,
            previousButton,
            nextButton,
            shiftCountLabel,
            shiftCountValueLabel
        ]
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
