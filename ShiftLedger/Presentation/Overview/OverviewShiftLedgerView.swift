import UIKit

/// A presentation-only list. The supplied cards already contain exact, formatted Shift contributions.
final class OverviewShiftLedgerView: UIView {
    private let rows = UIStackView()
    private var rowViews: [UUID: OverviewShiftLedgerRowView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: topAnchor),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func render(
        _ cards: [OverviewView.ShiftCard],
        onCardTapped: ((UUID) -> Void)?,
        onEditTapped: ((UUID) -> Void)?
    ) {
        let currentIDs = Set(cards.map(\.id))
        for id in rowViews.keys.filter({ !currentIDs.contains($0) }) {
            rowViews.removeValue(forKey: id)?.removeFromSuperview()
        }

        for (index, card) in cards.enumerated() {
            let row: OverviewShiftLedgerRowView
            if let existing = rowViews[card.id] {
                row = existing
            } else {
                row = OverviewShiftLedgerRowView()
                row.translatesAutoresizingMaskIntoConstraints = false
                rowViews[card.id] = row
            }
            row.update(
                card,
                showsDivider: index < cards.count - 1,
                onCardTapped: onCardTapped,
                onEditTapped: onEditTapped
            )
            if rows.arrangedSubviews.indices.contains(index), rows.arrangedSubviews[index] === row {
                continue
            }
            rows.insertArrangedSubview(row, at: index)
        }
        accessibilityElements = cards.compactMap { rowViews[$0.id] }
    }

    func rowView(with id: UUID) -> UIView? { rowViews[id] }
}

