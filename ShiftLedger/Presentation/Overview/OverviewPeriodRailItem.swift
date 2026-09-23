import UIKit

final class OverviewPeriodRailItem: UIControl {
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
