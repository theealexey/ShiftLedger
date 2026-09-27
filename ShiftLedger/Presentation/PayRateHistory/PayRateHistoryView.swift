import UIKit

final class PayRateHistoryView: UIView {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let workTypeLabel = UILabel()
    private let rowsStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func render(workTypeName: String, rows: [PayRateHistoryViewModel.Row]) {
        workTypeLabel.text = workTypeName
        workTypeLabel.accessibilityLabel = workTypeName
        rowsStack.arrangedSubviews.forEach { view in
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, row) in rows.enumerated() {
            let rowView = PayRateHistoryRowView(row: row)
            rowView.showsSeparator = index < rows.count - 1
            rowsStack.addArrangedSubview(rowView)
        }
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "payRateHistory.screen"
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "payRateHistory.list"
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 0
        workTypeLabel.font = ShiftLedgerTypography.headline
        workTypeLabel.textColor = ShiftLedgerColors.textPrimary
        workTypeLabel.numberOfLines = 0
        workTypeLabel.adjustsFontForContentSizeCategory = true
        workTypeLabel.accessibilityIdentifier = "payRateHistory.workType"
        workTypeLabel.accessibilityTraits.insert(.header)
        rowsStack.axis = .vertical
        rowsStack.alignment = .fill
        rowsStack.spacing = 0
    }

    private func configureHierarchy() {
        addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.addArrangedSubview(workTypeLabel)
        contentStack.addArrangedSubview(rowsStack)
        contentStack.setCustomSpacing(16, after: workTypeLabel)
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }
}

private final class PayRateHistoryRowView: UIView {
    private let labelsStack = UIStackView()
    private let amountLabel = UILabel()
    private let effectiveDateLabel = UILabel()
    private let separator = UIView()

    var showsSeparator: Bool {
        get { separator.isHidden == false }
        set { separator.isHidden = !newValue }
    }

    init(row: PayRateHistoryViewModel.Row) {
        super.init(frame: .zero)
        configure(row: row)
        configureHierarchy()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func configure(row: PayRateHistoryViewModel.Row) {
        accessibilityIdentifier = "payRateHistory.row.\(row.id.uuidString)"
        isAccessibilityElement = true
        accessibilityLabel = row.accessibilityLabel
        accessibilityTraits = .staticText

        labelsStack.axis = .vertical
        labelsStack.alignment = .fill
        labelsStack.spacing = 4
        amountLabel.text = row.amountAndBasis
        amountLabel.font = ShiftLedgerTypography.basePayAmount
        amountLabel.textColor = ShiftLedgerColors.textPrimary
        amountLabel.numberOfLines = 0
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.isAccessibilityElement = false
        amountLabel.accessibilityIdentifier = "payRateHistory.row.\(row.id.uuidString).amount"
        effectiveDateLabel.text = row.effectiveDateDescription
        effectiveDateLabel.font = ShiftLedgerTypography.callout
        effectiveDateLabel.textColor = ShiftLedgerColors.textSecondary
        effectiveDateLabel.numberOfLines = 0
        effectiveDateLabel.adjustsFontForContentSizeCategory = true
        effectiveDateLabel.isAccessibilityElement = false
        effectiveDateLabel.accessibilityIdentifier = "payRateHistory.row.\(row.id.uuidString).effectiveDate"
        separator.backgroundColor = ShiftLedgerColors.separator
        separator.isAccessibilityElement = false
    }

    private func configureHierarchy() {
        addSubview(labelsStack)
        addSubview(separator)
        labelsStack.addArrangedSubview(amountLabel)
        labelsStack.addArrangedSubview(effectiveDateLabel)
    }

    private func configureLayout() {
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            labelsStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            labelsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
}