final class OverviewShiftLedgerRowView: UIControl {
    private let content = UIStackView()
    private let heading = UIStackView()
    private let dateLabel = UILabel()
    private let amountLabel = UILabel()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()
    private let summary = UIStackView()
    private let summarySpacer = UIView()
    private let durationSummary = UIStackView()
    private let details = UIStackView()
    private let endpoints = OverviewShiftEndpointsView()
    private let paidTime = OverviewReceiptFieldView()
    private let exactAmount = OverviewReceiptFieldView()
    private let unpaidBreak = OverviewReceiptFieldView()
    private let rate = OverviewReceiptFieldView()
    private let payBasis = OverviewReceiptFieldView()
    private let editButton = UIButton(type: .system)
    private let disclosure = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let divider = OverviewReceiptRuleView()
    private let selectedRule = UIView()
    private var onCardTapped: (() -> Void)?
    private var onEditTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.updateHeadingAxis()
            self.updateEditButtonForContentSizeCategory()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        updateHeadingAxis()
        super.layoutSubviews()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point), !isHidden, isUserInteractionEnabled else { return nil }
        if !editButton.isHidden {
            let buttonPoint = editButton.convert(point, from: self)
            if editButton.point(inside: buttonPoint, with: event) {
                return editButton.hitTest(buttonPoint, with: event) ?? editButton
            }
        }
        return self
    }

    func update(
        _ card: OverviewView.ShiftCard,
        showsDivider: Bool,
        onCardTapped: ((UUID) -> Void)?,
        onEditTapped: ((UUID) -> Void)?
    ) {
        self.onCardTapped = { onCardTapped?(card.id) }
        self.onEditTapped = { onEditTapped?(card.id) }
        let prefix = "overview.shift.\(card.id.uuidString)"
        accessibilityIdentifier = prefix
        accessibilityLabel = card.accessibilityLabel
        accessibilityHint = !card.isSelected
            ? OverviewStrings.selectShift
            : card.isExpanded ? OverviewStrings.collapseShift : OverviewStrings.expandShift
        accessibilityValue = card.isExpanded ? OverviewStrings.expanded : OverviewStrings.collapsed
        accessibilityTraits = card.isSelected ? [.button, .selected] : .button
        accessibilityCustomActions = card.isExpanded
            ? [UIAccessibilityCustomAction(
                name: OverviewStrings.editShift,
                target: self,
                selector: #selector(editAccessibilityAction)
            )]
            : nil
        isAccessibilityElement = true

        backgroundColor = card.isSelected ? OverviewReceiptPaperView.selectedSurface : .clear
        selectedRule.isHidden = !card.isSelected
        dateLabel.text = card.frontDate
        dateLabel.accessibilityIdentifier = "\(prefix).date"
        amountLabel.text = card.expectedAmount
        amountLabel.accessibilityIdentifier = "\(prefix).expected"
        timeLabel.text = card.timeRange
        timeLabel.accessibilityIdentifier = "\(prefix).time"
        durationLabel.text = OverviewStrings.paidDuration(card.paidDuration)
        durationLabel.accessibilityIdentifier = "\(prefix).duration"

        endpoints.update(
            endpoints: card.endpoints,
            foreground: ShiftLedgerColors.textPrimary,
            identifierPrefix: "\(prefix).endpoints"
        )
        paidTime.update(label: PaycheckResultStrings.paidTime, value: card.paidDuration,
                        identifier: "\(prefix).detail.paidTime")
        exactAmount.update(label: OverviewStrings.exactContribution, value: card.exactExpectedAmount ?? "",
                           identifier: "\(prefix).detail.exactContribution")
        exactAmount.isHidden = card.exactExpectedAmount == nil
        let breakValue = card.unpaidBreak.map { duration in
            let interval = card.unpaidBreakTimeRange.map { "\($0) · " } ?? ""
            return "\(interval)\(duration)"
        }
        unpaidBreak.update(label: AddShiftStrings.unpaidBreak, value: breakValue ?? "",
                           identifier: "\(prefix).detail.break")
        unpaidBreak.isHidden = card.unpaidBreak == nil
        rate.update(label: PaycheckResultStrings.rate, value: card.appliedRate,
                    identifier: "\(prefix).detail.rate", accessibilitySizeValue: card.appliedRateAmount)
        payBasis.update(label: OverviewStrings.payBasis, value: card.payBasis,
                        identifier: "\(prefix).detail.payBasis")
        if card.isExpanded {
            accessibilityLabel = [card.accessibilityLabel,
                                  "\(PaycheckResultStrings.rate): \(card.appliedRate)",
                                  "\(OverviewStrings.payBasis): \(card.payBasis)"]
                .joined(separator: ", ")
        }
        if let exact = card.exactExpectedAmount {
            accessibilityLabel = [accessibilityLabel ?? "", "\(OverviewStrings.exactContribution): \(exact)"]
                .joined(separator: ", ")
        }
        details.isHidden = !card.isExpanded
        editButton.isHidden = !card.isExpanded
        editButton.accessibilityIdentifier = "\(prefix).edit"
        disclosure.image = UIImage(systemName: card.isExpanded ? "chevron.up" : "chevron.right")
        divider.isHidden = !showsDivider
        updateHeadingAxis()
        updateEditButtonForContentSizeCategory()
    }

    private func configureHierarchy() {
        content.axis = .vertical
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        heading.axis = .horizontal
        heading.alignment = .firstBaseline
        heading.spacing = 8
        amountLabel.textAlignment = .right
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        heading.addArrangedSubview(dateLabel)
        heading.addArrangedSubview(amountLabel)

        summary.axis = .horizontal
        summary.spacing = 12
        summary.addArrangedSubview(timeLabel)
        summary.addArrangedSubview(summarySpacer)
        durationSummary.spacing = 12
        durationSummary.alignment = .center
        durationSummary.addArrangedSubview(durationLabel)
        disclosure.tintColor = ShiftLedgerColors.textSecondary
        disclosure.contentMode = .scaleAspectFit
        disclosure.setContentHuggingPriority(.required, for: .horizontal)
        durationSummary.addArrangedSubview(disclosure)
        summary.addArrangedSubview(durationSummary)

        details.axis = .vertical
        details.spacing = 8
        details.isLayoutMarginsRelativeArrangement = true
        details.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 0)
        [endpoints, paidTime, unpaidBreak, rate, payBasis, exactAmount].forEach(details.addArrangedSubview)

        var editConfiguration = UIButton.Configuration.plain()
        editConfiguration.title = OverviewStrings.editShift
        editConfiguration.image = UIImage(systemName: "pencil")
        editConfiguration.imagePadding = 8
        editConfiguration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        editButton.configuration = editConfiguration
        editButton.contentHorizontalAlignment = .leading
        editButton.titleLabel?.adjustsFontForContentSizeCategory = true
        editButton.titleLabel?.numberOfLines = 0
        editButton.titleLabel?.lineBreakMode = .byWordWrapping
        editButton.addAction(UIAction { [weak self] _ in self?.onEditTapped?() }, for: .touchUpInside)
        editButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        addAction(UIAction { [weak self] _ in self?.onCardTapped?() }, for: .touchUpInside)

        [heading, summary, details, editButton].forEach(content.addArrangedSubview)
        content.setCustomSpacing(16, after: summary)
        content.setCustomSpacing(16, after: details)

        selectedRule.backgroundColor = ShiftLedgerColors.textPrimary
        selectedRule.isUserInteractionEnabled = false
        selectedRule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectedRule)
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            selectedRule.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectedRule.topAnchor.constraint(equalTo: topAnchor),
            selectedRule.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectedRule.widthAnchor.constraint(equalToConstant: 3),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        configureLabel(dateLabel, font: UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .monospacedSystemFont(ofSize: 16, weight: .semibold)), color: ShiftLedgerColors.textPrimary)
        configureLabel(amountLabel, font: UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 19, weight: .semibold)), color: ShiftLedgerColors.textPrimary)
        [timeLabel, durationLabel].forEach {
            configureLabel($0, font: UIFontMetrics(forTextStyle: .callout).scaledFont(
                for: .monospacedSystemFont(ofSize: 14, weight: .regular)
            ), color: ShiftLedgerColors.textSecondary)
        }
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
    }

    private func updateHeadingAxis() {
        let available = bounds.width - 32
        guard available > 0 else { return }
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || dateLabel.intrinsicContentSize.width + amountLabel.intrinsicContentSize.width + 36 > available
        let axis: NSLayoutConstraint.Axis = vertical ? .vertical : .horizontal
        if heading.axis != axis {
            heading.axis = axis
            heading.alignment = vertical ? .fill : .firstBaseline
            amountLabel.textAlignment = vertical ? .left : .right
        }
        let timeWidth = (timeLabel.text ?? "").size(withAttributes: [.font: timeLabel.font as Any]).width
        let durationWidth = (durationLabel.text ?? "").size(withAttributes: [.font: durationLabel.font as Any]).width
        let verticalSummary = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || timeWidth + durationWidth
                + disclosure.intrinsicContentSize.width + 36 > available
        summary.axis = verticalSummary ? .vertical : .horizontal
        summary.alignment = verticalSummary ? .fill : .center
        timeLabel.setContentCompressionResistancePriority(verticalSummary ? .defaultHigh : .required, for: .horizontal)
        summary.spacing = verticalSummary ? 8 : 12
        summarySpacer.isHidden = verticalSummary
    }

    private func updateEditButtonForContentSizeCategory() {
        var configuration = editButton.configuration
        configuration?.image = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? nil : UIImage(systemName: "pencil")
        editButton.configuration = configuration
        editButton.titleLabel?.numberOfLines = 0
        editButton.titleLabel?.lineBreakMode = .byWordWrapping
        editButton.titleLabel?.invalidateIntrinsicContentSize()
        editButton.invalidateIntrinsicContentSize()
        editButton.setNeedsLayout()
        content.setNeedsLayout()
        setNeedsLayout()
    }

    @objc private func editAccessibilityAction() -> Bool {
        onEditTapped?()
        return true
    }
}

