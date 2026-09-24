import UIKit

final class OverviewShiftCardView: UIControl {
    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 12
        static let headerTopInset: CGFloat = 2
        static let headerToMetadataSpacing: CGFloat = 20
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
        if var editConfiguration = editButton.configuration {
            editConfiguration.baseForegroundColor = foreground
            editButton.configuration = editConfiguration
        }

        headerStack.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).header"
        headerStack.isHidden = isDeckFront
        frontContentStack.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).frontContent"
        frontContentStack.isHidden = isDeckFront == false

        coveredDateLabel.text = card.frontDate
        configureLabel(coveredDateLabel, font: ShiftLedgerTypography.headline, color: foreground)
        coveredDateLabel.numberOfLines = 1
        coveredDateLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).date"
        coveredDateLabel.isAccessibilityElement = false
        coveredDateLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        timeRangeLabel.text = card.timeRange
        configureLabel(timeRangeLabel, font: ShiftLedgerTypography.caption, color: foreground)
        timeRangeLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).time"
        timeRangeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        expectedAmountLabel.text = card.expectedAmount
        configureLabel(expectedAmountLabel, font: ShiftLedgerTypography.basePayAmount, color: foreground)
        expectedAmountLabel.textAlignment = .right
        expectedAmountLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).expected"
        expectedAmountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        frontDateLabel.text = card.frontDate
        configureLabel(frontDateLabel, font: ShiftLedgerTypography.headline, color: foreground)
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
        configureLabel(paidDurationLabel, font: ShiftLedgerTypography.callout, color: foreground)
        paidDurationLabel.accessibilityIdentifier = "overview.shift.\(card.id.uuidString).duration"

        unpaidBreakLabel.text = card.unpaidBreak.map { "\(AddShiftStrings.unpaidBreak): \($0)" }
        configureLabel(unpaidBreakLabel, font: ShiftLedgerTypography.caption, color: foreground)
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
            configureLabel($0, font: ShiftLedgerTypography.caption, color: foreground)
        }
        [paidTimeDetailLabel, unpaidBreakDetailLabel, rateDetailLabel, payBasisDetailLabel].forEach {
            configureLabel($0, font: ShiftLedgerTypography.callout, color: foreground)
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
            top: Layout.headerTopInset,
            leading: 0,
            bottom: 0,
            trailing: 0
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
            top: Layout.headerTopInset,
            leading: 0,
            bottom: 4,
            trailing: 0
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
