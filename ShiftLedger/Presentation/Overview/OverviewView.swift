import UIKit

final class OverviewView: UIView, UIScrollViewDelegate {
    struct PrecisionExplanation: Equatable {
        let exactTotal: String
        let displayedTotal: String
    }
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
        let exactExpectedAmount: String?
        let paidDuration: String
        let unpaidBreak: String?
        let unpaidBreakTimeRange: String?
        let appliedRate: String
        let appliedRateAmount: String
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
    private let periodCard = UIView()
    private let periodStack = UIStackView()
    private let periodCaption = UILabel()
    private let historyCard = UIView()
    private let perShiftPeriodLabel = UILabel()
    private let perShiftTimeLabel = UILabel()
    private let perShiftHeading = UIStackView()
    private let precisionLabel = UILabel()
    private let precisionStack = UIStackView()
    private let exactTotalField = OverviewReceiptFieldView()
    private let displayedTotalField = OverviewReceiptFieldView()
    private let historyScopeLabel = UILabel()

    private let periodRailContainer = UIStackView()
    private var showsPeriodNavigation = false
    private let periodRailViewport = UIView()
    private let periodRailScrollView = UIScrollView()
    private let periodRailStack = UIStackView()
    private lazy var periodRailViewportWidthConstraint =
        periodRailScrollView.widthAnchor.constraint(equalToConstant: 0)
    private var needsPeriodCentering = false
    private let contentCard = UIView()
    private let contentStack = UIStackView()
    private let expectedGrossLabel = UILabel()
    private let expectedGrossAmountLabel = UILabel()
    private let grossMeasurementLabel = UILabel()
    private var grossFontLayout: (text: String, width: CGFloat, category: UIContentSizeCategory, scale: CGFloat)?
    private var grossAmountText = ""
    private var grossAmountLocale = Locale.current
    private let navigationStack = UIStackView()
    private let previousButton = UIButton(type: .system)
    private let periodLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let shiftCountStack = UIStackView()
    private let shiftCountLabel = UILabel()
    private let shiftCountValueLabel = UILabel()

