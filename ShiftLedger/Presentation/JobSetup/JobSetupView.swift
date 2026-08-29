import UIKit

final class JobSetupView: UIView {
    var onNameChanged: ((String) -> Void)?
    var onCurrencyTapped: (() -> Void)?
    var onTimeZoneTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    var nameText: String {
        get { nameTextField.text ?? "" }
        set { nameTextField.text = newValue }
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let headingStack = UIStackView()
    private let nameStack = UIStackView()
    private let selectionStack = UIStackView()

    private let brandLabel = UILabel()
    private let titleLabel = UILabel()
    private let supportingTextLabel = UILabel()
    private let nameLabel = UILabel()
    private let nameFieldContainer = UIView()
    private let nameTextField = UITextField()
    private let selectionGroup = UIView()
    private let selectionSeparator = UIView()
    private let currencyButton = UIButton(type: .system)
    private let timeZoneButton = UIButton(type: .system)
    private let continueButton = UIButton(type: .system)

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

    func setCurrencyCode(_ code: String) {
        setSelectionValue(code, for: currencyButton)
    }

    func setTimeZoneIdentifier(_ identifier: String) {
        setSelectionValue(identifier, for: timeZoneButton)
    }

    func setContinueEnabled(_ enabled: Bool) {
        continueButton.isEnabled = enabled

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.baseBackgroundColor = enabled
            ? ShiftLedgerColors.accentPrimary
            : ShiftLedgerColors.backgroundSecondary
        configuration.baseForegroundColor = enabled
            ? ShiftLedgerColors.backgroundPrimary
            : ShiftLedgerColors.textTertiary
        continueButton.configuration = configuration
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        brandLabel.text = "SHIFTLEDGER"
        brandLabel.font = ShiftLedgerTypography.caption
        brandLabel.textColor = ShiftLedgerColors.accentPrimary
        brandLabel.adjustsFontForContentSizeCategory = true
        brandLabel.isAccessibilityElement = false

        titleLabel.text = "Настроим вашу работу"
        titleLabel.font = ShiftLedgerTypography.largeTitle
        titleLabel.textColor = ShiftLedgerColors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        supportingTextLabel.text = "Укажите основные данные для расчёта начислений."
        supportingTextLabel.font = ShiftLedgerTypography.body
        supportingTextLabel.textColor = ShiftLedgerColors.textSecondary
        supportingTextLabel.numberOfLines = 0
        supportingTextLabel.adjustsFontForContentSizeCategory = true

        nameLabel.text = "Название работы"
        nameLabel.font = ShiftLedgerTypography.headline
        nameLabel.textColor = ShiftLedgerColors.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true

        nameFieldContainer.backgroundColor = ShiftLedgerColors.surfacePrimary
        nameFieldContainer.layer.cornerRadius = 12

        nameTextField.font = ShiftLedgerTypography.body
        nameTextField.textColor = ShiftLedgerColors.textPrimary
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: "Например, Karolinska Hospital",
            attributes: [.foregroundColor: ShiftLedgerColors.textTertiary]
        )
        nameTextField.borderStyle = .none
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.returnKeyType = .done
        nameTextField.autocorrectionType = .no
        nameTextField.autocapitalizationType = .words
        nameTextField.adjustsFontForContentSizeCategory = true
        nameTextField.delegate = self
        nameTextField.accessibilityLabel = "Название работы"
        nameTextField.accessibilityHint = "Введите название вашей работы"

        selectionGroup.backgroundColor = ShiftLedgerColors.surfacePrimary
        selectionGroup.layer.cornerRadius = 12
        selectionSeparator.backgroundColor = ShiftLedgerColors.separator

        configureSelectionButton(currencyButton, title: "Валюта", hint: "Открывает выбор валюты")
        configureSelectionButton(timeZoneButton, title: "Часовой пояс", hint: "Открывает выбор часового пояса")

        var continueConfiguration = UIButton.Configuration.filled()
        continueConfiguration.title = "Продолжить"
        continueConfiguration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        continueConfiguration.baseForegroundColor = ShiftLedgerColors.backgroundPrimary
        continueConfiguration.cornerStyle = .medium
        continueConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 14,
            leading: 20,
            bottom: 14,
            trailing: 20
        )
        continueConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.button
            return transformedAttributes
        }
        continueButton.configuration = continueConfiguration
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
        continueButton.accessibilityLabel = "Продолжить"
    }

    private func configureSubviews() {
        [scrollView, contentView, contentStack, headingStack, nameStack, nameFieldContainer, selectionGroup, selectionStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [brandLabel, titleLabel, supportingTextLabel, nameLabel, nameTextField, selectionSeparator, currencyButton, timeZoneButton, continueButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill

        headingStack.axis = .vertical
        headingStack.spacing = 8
        headingStack.alignment = .fill

        nameStack.axis = .vertical
        nameStack.spacing = 8
        nameStack.alignment = .fill

        selectionStack.axis = .vertical
        selectionStack.spacing = 0
        selectionStack.alignment = .fill

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        headingStack.addArrangedSubview(titleLabel)
        headingStack.addArrangedSubview(supportingTextLabel)

        nameFieldContainer.addSubview(nameTextField)
        nameStack.addArrangedSubview(nameLabel)
        nameStack.addArrangedSubview(nameFieldContainer)

        selectionStack.addArrangedSubview(currencyButton)
        selectionStack.addArrangedSubview(selectionSeparator)
        selectionStack.addArrangedSubview(timeZoneButton)
        selectionGroup.addSubview(selectionStack)

        contentStack.addArrangedSubview(brandLabel)
        contentStack.addArrangedSubview(headingStack)
        contentStack.addArrangedSubview(nameStack)
        contentStack.addArrangedSubview(selectionGroup)
        contentStack.addArrangedSubview(continueButton)
        contentStack.setCustomSpacing(20, after: brandLabel)
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

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            nameTextField.topAnchor.constraint(equalTo: nameFieldContainer.topAnchor, constant: 12),
            nameTextField.leadingAnchor.constraint(equalTo: nameFieldContainer.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: nameFieldContainer.trailingAnchor, constant: -16),
            nameTextField.bottomAnchor.constraint(equalTo: nameFieldContainer.bottomAnchor, constant: -12),
            nameFieldContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            selectionStack.topAnchor.constraint(equalTo: selectionGroup.topAnchor),
            selectionStack.leadingAnchor.constraint(equalTo: selectionGroup.leadingAnchor),
            selectionStack.trailingAnchor.constraint(equalTo: selectionGroup.trailingAnchor),
            selectionStack.bottomAnchor.constraint(equalTo: selectionGroup.bottomAnchor),
            currencyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            timeZoneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            selectionSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    private func configureInteractions() {
        nameTextField.addTarget(self, action: #selector(nameTextChanged), for: .editingChanged)
        currencyButton.addTarget(self, action: #selector(currencyTapped), for: .touchUpInside)
        timeZoneButton.addTarget(self, action: #selector(timeZoneTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    private func configureSelectionButton(_ button: UIButton, title: String, hint: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 12
        configuration.titleAlignment = .leading
        configuration.baseForegroundColor = ShiftLedgerColors.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 16,
            bottom: 12,
            trailing: 16
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.headline
            transformedAttributes.foregroundColor = ShiftLedgerColors.textPrimary
            return transformedAttributes
        }
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.callout
            transformedAttributes.foregroundColor = ShiftLedgerColors.textSecondary
            return transformedAttributes
        }
        button.configuration = configuration
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityLabel = title
        button.accessibilityHint = hint
    }

    private func setSelectionValue(_ value: String, for button: UIButton) {
        guard var configuration = button.configuration else {
            return
        }

        configuration.subtitle = value
        button.configuration = configuration
        button.accessibilityValue = value
    }

    @objc private func nameTextChanged() {
        onNameChanged?(nameText)
    }

    @objc private func currencyTapped() {
        onCurrencyTapped?()
    }

    @objc private func timeZoneTapped() {
        onTimeZoneTapped?()
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
