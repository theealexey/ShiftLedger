import UIKit

final class ActualGrossEntryView: UIView {
    var onAmountChanged: ((String) -> Void)?
    var onCompareTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let questionLabel = UILabel()
    private let supportingLabel = UILabel()
    private let inputStack = UIStackView()
    private let amountLabel = UILabel()
    private let amountRow = UIStackView()
    private let amountTextField = UITextField()
    private let currencyLabel = UILabel()
    private let inputUnderline = UIView()
    private let validationLabel = UILabel()
    private let compareButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(
        amountText: String,
        currencyCode: String,
        canCompare: Bool,
        validationMessage: String?
    ) {
        if amountTextField.text != amountText {
            amountTextField.text = amountText
        }
        currencyLabel.text = currencyCode
        currencyLabel.accessibilityLabel = currencyCode
        compareButton.isEnabled = canCompare
        validationLabel.text = validationMessage
        validationLabel.isHidden = validationMessage == nil
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "actualGrossEntry.screen"
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 16

        configureLabel(
            questionLabel,
            text: ActualGrossEntryStrings.question,
            font: ShiftLedgerTypography.onboardingQuestion,
            color: ShiftLedgerColors.textPrimary
        )
        questionLabel.accessibilityTraits = .header
        questionLabel.accessibilityIdentifier = "actualGrossEntry.question"

        configureLabel(
            supportingLabel,
            text: ActualGrossEntryStrings.supporting,
            font: ShiftLedgerTypography.body,
            color: ShiftLedgerColors.textSecondary
        )
        supportingLabel.accessibilityIdentifier = "actualGrossEntry.supporting"

        inputStack.axis = .vertical
        inputStack.spacing = 8

        configureLabel(
            amountLabel,
            text: ActualGrossEntryStrings.amount,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textPrimary
        )
        amountLabel.accessibilityIdentifier = "actualGrossEntry.amount.label"

        amountRow.axis = .horizontal
        amountRow.alignment = .firstBaseline
        amountRow.spacing = 12

        amountTextField.font = ShiftLedgerTypography.basePayAmount
        amountTextField.textColor = ShiftLedgerColors.textPrimary
        amountTextField.backgroundColor = .clear
        amountTextField.borderStyle = .none
        amountTextField.keyboardType = .decimalPad
        amountTextField.textAlignment = .natural
        amountTextField.adjustsFontForContentSizeCategory = true
        amountTextField.textContentType = nil
        amountTextField.accessibilityLabel = ActualGrossEntryStrings.amount
        amountTextField.accessibilityIdentifier = "actualGrossEntry.amount.input"

        configureLabel(
            currencyLabel,
            text: nil,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textSecondary
        )
        currencyLabel.numberOfLines = 1
        currencyLabel.accessibilityIdentifier = "actualGrossEntry.currency"
        currencyLabel.setContentHuggingPriority(.required, for: .horizontal)
        currencyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        inputUnderline.backgroundColor = ShiftLedgerColors.separator

        configureLabel(
            validationLabel,
            text: nil,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.statusNegative
        )
        validationLabel.accessibilityIdentifier = "actualGrossEntry.validation"
        validationLabel.isHidden = true

        var configuration = UIButton.Configuration.filled()
        configuration.title = ActualGrossEntryStrings.compare
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        compareButton.configuration = configuration
        compareButton.titleLabel?.font = ShiftLedgerTypography.button
        compareButton.titleLabel?.adjustsFontForContentSizeCategory = true
        compareButton.accessibilityLabel = ActualGrossEntryStrings.compare
        compareButton.accessibilityIdentifier = "actualGrossEntry.compare"
    }

    private func configureHierarchy() {
        [scrollView, contentView, contentStack, inputStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        [questionLabel, supportingLabel, inputStack, validationLabel, compareButton]
            .forEach(contentStack.addArrangedSubview)
        [amountLabel, amountRow, inputUnderline].forEach(inputStack.addArrangedSubview)
        [amountTextField, currencyLabel].forEach(amountRow.addArrangedSubview)

        contentStack.setCustomSpacing(24, after: supportingLabel)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            amountTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            inputUnderline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale),
            compareButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func configureInteractions() {
        amountTextField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        amountTextField.addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        amountTextField.addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)
        compareButton.addAction(UIAction { [weak self] _ in
            self?.onCompareTapped?()
        }, for: .touchUpInside)
    }

    private func configureLabel(
        _ label: UILabel,
        text: String?,
        font: UIFont,
        color: UIColor
    ) {
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    @objc private func amountChanged() {
        onAmountChanged?(amountTextField.text ?? "")
    }

    @objc private func editingDidBegin() {
        inputUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
    }

    @objc private func editingDidEnd() {
        inputUnderline.backgroundColor = ShiftLedgerColors.separator
    }
}
