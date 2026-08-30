import UIKit

final class JobSetupView: UIView {
    var onBasePayAmountChanged: ((String) -> Void)?
    var onBasePayBasisSelected: ((BasePayBasis) -> Void)?
    var onCurrencyTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    var basePayAmountText: String {
        get { basePayAmountTextField.text ?? "" }
        set { basePayAmountTextField.text = newValue }
    }

    private let scaffold = JobSetupScaffoldView(
        brandText: JobSetupStrings.brandName,
        stepIndicator: JobSetupStrings.stepIndicator,
        stepAccessibilityLabel: JobSetupStrings.stepIndicatorAccessibilityLabel,
        activeStep: 1
    )
    private let questionLabel = UILabel()
    private let supportingTextLabel = UILabel()
    private let basisOptionsStack = UIStackView()
    private let hourlyBasisControl = BasePayBasisOptionControl(title: JobSetupStrings.hourlyBasis)
    private let fixedPerShiftBasisControl = BasePayBasisOptionControl(title: JobSetupStrings.fixedPerShiftBasis)
    private let amountSection = UIStackView()
    private let amountTitleLabel = UILabel()
    private let heroMoneyStack = UIStackView()
    private let currencySymbolLabel = UILabel()
    private let basePayAmountTextField = UITextField()
    private let basePayAmountUnderline = UIView()
    private let currencyRow = UIControl()
    private let currencyTitleLabel = UILabel()
    private let currencyValueLabel = UILabel()
    private let currencyChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let currencySeparator = UIView()
    private var currencyRowTopAfterAmountConstraint: NSLayoutConstraint?
    private var currencyRowTopAfterBasisConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureAppearance()
        configureSubviews()
        configureLayout()
        configureInteractions()
        configureTraitChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setCurrencyCode(_ code: String) {
        currencyValueLabel.text = code
        currencySymbolLabel.text = Locale(identifier: "en_US@currency=\(code)").currencySymbol ?? code
        currencyRow.accessibilityValue = code
    }

    func setBasePayBasis(_ basis: BasePayBasis?) {
        hourlyBasisControl.isSelected = basis == .hourly
        fixedPerShiftBasisControl.isSelected = basis == .fixedPerShift
        amountSection.isHidden = basis == nil
        amountTitleLabel.text = basis == .hourly
            ? JobSetupStrings.hourlyAmountTitle
            : JobSetupStrings.fixedPerShiftAmountTitle
        basePayAmountTextField.accessibilityLabel = amountTitleLabel.text
        basePayAmountTextField.accessibilityHint = JobSetupStrings.basePayAmountAccessibilityHint
        currencyRowTopAfterAmountConstraint?.isActive = basis != nil
        currencyRowTopAfterBasisConstraint?.isActive = basis == nil
    }

    func setContinueEnabled(_ enabled: Bool) {
        scaffold.setContinueEnabled(enabled)
    }

