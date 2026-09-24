import UIKit

final class OverviewShiftEndpointsView: UIView {
    private let startCaption = UILabel()
    private let startTime = UILabel()
    private let startDate = UILabel()
    private let endCaption = UILabel()
    private let endTime = UILabel()
    private let endDate = UILabel()
    private let startGroup = UIStackView()
    private let endGroup = UIStackView()
    private let columns = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        startCaption.text = AddShiftStrings.start
        endCaption.text = AddShiftStrings.end
        for (group, labels) in [
            (startGroup, [startCaption, startTime, startDate]),
            (endGroup, [endCaption, endTime, endDate])
        ] {
            group.axis = .vertical
            group.spacing = 6
            labels.forEach {
                $0.numberOfLines = 0
                $0.adjustsFontForContentSizeCategory = true
                $0.isAccessibilityElement = false
                group.addArrangedSubview($0)
            }
        }
        columns.spacing = 24
        columns.translatesAutoresizingMaskIntoConstraints = false
        [startGroup, endGroup].forEach(columns.addArrangedSubview)
        addSubview(columns)
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: topAnchor),
            columns.leadingAnchor.constraint(equalTo: leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
            (view: OverviewShiftEndpointsView, _: UITraitCollection) in
            view.updateLayout()
        }
        updateLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    func update(
        endpoints: OverviewFormatting.ShiftEndpoints,
        foreground: UIColor,
        identifierPrefix: String
    ) {
        accessibilityIdentifier = identifierPrefix
        for (label, text, suffix) in [
            (startTime, Optional(endpoints.startTime), "start"),
            (endTime, Optional(endpoints.endTime), "end"),
            (startDate, endpoints.startDate, "startDate"),
            (endDate, endpoints.endDate, "endDate")
        ] {
            label.text = text
            label.isHidden = text == nil
            label.accessibilityIdentifier = "\(identifierPrefix).\(suffix)"
        }
        [startTime, endTime].forEach { $0.textColor = foreground }
        [startCaption, endCaption, startDate, endDate].forEach {
            $0.textColor = foreground
        }
        updateLayout()
    }

    private func updateLayout() {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        [startTime, endTime].forEach {
            $0.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: font, compatibleWith: traitCollection)
        }
        [startCaption, endCaption, startDate, endDate].forEach {
            $0.font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traitCollection)
        }
        let requiredColumnWidth = max(
            startGroup.arrangedSubviews.map { $0.intrinsicContentSize.width }.max() ?? 0,
            endGroup.arrangedSubviews.map { $0.intrinsicContentSize.width }.max() ?? 0
        )
        let vertical = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            || (bounds.width > 0 && requiredColumnWidth * 2 + columns.spacing > bounds.width)
        columns.axis = vertical ? .vertical : .horizontal
        columns.distribution = vertical ? .fill : .fillEqually
        startGroup.alignment = .leading
        endGroup.alignment = vertical ? .leading : .trailing
        [endCaption, endTime, endDate].forEach { $0.textAlignment = vertical ? .left : .right }
    }
}
