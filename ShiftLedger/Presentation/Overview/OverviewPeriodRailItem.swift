import UIKit

final class OverviewPeriodRailItem: UIControl {
    let period: PayCalculationPeriod

    init(item: OverviewView.PeriodItem) {
        period = item.period
        super.init(frame: .zero)
        backgroundColor = .clear
        accessibilityLabel = item.title
        accessibilityTraits = item.isSelected ? [.button, .selected] : .button

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = UIFontMetrics(forTextStyle: .callout).scaledFont(
            for: .monospacedSystemFont(ofSize: 16, weight: item.isSelected ? .semibold : .regular)
        )
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