    private func configureAppearance() {
        questionLabel.text = JobSetupStrings.step1Title
        questionLabel.font = ShiftLedgerTypography.onboardingQuestion
        questionLabel.textColor = ShiftLedgerColors.textPrimary
        questionLabel.numberOfLines = 0
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.accessibilityTraits = .header

        supportingTextLabel.text = JobSetupStrings.step1Subtitle
        supportingTextLabel.font = ShiftLedgerTypography.body
        supportingTextLabel.textColor = ShiftLedgerColors.textSecondary
        supportingTextLabel.numberOfLines = 0
        supportingTextLabel.adjustsFontForContentSizeCategory = true

        basisOptionsStack.axis = .vertical
        basisOptionsStack.spacing = 0
        basisOptionsStack.addArrangedSubview(hourlyBasisControl)
        basisOptionsStack.addArrangedSubview(fixedPerShiftBasisControl)

        amountSection.axis = .vertical
        amountSection.spacing = 0
        amountSection.addArrangedSubview(amountTitleLabel)
        amountSection.addArrangedSubview(heroMoneyStack)
        amountSection.addArrangedSubview(basePayAmountUnderline)
        amountSection.setCustomSpacing(8, after: amountTitleLabel)
        amountSection.setCustomSpacing(8, after: heroMoneyStack)
        amountSection.isHidden = true

        amountTitleLabel.font = ShiftLedgerTypography.headline
        amountTitleLabel.textColor = ShiftLedgerColors.textPrimary
        amountTitleLabel.adjustsFontForContentSizeCategory = true
        amountTitleLabel.numberOfLines = 0

        currencySymbolLabel.font = ShiftLedgerTypography.title
        currencySymbolLabel.textColor = ShiftLedgerColors.textSecondary
        currencySymbolLabel.adjustsFontForContentSizeCategory = true

        basePayAmountTextField.font = ShiftLedgerTypography.basePayAmount
        basePayAmountTextField.textColor = ShiftLedgerColors.textPrimary
        basePayAmountTextField.backgroundColor = .clear
        basePayAmountTextField.borderStyle = .none
        basePayAmountTextField.keyboardType = .decimalPad
        basePayAmountTextField.textAlignment = .natural
        basePayAmountTextField.adjustsFontForContentSizeCategory = true
        basePayAmountTextField.delegate = self
        basePayAmountTextField.accessibilityHint = JobSetupStrings.basePayAmountAccessibilityHint

        basePayAmountUnderline.backgroundColor = ShiftLedgerColors.separator

        currencyTitleLabel.text = JobSetupStrings.currencyTitle
        currencyTitleLabel.font = ShiftLedgerTypography.body
        currencyTitleLabel.textColor = ShiftLedgerColors.textPrimary
        currencyTitleLabel.numberOfLines = 0
        currencyTitleLabel.adjustsFontForContentSizeCategory = true

        currencyValueLabel.font = ShiftLedgerTypography.callout
        currencyValueLabel.textColor = ShiftLedgerColors.textSecondary
        currencyValueLabel.adjustsFontForContentSizeCategory = true

        currencyChevron.tintColor = ShiftLedgerColors.textSecondary
        currencyChevron.contentMode = .scaleAspectFit
        currencyChevron.isAccessibilityElement = false

        currencyRow.isAccessibilityElement = true
        currencyRow.accessibilityLabel = JobSetupStrings.currencyTitle
        currencyRow.accessibilityHint = JobSetupStrings.currencyAccessibilityHint
        currencyRow.accessibilityTraits = .button
        currencySeparator.backgroundColor = ShiftLedgerColors.separator
    }

