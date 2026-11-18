import UIKit

final class PaycheckResultView: UIView {
    typealias Amount = PaycheckResultFormatting.Amount

    struct BreakdownRow {
        let workTypeName: String
        let date: String
        let duration: String
        let rate: Amount
        let amount: Amount
    }

    struct RenderModel {
        let expectedAmount: Amount
        let actualAmount: Amount
        let differenceAmount: Amount
        let explanation: String
        let approximationNote: String?
        let breakdownRows: [BreakdownRow]
        let emptyBreakdownMessage: String?

        var expected: String { expectedAmount.text }
        var actual: String { actualAmount.text }
        var difference: String { differenceAmount.text }
    }

    var onDoneTapped: (() -> Void)?

    private let periodLabel = UILabel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()

    private let summaryCard = UIView()
    private let summaryStack = UIStackView()
    private let expectedStack = UIStackView()
    private let expectedLabel = UILabel()
    private let expectedValueLabel = SummaryValueLabel(isDifference: false)
    private let actualStack = UIStackView()
    private let actualLabel = UILabel()
    private let actualValueLabel = SummaryValueLabel(isDifference: false)
    private let differenceStack = UIStackView()
    private let differenceLabel = UILabel()
    private let differenceValueLabel = SummaryValueLabel(isDifference: true)

