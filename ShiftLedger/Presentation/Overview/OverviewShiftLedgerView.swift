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
        accessibilityElements = cards.flatMap { card -> [UIView] in
            guard let row = rowViews[card.id] else { return [] }
            return row.editButton.isAccessibilityElement ? [row, row.editButton] : [row]
        }
    }

    func rowView(with id: UUID) -> UIView? { rowViews[id] }
}

final class OverviewShiftLedgerRowView: UIControl {
    private let content = UIStackView()
    private let heading = UIStackView()
    private let dateLabel = UILabel()
    private let amountLabel = UILabel()
    private let timeLabel = UILabel()
    private let endpointStack = UIStackView()
    private let startTimeLabel = UILabel()
    private let endDateLabel = UILabel()
    private let endTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let summary = UIStackView()
    private let summarySpacer = UIView()
    private let durationSummary = UIStackView()
    private let details = UIStackView()
    private let unpaidBreak = OverviewReceiptFieldView()
    private let rate = OverviewReceiptFieldView()
    fileprivate let editButton = UIButton(type: .system)
    private let editChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let disclosure = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let divider = UIView()
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
        updateOffsetFont(for: timeLabel)
        if !endpointStack.isHidden {
            updateOffsetFont(for: startTimeLabel)
            updateOffsetFont(for: endTimeLabel)
        }
    }

    private func updateOffsetFont(for timeLabel: UILabel) {
        let base = UIFontMetrics(forTextStyle: .callout).scaledFont(
            for: .monospacedSystemFont(ofSize: 14, weight: .regular), compatibleWith: traitCollection)
        guard let text = timeLabel.text else { return }
        let hasOffset = text.contains("GMT") || text.contains("UTC")
        if timeLabel.adjustsFontForContentSizeCategory == hasOffset {
            timeLabel.adjustsFontForContentSizeCategory = !hasOffset
        }
        let lineBreak: NSLineBreakMode = .byWordWrapping
        if timeLabel.lineBreakMode != lineBreak { timeLabel.lineBreakMode = lineBreak }
        guard hasOffset else {
            if timeLabel.font != base { timeLabel.font = base }
            return
        }
        let scale = max(traitCollection.displayScale, 1)
        let width = floor(timeLabel.bounds.width * scale) / scale - 1 / scale
        guard width > 0 else { return }
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let measure = UILabel()
        func fits(_ size: CGFloat) -> Bool {
            measure.font = base.withSize(size)
            return tokens.allSatisfy { token in
                measure.text = token
                return ceil(measure.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude)).width * scale) / scale <= width
            }
        }
        var lower = min(17, base.pointSize)
        var upper = base.pointSize
        guard fits(lower) else { return }
        if !fits(upper) {
            for _ in 0..<14 {
                let middle = (lower + upper) / 2
                if fits(middle) { lower = middle } else { upper = middle }
            }
        } else { lower = upper }
        let fitted = base.withSize(lower)
        if timeLabel.font != fitted { timeLabel.font = fitted }
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
        let canEdit = card.isExpanded && onEditTapped != nil
        accessibilityCustomActions = canEdit
            ? [UIAccessibilityCustomAction(
                name: OverviewStrings.editShift,
                target: self,
                selector: #selector(editAccessibilityAction)
            )]
            : nil
        isAccessibilityElement = true

        backgroundColor = card.isSelected ? ShiftLedgerColors.surfaceSelected : .clear
        selectedRule.isHidden = !card.isSelected
        let multiDay = card.endpoints.startDate != nil && card.endpoints.endDate != nil
        dateLabel.text = multiDay ? card.endpoints.startDate : card.frontDate
        dateLabel.accessibilityIdentifier = "\(prefix).date"
        amountLabel.text = card.expectedAmount
        amountLabel.accessibilityIdentifier = "\(prefix).expected"
        startTimeLabel.text = multiDay ? card.endpoints.startTime : nil
        startTimeLabel.accessibilityIdentifier = "\(prefix).startTime"
        endpointStack.isHidden = !multiDay
        endpointStack.accessibilityIdentifier = multiDay ? "\(prefix).time" : nil
        endpointStack.accessibilityLabel = multiDay
            ? [card.endpoints.startDate, card.endpoints.startTime,
               card.endpoints.endDate, card.endpoints.endTime].compactMap { $0 }.joined(separator: " ")
            : nil
        endDateLabel.text = card.endpoints.endDate.map { "→ \($0)" }
        endDateLabel.accessibilityIdentifier = "\(prefix).endDate"
        endTimeLabel.text = multiDay ? card.endpoints.endTime : nil
        endTimeLabel.accessibilityIdentifier = "\(prefix).endTime"
        timeLabel.isHidden = multiDay
        timeLabel.text = multiDay ? nil : card.timeRange
        timeLabel.accessibilityIdentifier = multiDay ? nil : "\(prefix).time"
        durationLabel.text = OverviewStrings.paidDuration(card.paidDuration)
        durationLabel.accessibilityIdentifier = "\(prefix).duration"

        let breakValue = card.unpaidBreak.map { duration in
            let interval = card.unpaidBreakTimeRange.map { "\($0) · " } ?? ""
            return "\(interval)\(duration)"
        }
        let wrappedBreakValue = card.unpaidBreak.flatMap { duration in
            card.unpaidBreakTimeRange.map { "\($0)\n\(duration)" }
        }
        unpaidBreak.update(label: OverviewStrings.unpaidBreakDetail, value: breakValue ?? "",
                           wrappedValue: wrappedBreakValue,
                           identifier: "\(prefix).detail.break")
        unpaidBreak.isHidden = card.unpaidBreak == nil
        rate.update(label: PaycheckResultStrings.rate,
                    value: card.appliedRate,
                    wrappedValue: card.appliedRate.replacingOccurrences(of: " / ", with: "\n/\u{00a0}"),
                    identifier: "\(prefix).detail.rate")
        if card.isExpanded {
            accessibilityLabel = [card.accessibilityLabel,
                                  "\(PaycheckResultStrings.rate): \(card.appliedRate)"]
                .joined(separator: ", ")
        }
        if let exact = card.exactExpectedAmount {
            accessibilityLabel = [accessibilityLabel ?? "", "\(OverviewStrings.exactContribution): \(exact)"]
                .joined(separator: ", ")
        }
        details.isHidden = !card.isExpanded
        editButton.isHidden = !canEdit
        editButton.isAccessibilityElement = canEdit
        editButton.accessibilityIdentifier = "\(prefix).edit"
        editChevron.accessibilityIdentifier = "\(prefix).edit.chevron"
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
        summary.alignment = .center
        summary.spacing = 8
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
        [unpaidBreak, rate].forEach(details.addArrangedSubview)

        var editConfiguration = UIButton.Configuration.tinted()
        editConfiguration.title = OverviewStrings.editShift
        editConfiguration.image = UIImage(systemName: "pencil")
        editConfiguration.imagePadding = 8
        editConfiguration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        editConfiguration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        editConfiguration.background.backgroundColor = ShiftLedgerColors.accentPrimary.withAlphaComponent(0.12)
        editConfiguration.background.backgroundColorTransformer = nil
        editConfiguration.cornerStyle = .fixed
        editConfiguration.background.cornerRadius = 12
        editConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 40)
        editConfiguration.titleLineBreakMode = .byWordWrapping
        editButton.configuration = editConfiguration
        editButton.contentHorizontalAlignment = .leading
        editButton.isAccessibilityElement = false
        editButton.accessibilityTraits.insert(.button)
        editButton.titleLabel?.adjustsFontForContentSizeCategory = true
        editButton.titleLabel?.numberOfLines = 0
        editButton.titleLabel?.lineBreakMode = .byWordWrapping
        editButton.addAction(UIAction { [weak self] _ in self?.onEditTapped?() }, for: .touchUpInside)
        editButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        editChevron.tintColor = ShiftLedgerColors.accentPrimary
        editChevron.contentMode = .scaleAspectFit
        editChevron.isUserInteractionEnabled = false
        editChevron.isAccessibilityElement = false
        editChevron.translatesAutoresizingMaskIntoConstraints = false
        editButton.addSubview(editChevron)
        NSLayoutConstraint.activate([
            editChevron.trailingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: -16),
            editChevron.centerYAnchor.constraint(equalTo: editButton.centerYAnchor),
            editChevron.widthAnchor.constraint(equalToConstant: 12),
            editChevron.heightAnchor.constraint(equalToConstant: 16)
        ])
        addAction(UIAction { [weak self] _ in self?.onCardTapped?() }, for: .touchUpInside)

        endpointStack.axis = .vertical
        endpointStack.spacing = 8
        [startTimeLabel, endDateLabel, endTimeLabel].forEach(endpointStack.addArrangedSubview)
        [heading, endpointStack, summary, details, editButton].forEach(content.addArrangedSubview)
        content.setCustomSpacing(12, after: endpointStack)
        content.setCustomSpacing(20, after: summary)
        content.setCustomSpacing(20, after: details)

        selectedRule.backgroundColor = ShiftLedgerColors.textPrimary
        selectedRule.isUserInteractionEnabled = false
        selectedRule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectedRule)
        divider.backgroundColor = ShiftLedgerColors.separator
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
        [timeLabel, startTimeLabel, endDateLabel, endTimeLabel, durationLabel].forEach {
            configureLabel($0, font: UIFontMetrics(forTextStyle: .callout).scaledFont(
                for: .monospacedSystemFont(ofSize: 14, weight: .regular)
            ), color: ShiftLedgerColors.textSecondary)
        }
    }

    private func configureLabel(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.lineBreakStrategy = []
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
    }

    private func updateHeadingAxis() {
        let available = bounds.width - 32
        guard available > 0 else { return }
        details.layoutMargins = UIEdgeInsets(top: 8,
            left: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 12,
            bottom: 8, right: 0)
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || singleLineWidth(of: dateLabel) + singleLineWidth(of: amountLabel)
                + heading.spacing > available
        let axis: NSLayoutConstraint.Axis = vertical ? .vertical : .horizontal
        if heading.axis != axis {
            heading.axis = axis
            heading.alignment = vertical ? .fill : .firstBaseline
            amountLabel.textAlignment = .right
        }
        let verticalSummary = !endpointStack.isHidden
            || traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || singleLineWidth(of: timeLabel) + singleLineWidth(of: durationLabel)
                + disclosure.intrinsicContentSize.width + 28 > available
        let summaryAxis: NSLayoutConstraint.Axis = verticalSummary ? .vertical : .horizontal
        if summary.axis != summaryAxis {
            summary.axis = summaryAxis
            summary.alignment = verticalSummary ? .fill : .center
            summarySpacer.isHidden = verticalSummary
            summary.spacing = verticalSummary ? 12 : 8
        }
    }

    private func singleLineWidth(of label: UILabel) -> CGFloat {
        guard let text = label.text, let font = label.font else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func updateEditButtonForContentSizeCategory() {
        let accessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        var configuration = editButton.configuration
        configuration?.image = accessibilitySize ? nil : UIImage(systemName: "pencil")
        configuration?.contentInsets.trailing = accessibilitySize ? 16 : 40
        let headline = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traitCollection)
        let font = UIFont.systemFont(ofSize: headline.pointSize, weight: .bold)
        configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        editButton.configuration = configuration
        editChevron.isHidden = accessibilitySize
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
    private var wrappedValue: String?

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

    func update(label title: String, value text: String, wrappedValue: String? = nil, identifier: String) {
        label.text = title
        fullValue = text
        self.wrappedValue = wrappedValue
        value.text = text
        value.accessibilityIdentifier = identifier
        label.accessibilityIdentifier = identifier + ".label"
        accessibilityLabel = "\(title), \(text)"
        updateAxis()
    }

    private func updateAxis() {
        // Keep the complete rate unit together on a deliberate second line when needed.
        // Measure source strings, not intrinsic sizes already affected by wrapping.
        let labelWidth = ceil((label.text ?? "").size(withAttributes: [.font: label.font as Any]).width)
        let valueWidth = ceil(fullValue.size(withAttributes: [.font: value.font as Any]).width)
        let displayedValue = bounds.width > 0 && valueWidth > bounds.width ? wrappedValue ?? fullValue : fullValue
        if value.text != displayedValue { value.text = displayedValue }
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || (bounds.width > 0 && labelWidth + valueWidth + spacing > bounds.width)
        let targetAxis: NSLayoutConstraint.Axis = vertical ? .vertical : .horizontal
        if axis != targetAxis { axis = targetAxis }
        alignment = vertical ? .fill : .firstBaseline
        value.textAlignment = vertical ? .left : .right
        value.setContentHuggingPriority(vertical ? .defaultHigh : .required, for: .horizontal)
    }
}