/// One receipt field, kept separate so accessibility text sizes never wrap a colon away from its value.
final class OverviewReceiptFieldView: UIStackView {
    let label = UILabel()
    let value = UILabel()
    private var fullValue = ""
    private var accessibilitySizeValue: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        spacing = 8
        [label, value].forEach {
            $0.font = UIFontMetrics(forTextStyle: .callout).scaledFont(
                for: .monospacedSystemFont(ofSize: 14, weight: .regular))
            $0.adjustsFontForContentSizeCategory = true
            $0.numberOfLines = 0
            $0.lineBreakMode = .byWordWrapping
            $0.textColor = ShiftLedgerColors.textPrimary
            $0.isAccessibilityElement = false
            addArrangedSubview($0)
        }
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.updateAxis()
        }
        updateAxis()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { super.init(coder: coder) }

    override func layoutSubviews() {
        updateAxis()
        super.layoutSubviews()
    }

    func update(label title: String, value text: String, identifier: String, accessibilitySizeValue: String? = nil) {
        label.text = title
        fullValue = text
        self.accessibilitySizeValue = accessibilitySizeValue
        value.accessibilityIdentifier = identifier
        label.accessibilityIdentifier = identifier + ".label"
        accessibilityLabel = "\(title), \(text)"
        updateAxis()
    }

    private func updateAxis() {
        // At accessibility sizes the adjacent Pay basis field supplies the rate unit.
        // Keep the full rate in the accessible summary; never split an amount from a slash.
        value.text = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? accessibilitySizeValue ?? fullValue : fullValue
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || (bounds.width > 0 && label.intrinsicContentSize.width + value.intrinsicContentSize.width + 8 > bounds.width)
        axis = vertical ? .vertical : .horizontal
        alignment = vertical ? .fill : .firstBaseline
        value.textAlignment = vertical ? .left : .right
        value.setContentHuggingPriority(vertical ? .defaultHigh : .required, for: .horizontal)
    }
}