    private let explanationLabel = UILabel()
    private let approximationLabel = UILabel()
    private let exactAmountsButton = UIButton(type: .system)
    private let exactSummaryStack = UIStackView()
    private var exactBreakdownStacks: [UIStackView] = []
    private var showsExactAmounts = false
    private let breakdownTitleLabel = UILabel()
    private let breakdownRowsStack = UIStackView()
    private let emptyBreakdownLabel = UILabel()
    private let doneButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: PaycheckResultView, _) in
            self.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateExplanationWrapping()
    }

    private func updateExplanationWrapping() {
        guard explanationLabel.bounds.width > 1, let text = explanationLabel.text, !text.isEmpty else { return }
        let preferred = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let base = UIFont.systemFont(ofSize: preferred.pointSize, weight: .regular)
        let probe = UILabel()
        let scale = max(1, traitCollection.displayScale)
        let available = floor(explanationLabel.bounds.width * scale) / scale - 1 / scale
        let words = text.split(whereSeparator: { $0.isWhitespace })
        func fits(_ size: CGFloat) -> Bool {
            probe.font = base.withSize(size)
            return words.allSatisfy { word in
                probe.text = String(word)
                return ceil(probe.sizeThatFits(CGSize(width: 10000, height: 10000)).width * scale) / scale <= available
            }
        }
        var lower = min(17, base.pointSize)
        var upper = base.pointSize
        // Unsupported widths retain the canonical text; never install a known non-fitting font.
        guard fits(lower) else { return }
        if fits(upper) { lower = upper } else {
            for _ in 0..<14 {
                let candidate = (lower + upper) / 2
                if fits(candidate) { lower = candidate } else { upper = candidate }
            }
        }
        let font = base.withSize(lower)
        if explanationLabel.font == font,
           let current = explanationLabel.attributedText, current.string == text,
           current.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == font,
           let style = current.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
           style.lineBreakMode == .byWordWrapping, style.lineBreakStrategy.isEmpty,
           style.hyphenationFactor == 0.001, !style.usesDefaultHyphenation { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = []
        paragraph.hyphenationFactor = 0.001
        paragraph.usesDefaultHyphenation = false
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: ShiftLedgerColors.textSecondary, .paragraphStyle: paragraph
        ])
        if explanationLabel.font != font { explanationLabel.font = font }
        if explanationLabel.attributedText?.isEqual(to: attributed) != true {
            explanationLabel.attributedText = attributed
        }
    }

    func render(_ model: RenderModel) {
        for (label, amount) in [(expectedValueLabel, model.expectedAmount), (actualValueLabel, model.actualAmount),
                                (differenceValueLabel, model.differenceAmount)] {
            label.text = amount.text
            label.accessibilityLabel = amount.accessibilityText
        }
        explanationLabel.text = model.explanation
        approximationLabel.text = model.approximationNote
        approximationLabel.isHidden = model.approximationNote == nil

        for view in exactSummaryStack.arrangedSubviews {
            view.removeFromSuperview()
        }
        let exactSummary = [
            ("expected", PaycheckResultStrings.expected, model.expectedAmount.exact),
            ("actual", PaycheckResultStrings.actual, model.actualAmount.exact),
            ("difference", PaycheckResultStrings.difference, model.differenceAmount.exact)
        ]
        for (key, title, value) in exactSummary {
            exactSummaryStack.addArrangedSubview(makeExactField(
                title: title, value: value, identifier: "paycheckResult.exact.\(key)"
            ))
        }

        exactBreakdownStacks.removeAll()
        breakdownRowsStack.arrangedSubviews.forEach { row in
            breakdownRowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for (index, row) in model.breakdownRows.enumerated() {
            breakdownRowsStack.addArrangedSubview(makeBreakdownRow(row, index: index))
        }

        setExactAmountsVisible(false)
        emptyBreakdownLabel.text = model.emptyBreakdownMessage
        emptyBreakdownLabel.isHidden = model.emptyBreakdownMessage == nil
        setNeedsLayout()
    }

    func renderPeriod(_ heading: OverviewFormatting.PeriodHeading) {
        periodLabel.text = [heading.date, heading.time].compactMap { $0 }.joined(separator: "\n")
        periodLabel.accessibilityLabel = heading.accessibilityLabel
        periodLabel.isHidden = false
    }

    private func configureAppearance() {
        periodLabel.font = ShiftLedgerTypography.callout
        periodLabel.textColor = ShiftLedgerColors.textSecondary
        periodLabel.adjustsFontForContentSizeCategory = true
        periodLabel.numberOfLines = 0
        periodLabel.lineBreakMode = .byWordWrapping
        periodLabel.accessibilityIdentifier = "paycheckResult.period"
        periodLabel.isHidden = true
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "paycheckResult.screen"
        scrollView.alwaysBounceVertical = true

        mainStack.axis = .vertical
        mainStack.spacing = 16

        summaryCard.backgroundColor = ShiftLedgerColors.surfacePrimary
        summaryCard.layer.cornerCurve = .continuous
        summaryCard.layer.cornerRadius = 20
        summaryStack.axis = .vertical
        summaryStack.spacing = 16

        configureSummaryRow(
            expectedStack,
            titleLabel: expectedLabel,
            title: PaycheckResultStrings.expected,
            valueLabel: expectedValueLabel,
            valueFont: ShiftLedgerTypography.headline,
            labelIdentifier: "paycheckResult.expected.label",
            valueIdentifier: "paycheckResult.expected.value"
        )
        configureSummaryRow(
            actualStack,
            titleLabel: actualLabel,
            title: PaycheckResultStrings.actual,
            valueLabel: actualValueLabel,
            valueFont: ShiftLedgerTypography.headline,
            labelIdentifier: "paycheckResult.actual.label",
            valueIdentifier: "paycheckResult.actual.value"
        )
        configureSummaryRow(
            differenceStack,
            titleLabel: differenceLabel,
            title: PaycheckResultStrings.difference,
            valueLabel: differenceValueLabel,
            valueFont: ShiftLedgerTypography.display,
            labelIdentifier: "paycheckResult.difference.label",
            valueIdentifier: "paycheckResult.difference.value"
        )

        configureLabel(
            explanationLabel,
            font: ShiftLedgerTypography.body,
            color: ShiftLedgerColors.textSecondary
        )
        explanationLabel.adjustsFontForContentSizeCategory = false
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.lineBreakStrategy = []
        explanationLabel.accessibilityIdentifier = "paycheckResult.explanation"

        configureLabel(approximationLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        approximationLabel.accessibilityIdentifier = "paycheckResult.approximation"
        approximationLabel.isHidden = true

        exactAmountsButton.accessibilityIdentifier = "paycheckResult.exact.toggle"
        exactSummaryStack.axis = .vertical
        exactSummaryStack.spacing = 12
        exactSummaryStack.backgroundColor = ShiftLedgerColors.surfacePrimary
        exactSummaryStack.layer.cornerCurve = .continuous
        exactSummaryStack.layer.cornerRadius = 18
        exactSummaryStack.isLayoutMarginsRelativeArrangement = true
        exactSummaryStack.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        setExactAmountsVisible(false)

        configureLabel(
            breakdownTitleLabel,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        breakdownTitleLabel.text = PaycheckResultStrings.breakdownTitle
        breakdownTitleLabel.accessibilityTraits = .header
        breakdownTitleLabel.accessibilityIdentifier = "paycheckResult.breakdown.title"

        breakdownRowsStack.axis = .vertical
        breakdownRowsStack.spacing = 12

        configureLabel(
            emptyBreakdownLabel,
            font: ShiftLedgerTypography.body,
            color: ShiftLedgerColors.textSecondary
        )
        emptyBreakdownLabel.accessibilityIdentifier = "paycheckResult.breakdown.empty"

        var configuration = UIButton.Configuration.filled()
        configuration.title = PaycheckResultStrings.done
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        configuration.baseForegroundColor = ShiftLedgerColors.onAccent
        doneButton.configuration = configuration
        doneButton.titleLabel?.font = ShiftLedgerTypography.button
        doneButton.titleLabel?.adjustsFontForContentSizeCategory = true
        doneButton.accessibilityLabel = PaycheckResultStrings.done
        doneButton.accessibilityIdentifier = "paycheckResult.done"
    }

    private func configureHierarchy() {
        [scrollView, contentView, mainStack, summaryStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)
        [summaryCard, explanationLabel, approximationLabel, exactAmountsButton, exactSummaryStack,
         breakdownTitleLabel, breakdownRowsStack, emptyBreakdownLabel, doneButton]
            .forEach(mainStack.addArrangedSubview)

        mainStack.insertArrangedSubview(periodLabel, at: 0)

        summaryCard.addSubview(summaryStack)
        [expectedStack, actualStack, differenceStack].forEach(summaryStack.addArrangedSubview)
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

            summaryStack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 20),
            summaryStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 20),
            summaryStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -20),
            summaryStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -20),

            exactAmountsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            doneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func setExactAmountsVisible(_ visible: Bool) {
        showsExactAmounts = visible
        for stack in [exactSummaryStack] + exactBreakdownStacks {
            stack.isHidden = !visible
            stack.accessibilityElementsHidden = !visible
        }
        let title = visible ? PaycheckResultStrings.hideExactAmounts : PaycheckResultStrings.showExactAmounts
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.image = UIImage(systemName: visible ? "chevron.up" : "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        configuration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        configuration.cornerStyle = .large
        exactAmountsButton.configuration = configuration
        exactAmountsButton.titleLabel?.font = ShiftLedgerTypography.button
        exactAmountsButton.titleLabel?.adjustsFontForContentSizeCategory = true
        exactAmountsButton.accessibilityLabel = title
    }

    private func makeExactField(title: String, value: String, identifier: String) -> UIStackView {
        let titleLabel = UILabel()
        configureLabel(titleLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        titleLabel.text = title
        let valueLabel = UILabel()
        configureLabel(valueLabel, font: ShiftLedgerTypography.body, color: ShiftLedgerColors.textPrimary)
        valueLabel.text = value
        // Only the expanded evidence can contain an arbitrarily long exact digit sequence.
        valueLabel.lineBreakMode = .byCharWrapping
        let field = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        field.axis = .vertical
        field.spacing = 4
        field.isAccessibilityElement = true
        field.accessibilityTraits = .staticText
        field.accessibilityIdentifier = identifier
        field.accessibilityLabel = title
        field.accessibilityValue = value
        return field
    }

    private func configureInteractions() {
        exactAmountsButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.setExactAmountsVisible(!self.showsExactAmounts)
        }, for: .touchUpInside)
        doneButton.addAction(UIAction { [weak self] _ in
            self?.onDoneTapped?()
        }, for: .touchUpInside)
    }

    private func configureSummaryRow(
        _ stack: UIStackView,
        titleLabel: UILabel,
        title: String,
        valueLabel: UILabel,
        valueFont: UIFont,
        labelIdentifier: String,
        valueIdentifier: String
    ) {
        stack.axis = .vertical
        stack.spacing = 4
        configureLabel(titleLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        titleLabel.text = title
        titleLabel.accessibilityIdentifier = labelIdentifier
        configureLabel(valueLabel, font: valueFont, color: ShiftLedgerColors.textPrimary)
        valueLabel.accessibilityIdentifier = valueIdentifier
        valueLabel.adjustsFontForContentSizeCategory = false
        valueLabel.lineBreakMode = .byWordWrapping
        [titleLabel, valueLabel].forEach(stack.addArrangedSubview)
    }

    private func makeBreakdownRow(_ row: BreakdownRow, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = ShiftLedgerColors.surfacePrimary
        card.layer.cornerCurve = .continuous
        card.layer.cornerRadius = 18
        card.accessibilityIdentifier = "paycheckResult.breakdown.row.\(index)"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let workTypeLabel = UILabel()
        configureLabel(workTypeLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
        workTypeLabel.text = row.workTypeName
        workTypeLabel.accessibilityIdentifier = "paycheckResult.breakdown.row.\(index).workType"
        stack.addArrangedSubview(workTypeLabel)
        stack.setCustomSpacing(4, after: workTypeLabel)

        let dateLabel = UILabel()
        configureLabel(dateLabel, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        dateLabel.text = row.date
        dateLabel.accessibilityIdentifier = "paycheckResult.breakdown.row.\(index).date"
        stack.addArrangedSubview(dateLabel)
        stack.setCustomSpacing(14, after: dateLabel)

        let metrics = [
            (PaycheckResultStrings.paidTime, row.duration, row.duration, ShiftLedgerTypography.body, "duration"),
            (PaycheckResultStrings.rate, row.rate.text, row.rate.accessibilityText, ShiftLedgerTypography.body, "rate"),
            (PaycheckResultStrings.shiftExpected, row.amount.text, row.amount.accessibilityText,
             ShiftLedgerTypography.headline, "amount")
        ]
        for (metricIndex, metric) in metrics.enumerated() {
            stack.addArrangedSubview(makeBreakdownValue(
                title: metric.0,
                value: metric.1,
                accessibilityText: metric.2,
                valueFont: metric.3,
                identifier: "paycheckResult.breakdown.row.\(index).\(metric.4)",
                fitsTitleWords: metric.4 == "duration"
            ))
            if metricIndex < metrics.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }

        let exactMetrics = UIStackView()
        exactMetrics.axis = .vertical
        exactMetrics.spacing = 10
        if row.rate.needsExactDetail {
            exactMetrics.addArrangedSubview(makeExactField(title: PaycheckResultStrings.exactRate,
                value: row.rate.exact, identifier: "paycheckResult.breakdown.row.\(index).exactRate"))
        }
        if row.amount.needsExactDetail {
            exactMetrics.addArrangedSubview(makeExactField(title: PaycheckResultStrings.exactContribution,
                value: row.amount.exact, identifier: "paycheckResult.breakdown.row.\(index).exactAmount"))
        }
        if !exactMetrics.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(exactMetrics)
            exactBreakdownStacks.append(exactMetrics)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeBreakdownValue(
        title: String,
        value: String,
        accessibilityText: String,
        valueFont: UIFont,
        identifier: String,
        fitsTitleWords: Bool
    ) -> BreakdownMetricRow {
        BreakdownMetricRow(
            title: title,
            value: value,
            accessibilityText: accessibilityText,
            valueFont: valueFont,
            identifier: identifier,
            fitsTitleWords: fitsTitleWords
        )
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = ShiftLedgerColors.separator
        separator.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale).isActive = true
        return separator
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private final class SummaryValueLabel: UILabel {
        private let isDifference: Bool

        init(isDifference: Bool) {
            self.isDifference = isDifference
            super.init(frame: .zero)
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SummaryValueLabel, _) in
                self.setNeedsLayout()
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override var text: String? {
            didSet { setNeedsLayout() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let text, bounds.width > 1 else { return }
            var baseFont = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
            if isDifference {
                traitCollection.performAsCurrent { baseFont = ShiftLedgerTypography.display }
            }
            let measure = UILabel()
            let scale = max(1, traitCollection.displayScale)
            let available = floor(bounds.width * scale) / scale - 1 / scale
            func fits(_ value: String, at size: CGFloat) -> Bool {
                measure.text = value
                measure.font = baseFont.withSize(size)
                let width = measure.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)).width
                return ceil(width * scale) / scale <= available
            }
            var upper = baseFont.pointSize
            var lower = min(upper, max(17, upper * 0.75))
            // Prefer wrapping at the currency boundary over excessive font reduction.
            let parts = fits(text, at: lower) ? [text] : text.components(separatedBy: " ")
            func fits(_ size: CGFloat) -> Bool { parts.allSatisfy { fits($0, at: size) } }
            guard fits(lower) else {
                if font != baseFont.withSize(lower) { font = baseFont.withSize(lower) }
                return
            }
            if fits(upper) {
                lower = upper
            } else {
                for _ in 0..<14 {
                    let candidate = (lower + upper) / 2
                    if fits(candidate) { lower = candidate } else { upper = candidate }
                }
            }
            let fitted = baseFont.withSize(lower)
            if font != fitted { font = fitted }
        }
    }

    private final class BreakdownMetricRow: UIStackView {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()

        private let fitsTitleWords: Bool

        init(title: String, value: String, accessibilityText: String, valueFont: UIFont,
             identifier: String, fitsTitleWords: Bool) {
            self.fitsTitleWords = fitsTitleWords
            super.init(frame: .zero)

            configureLabel(titleLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
            titleLabel.text = title
            if fitsTitleWords {
                titleLabel.adjustsFontForContentSizeCategory = false
                titleLabel.lineBreakMode = .byWordWrapping
                titleLabel.lineBreakStrategy = []
            }
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            configureLabel(valueLabel, font: valueFont, color: ShiftLedgerColors.textPrimary)
            valueLabel.text = value
            valueLabel.accessibilityLabel = accessibilityText
            valueLabel.accessibilityIdentifier = identifier

            [titleLabel, valueLabel].forEach(addArrangedSubview)
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: BreakdownMetricRow, _) in
                self.updateDynamicTypeLayout()
            }
            updateDynamicTypeLayout()
        }

        @available(*, unavailable)
        required init(coder: NSCoder) {
            fitsTitleWords = false
            super.init(coder: coder)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard fitsTitleWords, let text = titleLabel.text, titleLabel.bounds.width > 0 else { return }
            let base = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
            let width = max(1, titleLabel.bounds.width - 1 / max(traitCollection.displayScale, 1))
            var font = base
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                let words = text.split(whereSeparator: { $0.isWhitespace })
                let probe = UILabel()
                func fits(_ font: UIFont) -> Bool {
                    probe.font = font
                    return words.allSatisfy {
                        probe.text = String($0)
                        return probe.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                        height: CGFloat.greatestFiniteMagnitude)).width <= width
                    }
                }
                if !fits(base) {
                    var lower = min(17, base.pointSize)
                    var upper = base.pointSize
                    for _ in 0..<12 {
                        let middle = (lower + upper) / 2
                        if fits(base.withSize(middle)) {
                            lower = middle
                        } else {
                            upper = middle
                        }
                    }
                    font = base.withSize(lower)
                }
            }
            if titleLabel.font != font { titleLabel.font = font }
        }

        private func updateDynamicTypeLayout() {
            let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            axis = usesAccessibilityLayout ? .vertical : .horizontal
            alignment = usesAccessibilityLayout ? .fill : .firstBaseline
            spacing = usesAccessibilityLayout ? 4 : 12
            valueLabel.textAlignment = usesAccessibilityLayout ? .natural : .right
        }

        private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
            label.font = font
            label.textColor = color
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
    }
}