    private let shiftHistoryStack = UIStackView()
    private let shiftStack = OverviewShiftLedgerView()
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
            self.setNeedsLayout()
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
        amountLocale: Locale = .current,
        precisionExplanation: PrecisionExplanation? = nil,
        period: String,
        periodTime: String? = nil,
        periodAccessibilityLabel: String? = nil,
        periodItems: [PeriodItem],
        showPeriodNavigation: Bool,
        shiftCount: Int,
        shiftCards: [ShiftCard],
        canNavigatePrevious: Bool,
        canNavigateNext: Bool,
        canCheckPaycheck: Bool
    ) {
        showsPeriodNavigation = showPeriodNavigation
        periodRailContainer.accessibilityElementsHidden = !showPeriodNavigation
        grossAmountText = expectedGross
        grossAmountLocale = amountLocale
        grossFontLayout = nil
        expectedGrossAmountLabel.text = expectedGross
        expectedGrossAmountLabel.numberOfLines = 1
        expectedGrossAmountLabel.textAlignment = .natural
        updateGrossAmountFont()
        expectedGrossAmountLabel.accessibilityLabel = "\(expectedGrossContext), \(expectedGross)"
        expectedGrossLabel.text = expectedGrossContext
        precisionLabel.text = OverviewStrings.roundedForDisplay
        precisionStack.isHidden = precisionExplanation == nil
        if let precisionExplanation {
            exactTotalField.update(label: OverviewStrings.exactTotal, value: precisionExplanation.exactTotal,
                                   identifier: "overview.receipt.precision.exact")
            displayedTotalField.update(label: OverviewStrings.displayedTotal, value: precisionExplanation.displayedTotal,
                                       identifier: "overview.receipt.precision.displayed")
        }
        contentCard.accessibilityElements = precisionExplanation == nil
            ? [expectedGrossAmountLabel]
            : [expectedGrossAmountLabel, exactTotalField, displayedTotalField, precisionLabel]
        periodLabel.text = period
        periodLabel.accessibilityLabel = period
        perShiftPeriodLabel.text = period
        perShiftPeriodLabel.accessibilityLabel = periodAccessibilityLabel ?? period
        perShiftTimeLabel.text = periodTime
        perShiftTimeLabel.isHidden = periodTime == nil
        renderPeriodRail(periodItems)
        shiftCountValueLabel.text = String(shiftCount)
        shiftCountStack.accessibilityLabel = "\(OverviewStrings.allShiftHistory) \(shiftCount)"
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
        contentStack.layoutIfNeeded()
        updateGrossAmountFont()
        updateShiftHistoryHeading()
        updatePerShiftTimeFont()
        periodRailContainer.layoutIfNeeded()
        periodRailViewport.layoutIfNeeded()
        periodRailStack.layoutIfNeeded()
        if !periodRailScrollView.isHidden,
           !periodRailScrollView.isDragging,
           !periodRailScrollView.isDecelerating,
           let selected = periodRailStack.arrangedSubviews.first(where: {
               $0.accessibilityTraits.contains(.selected)
           }) as? OverviewPeriodRailItem {
            let viewportWidth = min(selected.bounds.width, periodRailViewport.bounds.width)
            if viewportWidth > 0,
               abs(periodRailViewportWidthConstraint.constant - viewportWidth) > 0.5 {
                periodRailViewportWidthConstraint.constant = viewportWidth
                needsPeriodCentering = true
                periodRailViewport.layoutIfNeeded()
            }
            periodRailScrollView.layoutIfNeeded()
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
        guard let card = shiftStack.rowView(with: id) else {
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
        renderShiftHistory([])
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
        mainStack.spacing = 16
        periodCard.accessibilityIdentifier = "overview.period.card"
        historyCard.accessibilityIdentifier = "overview.shiftHistory.section"
        [periodCard, contentCard, historyCard, emptyCard, errorCard].forEach(configureCard)
        periodStack.axis = .vertical
        periodStack.spacing = 8
        periodCaption.text = String(localized: "overview.payPeriod.caption", table: "Localizable")
        configureLabel(periodCaption, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        perShiftPeriodLabel.accessibilityIdentifier = "overview.receipt.perShiftPeriod"
        configureLabel(perShiftPeriodLabel, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        perShiftPeriodLabel.textAlignment = .center
        perShiftPeriodLabel.isAccessibilityElement = true
        configureLabel(perShiftTimeLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        perShiftTimeLabel.adjustsFontForContentSizeCategory = false
        perShiftTimeLabel.lineBreakMode = .byWordWrapping
        perShiftTimeLabel.lineBreakStrategy = []
        perShiftTimeLabel.textAlignment = .center
        perShiftTimeLabel.isAccessibilityElement = false
        perShiftTimeLabel.accessibilityIdentifier = "overview.receipt.perShiftTime"
        perShiftHeading.axis = .vertical
        perShiftHeading.spacing = 6
        perShiftHeading.addArrangedSubview(perShiftPeriodLabel)
        perShiftHeading.addArrangedSubview(perShiftTimeLabel)
        contentCard.accessibilityIdentifier = "overview.expectedGross.hero"

        contentStack.axis = .vertical
        contentStack.spacing = 8
        expectedGrossLabel.text = OverviewStrings.expectedGross
        configureLabel(
            expectedGrossLabel,
            font: UIFontMetrics(forTextStyle: .callout).scaledFont(
                for: .monospacedSystemFont(ofSize: 14, weight: .medium)
            ),
            color: ShiftLedgerColors.textSecondary
        )
        expectedGrossLabel.accessibilityIdentifier = "overview.expectedGross.label"
        expectedGrossLabel.isAccessibilityElement = false

        configureLabel(
            expectedGrossAmountLabel,
            font: ShiftLedgerTypography.expectedGrossDisplay,
            color: ShiftLedgerColors.textPrimary
        )
        expectedGrossAmountLabel.accessibilityIdentifier = "overview.expectedGross.amount"
        expectedGrossAmountLabel.isAccessibilityElement = true
        expectedGrossAmountLabel.numberOfLines = 1
        expectedGrossAmountLabel.adjustsFontForContentSizeCategory = false
        configureLabel(precisionLabel, font: UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .monospacedSystemFont(ofSize: 12, weight: .regular)
        ), color: ShiftLedgerColors.textSecondary)
        precisionLabel.accessibilityIdentifier = "overview.receipt.precision"
        precisionStack.axis = .vertical
        precisionStack.spacing = 8
        [exactTotalField, displayedTotalField, precisionLabel].forEach(precisionStack.addArrangedSubview)
        exactTotalField.isAccessibilityElement = true
        displayedTotalField.isAccessibilityElement = true
        exactTotalField.accessibilityIdentifier = "overview.receipt.precision.exactField"
        displayedTotalField.accessibilityIdentifier = "overview.receipt.precision.displayedField"

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
        shiftCountStack.distribution = .equalSpacing
        shiftCountStack.spacing = 4
        shiftCountStack.isAccessibilityElement = true
        shiftCountStack.accessibilityTraits = .header
        shiftCountStack.accessibilityIdentifier = "overview.shiftHistory.title"
        shiftCountLabel.text = OverviewStrings.allShiftHistory
        configureLabel(
            shiftCountLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftCountLabel.accessibilityIdentifier = "overview.shiftCount.label"
        shiftCountLabel.lineBreakMode = .byWordWrapping
        shiftCountLabel.adjustsFontForContentSizeCategory = false
        shiftCountLabel.lineBreakStrategy = []
        shiftCountLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        configureLabel(
            shiftCountValueLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        shiftCountValueLabel.textAlignment = .left
        shiftCountValueLabel.accessibilityIdentifier = "overview.shiftCount.value"
        historyScopeLabel.text = OverviewStrings.historyScope
        configureLabel(historyScopeLabel, font: UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .monospacedSystemFont(ofSize: 12, weight: .regular)
        ), color: ShiftLedgerColors.textSecondary)
        historyScopeLabel.accessibilityIdentifier = "overview.receipt.historyScope"

        shiftHistoryStack.axis = .vertical
        shiftHistoryStack.spacing = 12

        shiftStack.accessibilityIdentifier = "overview.shiftStack"
        shiftHistoryEmptyLabel.text = OverviewStrings.noSavedShifts
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
            periodStack,
            periodRailContainer,
            periodRailViewport,
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
        [emptyCard, periodCard, contentCard, historyCard, checkPaycheckButton, addShiftButton, errorCard]
            .forEach(mainStack.addArrangedSubview)
        periodCard.addSubview(periodStack)
        [periodCaption, periodRailContainer, perShiftHeading].forEach(periodStack.addArrangedSubview)
        historyCard.addSubview(shiftHistoryStack)

        periodRailContainer.addArrangedSubview(periodLabel)
        periodRailContainer.addArrangedSubview(navigationStack)
        navigationStack.addArrangedSubview(previousButton)
        navigationStack.addArrangedSubview(periodRailViewport)
        navigationStack.addArrangedSubview(nextButton)
        periodRailViewport.addSubview(periodRailScrollView)
        periodRailScrollView.addSubview(periodRailStack)

        contentCard.addSubview(contentStack)
        [expectedGrossLabel, expectedGrossAmountLabel, precisionStack]
            .forEach(contentStack.addArrangedSubview)
        [shiftCountLabel, shiftCountValueLabel].forEach(shiftCountStack.addArrangedSubview)

        [shiftCountStack, historyScopeLabel, shiftStack, shiftHistoryEmptyLabel]
            .forEach(shiftHistoryStack.addArrangedSubview)

        emptyCard.addSubview(emptyStack)
        [emptyTitleLabel, emptyMessageLabel].forEach(emptyStack.addArrangedSubview)

        errorCard.addSubview(errorStack)
        [errorTitleLabel, errorMessageLabel, retryButton].forEach(errorStack.addArrangedSubview)

        contentCard.accessibilityElements = [expectedGrossAmountLabel]

    }

    private func configureLayout() {
        for (card, stack) in [(periodCard, periodStack), (contentCard, contentStack),
                              (historyCard, shiftHistoryStack), (emptyCard, emptyStack)] {
            let guide = card.layoutMarginsGuide
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: guide.topAnchor),
                stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
            ])
        }
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
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            periodRailScrollView.topAnchor.constraint(equalTo: periodRailViewport.topAnchor),
            periodRailScrollView.bottomAnchor.constraint(equalTo: periodRailViewport.bottomAnchor),
            periodRailScrollView.centerXAnchor.constraint(equalTo: periodRailViewport.centerXAnchor),
            periodRailViewportWidthConstraint,
            periodRailScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            periodRailScrollView.heightAnchor.constraint(equalTo: periodRailStack.heightAnchor),
            periodRailStack.leadingAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.leadingAnchor),
            periodRailStack.trailingAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.trailingAnchor),
            periodRailStack.topAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.topAnchor),
            periodRailStack.bottomAnchor.constraint(equalTo: periodRailScrollView.contentLayoutGuide.bottomAnchor),

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
        card.layer.cornerRadius = 16
        card.insetsLayoutMarginsFromSafeArea = false
        card.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    }

    private func updatePerShiftTimeFont() {
        let label = perShiftTimeLabel
        guard !perShiftHeading.isHidden, !label.isHidden,
              let text = label.text, label.bounds.width > 0 else { return }
        let traits = label.traitCollection
        let preferred = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traits)
        var fitted = preferred
        if traits.preferredContentSizeCategory.isAccessibilityCategory {
            let scale = max(1, traits.displayScale)
            let width = (floor(label.bounds.width * scale) - 1) / scale
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = label.textAlignment
            paragraph.lineBreakMode = label.lineBreakMode
            paragraph.lineBreakStrategy = label.lineBreakStrategy
            let storage = NSTextStorage(string: text, attributes: [.paragraphStyle: paragraph])
            let manager = NSLayoutManager()
            let container = NSTextContainer(size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            container.lineBreakMode = label.lineBreakMode
            storage.addLayoutManager(manager)
            manager.addTextContainer(container)

            let fragments = text.split(whereSeparator: \.isWhitespace).map {
                NSRange($0.startIndex..<$0.endIndex, in: text)
            }
            let fullRange = NSRange(location: 0, length: storage.length)
            func fits(_ font: UIFont) -> Bool {
                storage.addAttribute(.font, value: font, range: fullRange)
                manager.ensureLayout(for: container)
                var lines: [NSRange] = []
                manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, glyphs, _ in
                    lines.append(manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil))
                }
                return fragments.allSatisfy { fragment in
                    lines.contains { NSIntersectionRange($0, fragment) == fragment }
                }
            }
            if !fits(preferred) {
                var lower = min(17, preferred.pointSize)
                var upper = preferred.pointSize
                if fits(preferred.withSize(lower)) {
                    for _ in 0..<14 {
                        let middle = (lower + upper) / 2
                        if fits(preferred.withSize(middle)) {
                            lower = middle
                        } else {
                            upper = middle
                        }
                    }
                    fitted = preferred.withSize(lower)
                }
            }
        }
        if label.font != fitted {
            label.font = fitted
        }
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
            configuration.baseForegroundColor = ShiftLedgerColors.onAccent
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
        periodCard.isHidden = !content
        historyCard.isHidden = !shiftHistory
        periodRailContainer.isHidden = !content || !showsPeriodNavigation
        perShiftHeading.isHidden = !content || showsPeriodNavigation
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
            if item.isSelected {
                itemView.accessibilityLabel = periodLabel.accessibilityLabel
            }
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

    private func updateGrossAmountFont() {
        guard contentStack.bounds.width > 0 else { return }
        let text = grossAmountText
        let preferred = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 52, weight: .bold),
            compatibleWith: traitCollection
        )
        let width = contentStack.bounds.width
        let category = traitCollection.preferredContentSizeCategory
        if let previous = grossFontLayout,
           previous.text == text, previous.width == width, previous.category == category,
           previous.scale == traitCollection.displayScale { return }
        let available = width - 1 / max(1, traitCollection.displayScale)
        grossMeasurementLabel.text = text
        grossMeasurementLabel.numberOfLines = 1
        func fits(_ size: CGFloat) -> Bool {
            grossMeasurementLabel.font = preferred.withSize(size)
            return grossMeasurementLabel.intrinsicContentSize.width <= available
        }
        let floor: CGFloat = 17
        if !fits(floor) {
            renderGroupedGross(text, preferred: preferred, available: available)
            grossFontLayout = (text, width, category, traitCollection.displayScale)
            return
        }
        var lower = floor
        var upper = preferred.pointSize
        if fits(upper) {
            lower = upper
        } else {
            for _ in 0..<16 {
                let candidate = (lower + upper) / 2
                if fits(candidate) { lower = candidate } else { upper = candidate }
            }
        }
        expectedGrossAmountLabel.text = text
        expectedGrossAmountLabel.numberOfLines = 1
        expectedGrossAmountLabel.textAlignment = .natural
        expectedGrossAmountLabel.font = preferred.withSize(lower)
        grossFontLayout = (text, width, category, traitCollection.displayScale)
    }

    private func renderGroupedGross(_ text: String, preferred: UIFont, available: CGFloat) {
        let formatter = NumberFormatter()
        formatter.locale = grossAmountLocale
        formatter.numberStyle = .currency
        let separator = formatter.currencyGroupingSeparator ?? formatter.groupingSeparator ?? ""
        let groups = separator.isEmpty ? [text] : text.components(separatedBy: separator)
        let tokens = groups.enumerated().map { index, group in
            index < groups.count - 1 ? group + separator : group
        }
        var size = max(17, UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection).pointSize)
        // Only whole groups are measured and wrapped; the final token includes the fraction.
        func measuredWidth(_ value: String) -> CGFloat {
            grossMeasurementLabel.text = value
            grossMeasurementLabel.font = preferred.withSize(size)
            return grossMeasurementLabel.intrinsicContentSize.width
        }
        while size > 17 && tokens.contains(where: { measuredWidth($0) > available }) {
            size = max(17, size - 1)
        }
        var lines: [String] = []
        var line = ""
        for token in tokens {
            if !line.isEmpty && measuredWidth(line + token) > available {
                lines.append(line)
                line = ""
            }
            line += token
        }
        if !line.isEmpty { lines.append(line) }
        expectedGrossAmountLabel.text = lines.joined(separator: "\n")
        expectedGrossAmountLabel.numberOfLines = 0
        expectedGrossAmountLabel.textAlignment = .right
        expectedGrossAmountLabel.font = preferred.withSize(size)
    }

    private func updateShiftHistoryHeading() {
        let width = contentStack.bounds.width
        guard width > 0, let text = shiftCountLabel.text else { return }
        let preferred = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        let measurement = UILabel()
        measurement.font = preferred
        measurement.text = text
        let titleWidth = measurement.intrinsicContentSize.width
        measurement.text = shiftCountValueLabel.text
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || titleWidth + measurement.intrinsicContentSize.width + shiftCountStack.spacing > width
        shiftCountStack.axis = vertical ? .vertical : .horizontal
        shiftCountStack.alignment = vertical ? .fill : .firstBaseline

        let available = width - 1 / max(1, traitCollection.displayScale)
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        func wordsFit(_ font: UIFont) -> Bool {
            measurement.font = font
            return words.allSatisfy {
                measurement.text = $0
                return measurement.intrinsicContentSize.width <= available
            }
        }
        var font = preferred
        if !wordsFit(preferred) {
            var lower: CGFloat = 17
            var upper = preferred.pointSize
            for _ in 0..<16 {
                let middle = (lower + upper) / 2
                if wordsFit(preferred.withSize(middle)) { lower = middle }
                else { upper = middle }
            }
            font = preferred.withSize(lower)
        }
        if shiftCountLabel.font != font { shiftCountLabel.font = font }
    }

    private func updatePeriodRailForContentSizeCategory() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        shiftCountStack.axis = usesAccessibilityLayout ? .vertical : .horizontal
        shiftCountStack.alignment = usesAccessibilityLayout ? .fill : .firstBaseline
        periodRailScrollView.isHidden = usesAccessibilityLayout
        periodRailViewport.isHidden = usesAccessibilityLayout
        periodLabel.isHidden = !usesAccessibilityLayout
        navigationStack.distribution = usesAccessibilityLayout ? .equalSpacing : .fill
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
