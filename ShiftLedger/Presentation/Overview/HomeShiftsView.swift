import UIKit

final class HomeShiftsView: UIStackView {
    var onShowSavedShifts: (() -> Void)?
    var onEditShift: ((UUID) -> Void)?

    private let saved = HomeShiftButton(symbol: "briefcase")
    private let recent = UIStackView()
    private let savedTitle = String(localized: "home.savedShifts")

    init() {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 12
        let heading = UILabel()
        heading.text = String(localized: "home.latestShifts")
        heading.font = ShiftLedgerTypography.headline
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        heading.textColor = ShiftLedgerColors.textPrimary
        heading.accessibilityTraits.insert(.header)
        recent.axis = .vertical
        recent.spacing = 8
        addArrangedSubview(saved)
        addArrangedSubview(heading)
        addArrangedSubview(recent)
        setCustomSpacing(20, after: saved)

        saved.accessibilityIdentifier = "home.savedShifts"
        saved.addAction(UIAction { [weak self] _ in self?.onShowSavedShifts?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { super.init(coder: coder) }

    func render(count: Int, recent cards: [OverviewView.ShiftCard]) {
        let countText = count.formatted()
        saved.update(title: savedTitle, value: countText, details: [OverviewStrings.historyScope])
        saved.accessibilityLabel = savedTitle
        saved.accessibilityValue = countText
        saved.accessibilityHint = OverviewStrings.historyScope

        recent.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if cards.isEmpty {
            let empty = UILabel()
            empty.text = OverviewStrings.noSavedShifts
            empty.accessibilityIdentifier = "home.latestShifts.empty"
            empty.font = ShiftLedgerTypography.callout
            empty.adjustsFontForContentSizeCategory = true
            empty.numberOfLines = 0
            empty.textColor = ShiftLedgerColors.textSecondary
            recent.addArrangedSubview(empty)
        }
        for card in cards {
            let row = HomeShiftButton()
            let endpoints = card.endpoints
            let details: [String]
            if let endDate = endpoints.endDate {
                details = [endpoints.startTime, "→ \(endDate) · \(endpoints.endTime)"]
            } else {
                details = [card.timeRange]
            }
            var metadata = ["\(card.paidDuration) · \(PaycheckResultStrings.paidTime)"]
            if let unpaidBreak = card.unpaidBreak {
                metadata.append("\(AddShiftStrings.unpaidBreak): \(unpaidBreak)")
            }
            let title = endpoints.startDate ?? card.frontDate
            row.update(title: title, value: card.expectedAmount, details: details + metadata)
            row.accessibilityIdentifier = "home.recentShift.\(card.id.uuidString)"
            let amount = "\(PaycheckResultStrings.shiftExpected): \(card.expectedAmount)"
            let spokenDetails = details.map { $0.hasPrefix("→ ") ? String($0.dropFirst(2)) : $0 }
            row.accessibilityLabel = ([title] + spokenDetails + [amount] + metadata).joined(separator: ", ")
            row.addAction(UIAction { [weak self] _ in self?.onEditShift?(card.id) }, for: .touchUpInside)
            recent.addArrangedSubview(row)
        }
    }
}

private final class HomeShiftButton: UIButton {
    private let titleText = UILabel()
    private let valueText = UILabel()
    private let headline = UIStackView()
    private let textStack = UIStackView()

    init(symbol: String? = nil) {
        super.init(frame: .zero)
        backgroundColor = ShiftLedgerColors.surfacePrimary
        layer.cornerCurve = .continuous
        layer.cornerRadius = 16
        isAccessibilityElement = true
        accessibilityTraits = .button

        configure(titleText, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        configure(valueText, font: ShiftLedgerTypography.headline, color: ShiftLedgerColors.textPrimary)
        valueText.textAlignment = .right
        headline.spacing = 8
        headline.alignment = .firstBaseline
        headline.addArrangedSubview(titleText)
        headline.addArrangedSubview(valueText)
        valueText.setContentHuggingPriority(.required, for: .horizontal)

        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.addArrangedSubview(headline)
        let row = UIStackView()
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.accessibilityElementsHidden = true
        if let symbol {
            row.addArrangedSubview(icon(symbol, size: 24, color: ShiftLedgerColors.accentPrimary))
        }
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(icon("chevron.forward", size: 12, color: ShiftLedgerColors.textSecondary))
        addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: Self, _) in
            button.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let preferredWidth = titleText.intrinsicContentSize.width
            + valueText.intrinsicContentSize.width + headline.spacing
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || (textStack.bounds.width > 0 && preferredWidth > textStack.bounds.width)
        let axis: NSLayoutConstraint.Axis = vertical ? .vertical : .horizontal
        if headline.axis != axis {
            headline.axis = axis
            headline.alignment = vertical ? .fill : .firstBaseline
        }
    }

    func update(title: String, value: String, details: [String]) {
        titleText.text = title
        valueText.text = value
        textStack.arrangedSubviews.dropFirst().forEach { $0.removeFromSuperview() }
        for detail in details {
            let label = UILabel()
            configure(label, font: ShiftLedgerTypography.caption, color: ShiftLedgerColors.textSecondary)
            label.text = detail
            textStack.addArrangedSubview(label)
        }
        setNeedsLayout()
    }

    private func configure(_ label: UILabel, font: UIFont, color: UIColor) {
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
    }

    private func icon(_ symbol: String, size: CGFloat, color: UIColor) -> UIImageView {
        let image = UIImageView(image: UIImage(systemName: symbol))
        image.tintColor = color
        image.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: size),
            image.heightAnchor.constraint(equalToConstant: size)
        ])
        return image
    }
}
