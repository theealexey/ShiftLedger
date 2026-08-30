import UIKit

final class PayPeriodSetupView: UIView {
    var onBackTapped: (() -> Void)?
    var onCycleKindSelected: ((PayCalculationCycleKind) -> Void)?
    var onAnchorTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    private let scaffold = JobSetupScaffoldView(
        brandText: nil,
        stepIndicator: PayPeriodSetupStrings.stepIndicator,
        stepAccessibilityLabel: PayPeriodSetupStrings.stepIndicatorAccessibilityLabel,
        activeStep: 2,
        backAccessibilityLabel: PayPeriodSetupStrings.back
    )
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsStack = UIStackView()
    private let anchorSection = UIStackView()
    private let anchorTitleLabel = UILabel()
    private let anchorSubtitleLabel = UILabel()
    private let anchorRow = TappableControl()
    private let anchorValueLabel = UILabel()
    private let anchorChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let anchorSeparator = UIView()
    private var continueTopAfterAnchorConstraint: NSLayoutConstraint?
    private var continueTopAfterOptionsConstraint: NSLayoutConstraint?

    private let weeklyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.weekly)
    private let biweeklyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.biweekly)
    private let calendarMonthlyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.calendarMonthly)
    private let perShiftControl = FrequencyOptionControl(title: PayPeriodSetupStrings.perShift)

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

    func render(cycleKind: PayCalculationCycleKind?, anchorDateText: String?, canContinue: Bool) {
        perShiftControl.isSelected = cycleKind == .perShift
        weeklyControl.isSelected = cycleKind == .weekly
        biweeklyControl.isSelected = cycleKind == .biweekly
        calendarMonthlyControl.isSelected = cycleKind == .calendarMonthly

        let showsAnchor = cycleKind == .weekly || cycleKind == .biweekly
        anchorSection.isHidden = !showsAnchor
        anchorTitleLabel.isHidden = !showsAnchor
        anchorSubtitleLabel.isHidden = !showsAnchor
        anchorRow.isHidden = !showsAnchor
        anchorSeparator.isHidden = !showsAnchor
        anchorValueLabel.text = anchorDateText ?? PayPeriodSetupStrings.anchorChoose
        anchorRow.accessibilityValue = anchorDateText ?? PayPeriodSetupStrings.anchorChoose
        continueTopAfterAnchorConstraint?.isActive = showsAnchor
        continueTopAfterOptionsConstraint?.isActive = !showsAnchor
        scaffold.setContinueEnabled(canContinue)
    }

    private func configureAppearance() {
        questionLabel.text = PayPeriodSetupStrings.title
        questionLabel.font = ShiftLedgerTypography.onboardingQuestion
        questionLabel.textColor = ShiftLedgerColors.textPrimary
        questionLabel.numberOfLines = 0
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.accessibilityTraits = .header

        subtitleLabel.text = PayPeriodSetupStrings.subtitle
        subtitleLabel.font = ShiftLedgerTypography.body
        subtitleLabel.textColor = ShiftLedgerColors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        optionsStack.axis = .vertical
        optionsStack.spacing = 0
        optionsStack.addArrangedSubview(perShiftControl)
        optionsStack.addArrangedSubview(weeklyControl)
        optionsStack.addArrangedSubview(biweeklyControl)
        optionsStack.addArrangedSubview(calendarMonthlyControl)

        anchorSection.axis = .vertical
        anchorSection.spacing = 0
        anchorSection.addArrangedSubview(anchorTitleLabel)
        anchorSection.addArrangedSubview(anchorSubtitleLabel)
        anchorSection.addArrangedSubview(anchorRow)
        anchorSection.addArrangedSubview(anchorSeparator)
        anchorSection.setCustomSpacing(8, after: anchorTitleLabel)
        anchorSection.setCustomSpacing(16, after: anchorSubtitleLabel)

        anchorTitleLabel.text = PayPeriodSetupStrings.anchorTitle
        anchorTitleLabel.font = ShiftLedgerTypography.headline
        anchorTitleLabel.textColor = ShiftLedgerColors.textPrimary
        anchorTitleLabel.numberOfLines = 0
        anchorTitleLabel.adjustsFontForContentSizeCategory = true

        anchorSubtitleLabel.text = PayPeriodSetupStrings.anchorSubtitle
        anchorSubtitleLabel.font = ShiftLedgerTypography.body
        anchorSubtitleLabel.textColor = ShiftLedgerColors.textSecondary
        anchorSubtitleLabel.numberOfLines = 0
        anchorSubtitleLabel.adjustsFontForContentSizeCategory = true

        anchorValueLabel.font = ShiftLedgerTypography.callout
        anchorValueLabel.textColor = ShiftLedgerColors.textPrimary
        anchorValueLabel.numberOfLines = 0
        anchorValueLabel.adjustsFontForContentSizeCategory = true

        anchorChevron.tintColor = ShiftLedgerColors.textTertiary
        anchorChevron.contentMode = .scaleAspectFit
        anchorChevron.isAccessibilityElement = false
        anchorRow.isAccessibilityElement = true
        anchorRow.accessibilityLabel = PayPeriodSetupStrings.anchorChoose
        anchorRow.accessibilityTraits = .button
        anchorSeparator.backgroundColor = ShiftLedgerColors.separator
    }

    private func configureSubviews() {
        [
            scaffold,
            questionLabel,
            subtitleLabel,
            optionsStack,
            anchorSection,
            anchorTitleLabel,
            anchorSubtitleLabel,
            anchorRow,
            anchorValueLabel,
            anchorChevron,
            anchorSeparator
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        anchorRow.addSubview(anchorValueLabel)
        anchorRow.addSubview(anchorChevron)

        addSubview(scaffold)
        [questionLabel, subtitleLabel, optionsStack, anchorSection].forEach(scaffold.contentView.addSubview)
    }

    private func configureLayout() {
        continueTopAfterAnchorConstraint = scaffold.continueButton.topAnchor.constraint(
            greaterThanOrEqualTo: anchorSection.bottomAnchor,
            constant: 44
        )
        continueTopAfterOptionsConstraint = scaffold.continueButton.topAnchor.constraint(
            greaterThanOrEqualTo: optionsStack.bottomAnchor,
            constant: 44
        )

        NSLayoutConstraint.activate([
            scaffold.topAnchor.constraint(equalTo: topAnchor),
            scaffold.leadingAnchor.constraint(equalTo: leadingAnchor),
            scaffold.trailingAnchor.constraint(equalTo: trailingAnchor),
            scaffold.bottomAnchor.constraint(equalTo: bottomAnchor),

            questionLabel.topAnchor.constraint(equalTo: scaffold.progressBottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            subtitleLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),
            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            optionsStack.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            optionsStack.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),

            anchorSection.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 28),
            anchorSection.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            anchorSection.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            anchorRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            anchorValueLabel.leadingAnchor.constraint(equalTo: anchorRow.leadingAnchor),
            anchorValueLabel.topAnchor.constraint(equalTo: anchorRow.topAnchor, constant: 8),
            anchorValueLabel.bottomAnchor.constraint(equalTo: anchorRow.bottomAnchor, constant: -8),
            anchorValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: anchorChevron.leadingAnchor, constant: -12),
            anchorChevron.trailingAnchor.constraint(equalTo: anchorRow.trailingAnchor),
            anchorChevron.centerYAnchor.constraint(equalTo: anchorRow.centerYAnchor),
            anchorChevron.widthAnchor.constraint(equalToConstant: 9),
            anchorChevron.heightAnchor.constraint(equalToConstant: 13),
            anchorSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        continueTopAfterOptionsConstraint?.isActive = true
    }

    private func configureInteractions() {
        scaffold.onBackTapped = { [weak self] in self?.onBackTapped?() }
        scaffold.onContinueTapped = { [weak self] in self?.onContinueTapped?() }
        perShiftControl.addAction(UIAction { [weak self] _ in self?.onCycleKindSelected?(.perShift) }, for: .touchUpInside)
        weeklyControl.addAction(UIAction { [weak self] _ in self?.onCycleKindSelected?(.weekly) }, for: .touchUpInside)
        biweeklyControl.addAction(UIAction { [weak self] _ in self?.onCycleKindSelected?(.biweekly) }, for: .touchUpInside)
        calendarMonthlyControl.addAction(UIAction { [weak self] _ in self?.onCycleKindSelected?(.calendarMonthly) }, for: .touchUpInside)
        anchorRow.addAction(UIAction { [weak self] _ in self?.onAnchorTapped?() }, for: .touchUpInside)
    }
}

private final class TappableControl: UIControl {
    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchUpInside)
        return true
    }
}

private final class FrequencyOptionControl: UIControl {
    private let optionTitle: String
    private let titleLabel = UILabel()

    override var isSelected: Bool {
        didSet {
            titleLabel.text = isSelected ? "●  \(optionTitle)" : "○  \(optionTitle)"
            titleLabel.textColor = isSelected ? ShiftLedgerColors.accentPrimary : ShiftLedgerColors.textPrimary
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    init(title: String) {
        optionTitle = title
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "○  \(title)"
        titleLabel.font = ShiftLedgerTypography.body
        titleLabel.textColor = ShiftLedgerColors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