    private func configureSubviews() {
        [
            scaffold,
            questionLabel,
            supportingTextLabel,
            basisOptionsStack,
            amountSection,
            amountTitleLabel,
            heroMoneyStack,
            currencySymbolLabel,
            basePayAmountTextField,
            basePayAmountUnderline,
            currencyRow,
            currencyTitleLabel,
            currencyValueLabel,
            currencyChevron,
            currencySeparator
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        heroMoneyStack.axis = .horizontal
        heroMoneyStack.alignment = .firstBaseline
        heroMoneyStack.spacing = 8
        heroMoneyStack.addArrangedSubview(currencySymbolLabel)
        heroMoneyStack.addArrangedSubview(basePayAmountTextField)

        addSubview(scaffold)
        [questionLabel, supportingTextLabel, basisOptionsStack, amountSection, currencyRow, currencySeparator]
            .forEach(scaffold.contentView.addSubview)
        [currencyTitleLabel, currencyValueLabel, currencyChevron].forEach(currencyRow.addSubview)

        currencySymbolLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        currencyValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        currencyChevron.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func configureLayout() {
        currencyRowTopAfterAmountConstraint = currencyRow.topAnchor.constraint(
            equalTo: amountSection.bottomAnchor,
            constant: 28
        )
        currencyRowTopAfterBasisConstraint = currencyRow.topAnchor.constraint(
            equalTo: basisOptionsStack.bottomAnchor,
            constant: 28
        )

        NSLayoutConstraint.activate([
            scaffold.topAnchor.constraint(equalTo: topAnchor),
            scaffold.leadingAnchor.constraint(equalTo: leadingAnchor),
            scaffold.trailingAnchor.constraint(equalTo: trailingAnchor),
            scaffold.bottomAnchor.constraint(equalTo: bottomAnchor),

            questionLabel.topAnchor.constraint(equalTo: scaffold.progressBottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),

            supportingTextLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            supportingTextLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            supportingTextLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),

            basisOptionsStack.topAnchor.constraint(equalTo: supportingTextLabel.bottomAnchor, constant: 32),
            basisOptionsStack.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            basisOptionsStack.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),

            amountSection.topAnchor.constraint(equalTo: basisOptionsStack.bottomAnchor, constant: 28),
            amountSection.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            amountSection.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            basePayAmountTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            basePayAmountTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            basePayAmountTextField.widthAnchor.constraint(lessThanOrEqualTo: scaffold.contentView.widthAnchor, constant: -48),
            basePayAmountUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            currencyRow.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            currencyRow.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            currencyRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            currencyTitleLabel.leadingAnchor.constraint(equalTo: currencyRow.leadingAnchor),
            currencyTitleLabel.topAnchor.constraint(equalTo: currencyRow.topAnchor, constant: 8),
            currencyTitleLabel.bottomAnchor.constraint(equalTo: currencyRow.bottomAnchor, constant: -8),
            currencyTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: currencyValueLabel.leadingAnchor, constant: -12),
            currencyChevron.trailingAnchor.constraint(equalTo: currencyRow.trailingAnchor),
            currencyChevron.centerYAnchor.constraint(equalTo: currencyRow.centerYAnchor),
            currencyChevron.widthAnchor.constraint(equalToConstant: 9),
            currencyChevron.heightAnchor.constraint(equalToConstant: 13),
            currencyValueLabel.trailingAnchor.constraint(equalTo: currencyChevron.leadingAnchor, constant: -12),
            currencyValueLabel.centerYAnchor.constraint(equalTo: currencyRow.centerYAnchor),
            currencySeparator.topAnchor.constraint(equalTo: currencyRow.bottomAnchor),
            currencySeparator.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            currencySeparator.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            currencySeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            scaffold.continueButton.topAnchor.constraint(greaterThanOrEqualTo: currencySeparator.bottomAnchor, constant: 44)
        ])

        currencyRowTopAfterBasisConstraint?.isActive = true
    }

    private func configureInteractions() {
        scaffold.onContinueTapped = { [weak self] in self?.onContinueTapped?() }
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountTextChanged), for: .editingChanged)
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountEditingDidBegin), for: .editingDidBegin)
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountEditingDidEnd), for: .editingDidEnd)
        hourlyBasisControl.addAction(UIAction { [weak self] _ in self?.onBasePayBasisSelected?(.hourly) }, for: .touchUpInside)
        fixedPerShiftBasisControl.addAction(UIAction { [weak self] _ in self?.onBasePayBasisSelected?(.fixedPerShift) }, for: .touchUpInside)
        currencyRow.addTarget(self, action: #selector(currencyTapped), for: .touchUpInside)
    }

    private func configureTraitChanges() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: JobSetupView, _) in
            self.updateDynamicTypeLayout()
        }
        updateDynamicTypeLayout()
    }

    private func updateDynamicTypeLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        heroMoneyStack.axis = usesAccessibilityLayout ? .vertical : .horizontal
        heroMoneyStack.alignment = usesAccessibilityLayout ? .leading : .firstBaseline
        heroMoneyStack.spacing = usesAccessibilityLayout ? 4 : 8
    }

    @objc private func basePayAmountTextChanged() {
        onBasePayAmountChanged?(basePayAmountText)
    }

    @objc private func basePayAmountEditingDidBegin() {
        basePayAmountUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
    }

    @objc private func basePayAmountEditingDidEnd() {
        basePayAmountUnderline.backgroundColor = ShiftLedgerColors.separator
    }

    @objc private func currencyTapped() {
        onCurrencyTapped?()
    }
}

extension JobSetupView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        endEditing(true)
        return true
    }
}

private final class BasePayBasisOptionControl: UIControl {
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
