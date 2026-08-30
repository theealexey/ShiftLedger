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

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let topRow = UIStackView()
    private let topRowSpacer = UIView()
    private let brandLabel = UILabel()
    private let stepLabel = UILabel()
    private let progressStack = UIStackView()
    private let progressSegments = (0..<4).map { _ in UIView() }
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
    private let continueButton = UIButton(type: .system)

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
    }

    func setContinueEnabled(_ enabled: Bool) {
        continueButton.isEnabled = enabled

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.baseForegroundColor = enabled
            ? ShiftLedgerColors.accentPrimary
            : ShiftLedgerColors.textTertiary
        continueButton.configuration = configuration
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        updateDynamicTypeLayout()
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        brandLabel.text = JobSetupStrings.brandName
        brandLabel.font = ShiftLedgerTypography.caption
        brandLabel.textColor = ShiftLedgerColors.accentPrimary
        brandLabel.numberOfLines = 1
        brandLabel.adjustsFontForContentSizeCategory = true
        brandLabel.isAccessibilityElement = false

        stepLabel.text = JobSetupStrings.stepIndicator
        stepLabel.font = ShiftLedgerTypography.caption
        stepLabel.textColor = ShiftLedgerColors.textTertiary
        stepLabel.adjustsFontForContentSizeCategory = true
        stepLabel.accessibilityLabel = JobSetupStrings.stepIndicatorAccessibilityLabel

        for (index, segment) in progressSegments.enumerated() {
            segment.backgroundColor = index == 0
                ? ShiftLedgerColors.accentPrimary
                : ShiftLedgerColors.separator
        }

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

        currencySymbolLabel.font = ShiftLedgerTypography.title
        currencySymbolLabel.textColor = ShiftLedgerColors.textSecondary
        currencySymbolLabel.adjustsFontForContentSizeCategory = true

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

        basePayAmountTextField.font = ShiftLedgerTypography.display
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

        var continueConfiguration = UIButton.Configuration.plain()
        continueConfiguration.title = JobSetupStrings.continueTitle
        continueConfiguration.image = UIImage(systemName: "arrow.right")
        continueConfiguration.imagePlacement = .trailing
        continueConfiguration.imagePadding = 8
        continueConfiguration.titleAlignment = .trailing
        continueConfiguration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        continueConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 0,
            bottom: 10,
            trailing: 0
        )
        continueConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.button
            return transformedAttributes
        }
        continueButton.configuration = continueConfiguration
        continueButton.contentHorizontalAlignment = .trailing
        continueButton.titleLabel?.numberOfLines = 0
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }

    private func configureSubviews() {
        [
            scrollView,
            contentView,
            topRow,
            topRowSpacer,
            brandLabel,
            stepLabel,
            progressStack,
            questionLabel,
            supportingTextLabel,
            heroMoneyStack,
            currencySymbolLabel,
            basisOptionsStack,
            hourlyBasisControl,
            fixedPerShiftBasisControl,
            amountSection,
            amountTitleLabel,
            basePayAmountTextField,
            basePayAmountUnderline,
            currencyRow,
            currencyTitleLabel,
            currencyValueLabel,
            currencyChevron,
            currencySeparator,
            continueButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.distribution = .fill
        topRow.addArrangedSubview(brandLabel)
        topRow.addArrangedSubview(topRowSpacer)
        topRow.addArrangedSubview(stepLabel)

        progressStack.axis = .horizontal
        progressStack.alignment = .fill
        progressStack.distribution = .fillEqually
        progressStack.spacing = 3
        progressSegments.forEach(progressStack.addArrangedSubview)

        heroMoneyStack.axis = .horizontal
        heroMoneyStack.alignment = .firstBaseline
        heroMoneyStack.spacing = 8
        heroMoneyStack.addArrangedSubview(currencySymbolLabel)
        heroMoneyStack.addArrangedSubview(basePayAmountTextField)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        [
            topRow,
            progressStack,
            questionLabel,
            supportingTextLabel,
            basisOptionsStack,
            amountSection,
            currencyRow,
            currencySeparator,
            continueButton
        ].forEach(contentView.addSubview)

        [currencyTitleLabel, currencyValueLabel, currencyChevron].forEach(currencyRow.addSubview)

        stepLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        brandLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        topRowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        currencySymbolLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        currencyValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        currencyChevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        updateDynamicTypeLayout()
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            progressStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 16),
            progressStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressStack.heightAnchor.constraint(equalToConstant: 1),

            questionLabel.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            supportingTextLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            supportingTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            supportingTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            basisOptionsStack.topAnchor.constraint(equalTo: supportingTextLabel.bottomAnchor, constant: 32),
            basisOptionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            basisOptionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            amountSection.topAnchor.constraint(equalTo: basisOptionsStack.bottomAnchor, constant: 28),
            amountSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            amountSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            basePayAmountTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            basePayAmountTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            basePayAmountTextField.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -48),
            basePayAmountUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            currencyRow.topAnchor.constraint(equalTo: amountSection.bottomAnchor, constant: 28),
            currencyRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            currencyRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
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
            currencySeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            currencySeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            currencySeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.topAnchor.constraint(greaterThanOrEqualTo: currencySeparator.bottomAnchor, constant: 44),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountTextChanged), for: .editingChanged)
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountEditingDidBegin), for: .editingDidBegin)
        basePayAmountTextField.addTarget(self, action: #selector(basePayAmountEditingDidEnd), for: .editingDidEnd)
        hourlyBasisControl.addAction(UIAction { [weak self] _ in self?.onBasePayBasisSelected?(.hourly) }, for: .touchUpInside)
        fixedPerShiftBasisControl.addAction(UIAction { [weak self] _ in self?.onBasePayBasisSelected?(.fixedPerShift) }, for: .touchUpInside)
        currencyRow.addTarget(self, action: #selector(currencyTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    private func configureTraitChanges() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: JobSetupView, _) in
            self.updateDynamicTypeLayout()
        }
    }

    private func updateDynamicTypeLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory

        topRow.axis = usesAccessibilityLayout ? .vertical : .horizontal
        topRow.alignment = usesAccessibilityLayout ? .fill : .top
        topRow.spacing = usesAccessibilityLayout ? 8 : 12
        topRowSpacer.isHidden = usesAccessibilityLayout
        brandLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1
        brandLabel.setContentCompressionResistancePriority(
            usesAccessibilityLayout ? .required : .defaultLow,
            for: .horizontal
        )
        stepLabel.textAlignment = usesAccessibilityLayout ? .right : .natural

        heroMoneyStack.axis = usesAccessibilityLayout ? .vertical : .horizontal
        heroMoneyStack.alignment = usesAccessibilityLayout ? .leading : .firstBaseline
        heroMoneyStack.spacing = usesAccessibilityLayout ? 4 : 8

        updateContinueButtonLayout(usesAccessibilityLayout: usesAccessibilityLayout)
    }

    private func updateContinueButtonLayout(usesAccessibilityLayout: Bool) {
        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.imagePlacement = usesAccessibilityLayout ? .bottom : .trailing
        configuration.imagePadding = usesAccessibilityLayout ? 4 : 8
        continueButton.configuration = configuration
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

    @objc private func continueTapped() {
        onContinueTapped?()
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
            titleLabel.textColor = isSelected
                ? ShiftLedgerColors.accentPrimary
                : ShiftLedgerColors.textPrimary
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
