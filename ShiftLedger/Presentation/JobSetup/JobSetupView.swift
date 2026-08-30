import UIKit

final class JobSetupView: UIView {
    var onHourlyRateChanged: ((String) -> Void)?
    var onCurrencyTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    var hourlyRateText: String {
        get { hourlyRateTextField.text ?? "" }
        set { hourlyRateTextField.text = newValue }
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
    private let heroMoneyStack = UIStackView()
    private let currencySymbolLabel = UILabel()
    private let hourlyRateTextField = UITextField()
    private let hourlyRateUnderline = UIView()
    private let currencyRow = UIControl()
    private let currencyTitleLabel = UILabel()
    private let currencyValueLabel = UILabel()
    private let currencyChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let currencySeparator = UIView()
    private let actionSeparator = UIView()
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

        hourlyRateTextField.font = ShiftLedgerTypography.display
        hourlyRateTextField.textColor = ShiftLedgerColors.textPrimary
        hourlyRateTextField.backgroundColor = .clear
        hourlyRateTextField.borderStyle = .none
        hourlyRateTextField.keyboardType = .decimalPad
        hourlyRateTextField.textAlignment = .natural
        hourlyRateTextField.adjustsFontForContentSizeCategory = true
        hourlyRateTextField.delegate = self
        hourlyRateTextField.accessibilityLabel = JobSetupStrings.step1Title
        hourlyRateTextField.accessibilityHint = JobSetupStrings.hourlyRateAccessibilityHint

        hourlyRateUnderline.backgroundColor = ShiftLedgerColors.separator

        currencyTitleLabel.text = JobSetupStrings.currencyTitle
        currencyTitleLabel.font = ShiftLedgerTypography.headline
        currencyTitleLabel.textColor = ShiftLedgerColors.textPrimary
        currencyTitleLabel.numberOfLines = 0
        currencyTitleLabel.adjustsFontForContentSizeCategory = true

        currencyValueLabel.font = ShiftLedgerTypography.callout
        currencyValueLabel.textColor = ShiftLedgerColors.textSecondary
        currencyValueLabel.adjustsFontForContentSizeCategory = true

        currencyChevron.tintColor = ShiftLedgerColors.textTertiary
        currencyChevron.contentMode = .scaleAspectFit
        currencyChevron.isAccessibilityElement = false

        currencyRow.isAccessibilityElement = true
        currencyRow.accessibilityLabel = JobSetupStrings.currencyTitle
        currencyRow.accessibilityHint = JobSetupStrings.currencyAccessibilityHint
        currencyRow.accessibilityTraits = .button

        currencySeparator.backgroundColor = ShiftLedgerColors.separator
        actionSeparator.backgroundColor = ShiftLedgerColors.separator

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
            hourlyRateTextField,
            hourlyRateUnderline,
            currencyRow,
            currencyTitleLabel,
            currencyValueLabel,
            currencyChevron,
            currencySeparator,
            actionSeparator,
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
        progressStack.spacing = 4
        progressSegments.forEach(progressStack.addArrangedSubview)

        heroMoneyStack.axis = .horizontal
        heroMoneyStack.alignment = .firstBaseline
        heroMoneyStack.spacing = 8
        heroMoneyStack.addArrangedSubview(currencySymbolLabel)
        heroMoneyStack.addArrangedSubview(hourlyRateTextField)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        [
            topRow,
            progressStack,
            questionLabel,
            supportingTextLabel,
            heroMoneyStack,
            hourlyRateUnderline,
            currencyRow,
            currencySeparator,
            actionSeparator,
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
            progressStack.heightAnchor.constraint(equalToConstant: 2),

            questionLabel.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            supportingTextLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            supportingTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            supportingTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            heroMoneyStack.topAnchor.constraint(equalTo: supportingTextLabel.bottomAnchor, constant: 36),
            heroMoneyStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            heroMoneyStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            hourlyRateTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            hourlyRateUnderline.topAnchor.constraint(equalTo: heroMoneyStack.bottomAnchor, constant: 8),
            hourlyRateUnderline.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            hourlyRateUnderline.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            hourlyRateUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            currencyRow.topAnchor.constraint(equalTo: hourlyRateUnderline.bottomAnchor, constant: 28),
            currencyRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            currencyRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            currencyRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            currencyTitleLabel.leadingAnchor.constraint(equalTo: currencyRow.leadingAnchor),
            currencyTitleLabel.topAnchor.constraint(equalTo: currencyRow.topAnchor, constant: 8),
            currencyTitleLabel.bottomAnchor.constraint(equalTo: currencyRow.bottomAnchor, constant: -8),
            currencyTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: currencyValueLabel.leadingAnchor, constant: -12),

            currencyChevron.trailingAnchor.constraint(equalTo: currencyRow.trailingAnchor),
            currencyChevron.centerYAnchor.constraint(equalTo: currencyRow.centerYAnchor),
            currencyChevron.widthAnchor.constraint(equalToConstant: 12),
            currencyChevron.heightAnchor.constraint(equalToConstant: 18),

            currencyValueLabel.trailingAnchor.constraint(equalTo: currencyChevron.leadingAnchor, constant: -12),
            currencyValueLabel.centerYAnchor.constraint(equalTo: currencyRow.centerYAnchor),

            currencySeparator.topAnchor.constraint(equalTo: currencyRow.bottomAnchor),
            currencySeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            currencySeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            currencySeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            actionSeparator.topAnchor.constraint(greaterThanOrEqualTo: currencySeparator.bottomAnchor, constant: 44),
            actionSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            actionSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            actionSeparator.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -16),
            actionSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        hourlyRateTextField.addTarget(self, action: #selector(hourlyRateTextChanged), for: .editingChanged)
        hourlyRateTextField.addTarget(self, action: #selector(hourlyRateEditingDidBegin), for: .editingDidBegin)
        hourlyRateTextField.addTarget(self, action: #selector(hourlyRateEditingDidEnd), for: .editingDidEnd)
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

    @objc private func hourlyRateTextChanged() {
        onHourlyRateChanged?(hourlyRateText)
    }

    @objc private func hourlyRateEditingDidBegin() {
        hourlyRateUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
    }

    @objc private func hourlyRateEditingDidEnd() {
        hourlyRateUnderline.backgroundColor = ShiftLedgerColors.separator
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
