import UIKit

final class JobSetupView: UIView {
    var onNameChanged: ((String) -> Void)?
    var onContinueTapped: (() -> Void)?

    var nameText: String {
        get { nameTextField.text ?? "" }
        set { nameTextField.text = newValue }
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let topRow = UIStackView()
    private let topRowSpacer = UIView()
    private let brandLabel = UILabel()
    private let stepLabel = UILabel()
    private let questionLabel = UILabel()
    private let supportingTextLabel = UILabel()
    private let nameLabel = UILabel()
    private let nameTextField = UITextField()
    private let nameUnderline = UIView()
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

        updateTopRowLayout()
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

        nameLabel.text = JobSetupStrings.nameTitle
        nameLabel.font = ShiftLedgerTypography.headline
        nameLabel.textColor = ShiftLedgerColors.textPrimary
        nameLabel.numberOfLines = 0
        nameLabel.adjustsFontForContentSizeCategory = true

        nameTextField.font = ShiftLedgerTypography.body
        nameTextField.textColor = ShiftLedgerColors.textPrimary
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: JobSetupStrings.namePlaceholder,
            attributes: [.foregroundColor: ShiftLedgerColors.textTertiary]
        )
        nameTextField.backgroundColor = .clear
        nameTextField.borderStyle = .none
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.returnKeyType = .done
        nameTextField.autocorrectionType = .no
        nameTextField.autocapitalizationType = .words
        nameTextField.adjustsFontForContentSizeCategory = true
        nameTextField.delegate = self
        nameTextField.accessibilityLabel = JobSetupStrings.nameTitle
        nameTextField.accessibilityHint = JobSetupStrings.nameAccessibilityHint

        nameUnderline.backgroundColor = ShiftLedgerColors.separator

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
        [scrollView, contentView, topRow, topRowSpacer, brandLabel, stepLabel, questionLabel, supportingTextLabel, nameLabel, nameTextField, nameUnderline, continueButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topRow.axis = .horizontal
        topRow.alignment = .top
        topRow.distribution = .fill
        topRow.addArrangedSubview(brandLabel)
        topRow.addArrangedSubview(topRowSpacer)
        topRow.addArrangedSubview(stepLabel)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(topRow)
        [questionLabel, supportingTextLabel, nameLabel, nameTextField, nameUnderline, continueButton].forEach {
            contentView.addSubview($0)
        }

        stepLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        brandLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        topRowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        updateTopRowLayout()
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

            questionLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 52),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            supportingTextLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            supportingTextLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            supportingTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            nameLabel.topAnchor.constraint(equalTo: supportingTextLabel.bottomAnchor, constant: 48),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            nameTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            nameUnderline.topAnchor.constraint(equalTo: nameTextField.bottomAnchor),
            nameUnderline.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameUnderline.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            nameUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            continueButton.topAnchor.constraint(greaterThanOrEqualTo: nameUnderline.bottomAnchor, constant: 44),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        nameTextField.addTarget(self, action: #selector(nameTextChanged), for: .editingChanged)
        nameTextField.addTarget(self, action: #selector(nameEditingDidBegin), for: .editingDidBegin)
        nameTextField.addTarget(self, action: #selector(nameEditingDidEnd), for: .editingDidEnd)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    private func configureTraitChanges() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: JobSetupView, _) in
            self.updateTopRowLayout()
        }
    }

    private func updateTopRowLayout() {
        let usesVerticalLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory

        topRow.axis = usesVerticalLayout ? .vertical : .horizontal
        topRow.alignment = usesVerticalLayout ? .fill : .top
        topRow.spacing = usesVerticalLayout ? 8 : 12
        topRowSpacer.isHidden = usesVerticalLayout
        brandLabel.numberOfLines = usesVerticalLayout ? 0 : 1
        brandLabel.setContentCompressionResistancePriority(
            usesVerticalLayout ? .required : .defaultLow,
            for: .horizontal
        )
        stepLabel.textAlignment = usesVerticalLayout ? .right : .natural

        updateContinueButtonLayout(usesAccessibilityLayout: usesVerticalLayout)
    }

    private func updateContinueButtonLayout(usesAccessibilityLayout: Bool) {
        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.imagePlacement = usesAccessibilityLayout ? .bottom : .trailing
        configuration.imagePadding = usesAccessibilityLayout ? 4 : 8
        continueButton.configuration = configuration
    }

    @objc private func nameTextChanged() {
        onNameChanged?(nameText)
    }

    @objc private func nameEditingDidBegin() {
        nameUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
    }

    @objc private func nameEditingDidEnd() {
        nameUnderline.backgroundColor = ShiftLedgerColors.separator
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
