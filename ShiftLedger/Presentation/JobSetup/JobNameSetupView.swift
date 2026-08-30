import UIKit

final class JobNameSetupView: UIView, UITextFieldDelegate {
    var onBackTapped: (() -> Void)?
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
    private let backButton = UIButton(type: .system)
    private let stepLabel = UILabel()
    private let progressStack = UIStackView()
    private let progressSegments = (0..<4).map { _ in UIView() }
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
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
        updateDynamicTypeLayout()
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = ShiftLedgerColors.textSecondary
        backButton.accessibilityLabel = JobSetupStrings.back
        backButton.accessibilityTraits = .button

        stepLabel.text = JobSetupStrings.step3StepIndicator
        stepLabel.font = ShiftLedgerTypography.caption
        stepLabel.textColor = ShiftLedgerColors.textTertiary
        stepLabel.adjustsFontForContentSizeCategory = true
        stepLabel.accessibilityLabel = JobSetupStrings.step3StepIndicatorAccessibilityLabel

        progressStack.axis = .horizontal
        progressStack.alignment = .fill
        progressStack.distribution = .fillEqually
        progressStack.spacing = 3
        progressSegments.forEach { segment in
            segment.backgroundColor = ShiftLedgerColors.separator
            segment.isAccessibilityElement = false
        }
        progressSegments.prefix(3).forEach { $0.backgroundColor = ShiftLedgerColors.accentPrimary }
        progressStack.isAccessibilityElement = false

        questionLabel.text = JobSetupStrings.step3Title
        questionLabel.font = ShiftLedgerTypography.onboardingQuestion
        questionLabel.textColor = ShiftLedgerColors.textPrimary
        questionLabel.numberOfLines = 0
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.accessibilityTraits = .header

        subtitleLabel.text = JobSetupStrings.step3Subtitle
        subtitleLabel.font = ShiftLedgerTypography.body
        subtitleLabel.textColor = ShiftLedgerColors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        nameTextField.font = ShiftLedgerTypography.title
        nameTextField.textColor = ShiftLedgerColors.textPrimary
        nameTextField.tintColor = ShiftLedgerColors.accentPrimary
        nameTextField.backgroundColor = .clear
        nameTextField.borderStyle = .none
        nameTextField.placeholder = JobSetupStrings.namePlaceholder
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: JobSetupStrings.namePlaceholder,
            attributes: [.foregroundColor: ShiftLedgerColors.textTertiary]
        )
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.autocorrectionType = .no
        nameTextField.returnKeyType = .done
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
        continueConfiguration.baseForegroundColor = ShiftLedgerColors.textTertiary
        continueConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
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
            backButton,
            stepLabel,
            progressStack,
            questionLabel,
            subtitleLabel,
            nameTextField,
            nameUnderline,
            continueButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.addArrangedSubview(backButton)
        topRow.addArrangedSubview(topRowSpacer)
        topRow.addArrangedSubview(stepLabel)

        progressSegments.forEach(progressStack.addArrangedSubview)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        [topRow, progressStack, questionLabel, subtitleLabel, nameTextField, nameUnderline, continueButton]
            .forEach(contentView.addSubview)

        topRowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stepLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
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

            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            progressStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            progressStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressStack.heightAnchor.constraint(equalToConstant: 1),

            questionLabel.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),

            nameTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            nameUnderline.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 8),
            nameUnderline.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            nameUnderline.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            nameUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            continueButton.topAnchor.constraint(greaterThanOrEqualTo: nameUnderline.bottomAnchor, constant: 44),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameTextField.addTarget(self, action: #selector(nameEditingDidBegin), for: .editingDidBegin)
        nameTextField.addTarget(self, action: #selector(nameEditingDidEnd), for: .editingDidEnd)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    private func configureTraitChanges() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: JobNameSetupView, _) in
            self.updateDynamicTypeLayout()
        }
    }

    private func updateDynamicTypeLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        topRow.axis = usesAccessibilityLayout ? .vertical : .horizontal
        topRow.alignment = usesAccessibilityLayout ? .fill : .center
        topRow.spacing = usesAccessibilityLayout ? 8 : 12
        topRowSpacer.isHidden = usesAccessibilityLayout
        stepLabel.textAlignment = usesAccessibilityLayout ? .right : .natural

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        continueButton.configuration = configuration
    }

    @objc private func backTapped() {
        endEditing(true)
        onBackTapped?()
    }

    @objc private func nameChanged() {
        onNameChanged?(nameText)
    }

    @objc private func nameEditingDidBegin() {
        nameUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
    }

    @objc private func nameEditingDidEnd() {
        nameUnderline.backgroundColor = ShiftLedgerColors.separator
    }

    @objc private func continueTapped() {
        endEditing(true)
        onContinueTapped?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
