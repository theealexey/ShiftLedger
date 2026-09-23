import UIKit

final class PaycheckResultView: UIView {
    struct BreakdownRow {
        let workTypeName: String
        let date: String
        let duration: String
        let rate: String
        let amount: String
    }

    struct RenderModel {
        let expected: String
        let actual: String
        let difference: String
        let explanation: String
        let breakdownRows: [BreakdownRow]
        let emptyBreakdownMessage: String?
    }

    var onDoneTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let mainStack = UIStackView()

    private let summaryCard = UIView()
    private let summaryStack = UIStackView()
    private let expectedStack = UIStackView()
    private let expectedLabel = UILabel()
    private let expectedValueLabel = UILabel()
    private let actualStack = UIStackView()
    private let actualLabel = UILabel()
    private let actualValueLabel = UILabel()
    private let differenceStack = UIStackView()
    private let differenceLabel = UILabel()
    private let differenceValueLabel = UILabel()

    private let explanationLabel = UILabel()
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(_ model: RenderModel) {
        expectedValueLabel.text = model.expected
        expectedValueLabel.accessibilityLabel = model.expected
        actualValueLabel.text = model.actual
        actualValueLabel.accessibilityLabel = model.actual
        differenceValueLabel.text = model.difference
        differenceValueLabel.accessibilityLabel = model.difference
        explanationLabel.text = model.explanation

        breakdownRowsStack.arrangedSubviews.forEach { row in
            breakdownRowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for (index, row) in model.breakdownRows.enumerated() {
            breakdownRowsStack.addArrangedSubview(makeBreakdownRow(row, index: index))
        }

        emptyBreakdownLabel.text = model.emptyBreakdownMessage
        emptyBreakdownLabel.isHidden = model.emptyBreakdownMessage == nil
    }

    private func configureAppearance() {
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
        explanationLabel.accessibilityIdentifier = "paycheckResult.explanation"

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
        [summaryCard, explanationLabel, breakdownTitleLabel, breakdownRowsStack, emptyBreakdownLabel, doneButton]
            .forEach(mainStack.addArrangedSubview)

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

            doneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func configureInteractions() {
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
            (PaycheckResultStrings.paidTime, row.duration, ShiftLedgerTypography.body, "duration"),
            (PaycheckResultStrings.rate, row.rate, ShiftLedgerTypography.body, "rate"),
            (PaycheckResultStrings.shiftExpected, row.amount, ShiftLedgerTypography.headline, "amount")
        ]
        for (metricIndex, metric) in metrics.enumerated() {
            stack.addArrangedSubview(makeBreakdownValue(
                title: metric.0,
                value: metric.1,
                valueFont: metric.2,
                identifier: "paycheckResult.breakdown.row.\(index).\(metric.3)"
            ))
            if metricIndex < metrics.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
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
        valueFont: UIFont,
        identifier: String
    ) -> BreakdownMetricRow {
        BreakdownMetricRow(
            title: title,
            value: value,
            valueFont: valueFont,
            identifier: identifier
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

    private final class BreakdownMetricRow: UIStackView {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()

        init(title: String, value: String, valueFont: UIFont, identifier: String) {
            super.init(frame: .zero)

            configureLabel(titleLabel, font: ShiftLedgerTypography.callout, color: ShiftLedgerColors.textSecondary)
            titleLabel.text = title
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

            configureLabel(valueLabel, font: valueFont, color: ShiftLedgerColors.textPrimary)
            valueLabel.text = value
            valueLabel.accessibilityIdentifier = identifier

            [titleLabel, valueLabel].forEach(addArrangedSubview)
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: BreakdownMetricRow, _) in
                self.updateDynamicTypeLayout()
            }
            updateDynamicTypeLayout()
        }

        @available(*, unavailable)
        required init(coder: NSCoder) {
            super.init(coder: coder)
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
