import UIKit

final class JobSetupReviewView: UIView {
    private enum Layout {
        static let contentInset: CGFloat = 24
        static let progressToQuestion: CGFloat = 32
        static let questionToSubtitle: CGFloat = 12
        static let subtitleToRows: CGFloat = 28
        static let rowHeight: CGFloat = 44
    }

    var onBackTapped: (() -> Void)?
    var onTimeZoneTapped: (() -> Void)?
    var onStartTapped: (() -> Void)?

    private let scaffold = JobSetupScaffoldView(
        brandText: nil,
        stepIndicator: JobSetupReviewStrings.stepIndicator,
        stepAccessibilityLabel: JobSetupReviewStrings.stepIndicatorAccessibilityLabel,
        activeStep: 3,
        backAccessibilityLabel: JobSetupReviewStrings.back,
        continueTitle: JobSetupReviewStrings.start
    )
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let rowsStack = UIStackView()
    private let payRow = JobSetupReviewRow()
    private let amountRow = JobSetupReviewRow()
    private let currencyRow = JobSetupReviewRow()
    private let payPeriodRow = JobSetupReviewRow()
    private let periodStartRow = JobSetupReviewRow()
    private let timeZoneRow = JobSetupReviewRow(showsChevron: true)

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureAppearance()
        configureSubviews()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(
        basePayLabel: String?,
        amountText: String?,
        currencyCode: String,
        payPeriodLabel: String?,
        periodStartText: String?,
        timeZoneText: String,
        showsPeriodStart: Bool,
        canFinish: Bool
    ) {
        payRow.render(label: JobSetupReviewStrings.payLabel, value: basePayLabel ?? "")
        amountRow.render(label: JobSetupReviewStrings.amountLabel, value: amountText ?? "")
        currencyRow.render(label: JobSetupReviewStrings.currencyLabel, value: currencyCode)
        payPeriodRow.render(label: JobSetupReviewStrings.payPeriodLabel, value: payPeriodLabel ?? "")
        periodStartRow.render(label: JobSetupReviewStrings.periodStartLabel, value: periodStartText ?? "")
        timeZoneRow.render(label: JobSetupReviewStrings.timeZoneLabel, value: timeZoneText)
        periodStartRow.isHidden = !showsPeriodStart
        scaffold.setContinueEnabled(canFinish)
    }

    func setStartEnabled(_ enabled: Bool) {
        scaffold.setContinueEnabled(enabled)
    }

    private func configureAppearance() {
        questionLabel.text = JobSetupReviewStrings.title
        questionLabel.font = ShiftLedgerTypography.onboardingQuestion
        questionLabel.textColor = ShiftLedgerColors.textPrimary
        questionLabel.numberOfLines = 0
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.accessibilityTraits = .header

        subtitleLabel.text = JobSetupReviewStrings.subtitle
        subtitleLabel.font = ShiftLedgerTypography.body
        subtitleLabel.textColor = ShiftLedgerColors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        [payRow, amountRow, currencyRow, payPeriodRow, periodStartRow, timeZoneRow]
            .forEach(rowsStack.addArrangedSubview)
    }

    private func configureSubviews() {
        [scaffold, questionLabel, subtitleLabel, rowsStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scaffold)
        [questionLabel, subtitleLabel, rowsStack].forEach(scaffold.contentView.addSubview)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scaffold.topAnchor.constraint(equalTo: topAnchor),
            scaffold.leadingAnchor.constraint(equalTo: leadingAnchor),
            scaffold.trailingAnchor.constraint(equalTo: trailingAnchor),
            scaffold.bottomAnchor.constraint(equalTo: bottomAnchor),

            questionLabel.topAnchor.constraint(equalTo: scaffold.progressBottomAnchor, constant: Layout.progressToQuestion),
            questionLabel.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: Layout.contentInset),
            questionLabel.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -Layout.contentInset),

            subtitleLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: Layout.questionToSubtitle),
            subtitleLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),

            rowsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Layout.subtitleToRows),
            rowsStack.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: scaffold.contentView.bottomAnchor)
        ])
    }

    private func configureInteractions() {
        scaffold.onBackTapped = { [weak self] in self?.onBackTapped?() }
        scaffold.onContinueTapped = { [weak self] in self?.onStartTapped?() }
        timeZoneRow.addAction(UIAction { [weak self] _ in self?.onTimeZoneTapped?() }, for: .touchUpInside)
    }
}

private final class JobSetupReviewRow: UIControl {
    private let labelLabel = UILabel()
    private let valueLabel = UILabel()
    private let separator = UIView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let showsChevron: Bool

    init(showsChevron: Bool = false) {
        self.showsChevron = showsChevron
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        labelLabel.font = ShiftLedgerTypography.body
        labelLabel.textColor = ShiftLedgerColors.textSecondary
        labelLabel.adjustsFontForContentSizeCategory = true
        labelLabel.numberOfLines = 0

        valueLabel.font = ShiftLedgerTypography.callout
        valueLabel.textColor = ShiftLedgerColors.textPrimary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right

        chevron.tintColor = ShiftLedgerColors.textTertiary
        chevron.isHidden = !showsChevron
        chevron.isAccessibilityElement = false
        chevron.contentMode = .scaleAspectFit
        separator.backgroundColor = ShiftLedgerColors.separator

        [labelLabel, valueLabel, chevron, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        isAccessibilityElement = true
        accessibilityTraits = showsChevron ? .button : []
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        NSLayoutConstraint.activate([
            labelLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            labelLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: labelLabel.trailingAnchor, constant: 12),
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            valueLabel.trailingAnchor.constraint(equalTo: showsChevron ? chevron.leadingAnchor : trailingAnchor, constant: showsChevron ? -12 : 0),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 9),
            chevron.heightAnchor.constraint(equalToConstant: 13),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(label: String, value: String) {
        labelLabel.text = label
        valueLabel.text = value
        accessibilityLabel = "\(label), \(value)"
    }
}
