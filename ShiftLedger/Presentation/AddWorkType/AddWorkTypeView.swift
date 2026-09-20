import UIKit

final class AddWorkTypeView: UIView {
    var onNameChanged: ((String) -> Void)?
    var onBasePayBasisSelected: ((BasePayBasis) -> Void)?
    var onAmountChanged: ((String) -> Void)?

    var nameText: String {
        get { nameTextField.text ?? "" }
        set { nameTextField.text = newValue }
    }

    var amountText: String {
        get { amountTextField.text ?? "" }
        set { amountTextField.text = newValue }
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let nameTitleLabel = UILabel()
    private let nameTextField = UITextField()
    private let nameUnderline = UIView()
    private let payBasisTitleLabel = UILabel()
    private let basisStack = UIStackView()
    private let hourlyControl = AddWorkTypeBasisControl(
        title: AddWorkTypeStrings.hourlyBasis,
        accessibilityIdentifier: "addWorkType.basis.hourly"
    )
    private let fixedPerShiftControl = AddWorkTypeBasisControl(
        title: AddWorkTypeStrings.fixedPerShiftBasis,
        accessibilityIdentifier: "addWorkType.basis.fixedPerShift"
    )
    private let amountSection = UIStackView()
    private let amountTitleLabel = UILabel()
    private let amountTextField = UITextField()
    private let amountUnderline = UIView()
    private let currencyRow = UIView()
    private let currencyTitleLabel = UILabel()
    private let currencyValueLabel = UILabel()
    private let currencySeparator = UIView()

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
        nameText: String,
        basePayBasis: BasePayBasis?,
        amountText: String,
        currencyCode: String
    ) {
        self.nameText = nameText
        self.amountText = amountText
        hourlyControl.isSelected = basePayBasis == .hourly
        fixedPerShiftControl.isSelected = basePayBasis == .fixedPerShift
        amountSection.isHidden = basePayBasis == nil
        amountTitleLabel.text = switch basePayBasis {
        case .hourly:
            AddWorkTypeStrings.hourlyRateTitle
        case .fixedPerShift:
            AddWorkTypeStrings.fixedPerShiftAmountTitle
        case nil:
            nil
        }
        amountTextField.accessibilityLabel = amountTitleLabel.text
        currencyValueLabel.text = currencyCode
        currencyRow.accessibilityValue = currencyCode
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "addWorkType.screen"

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        contentStack.axis = .vertical
        contentStack.alignment = .fill

        configureTitle(nameTitleLabel, text: AddWorkTypeStrings.nameTitle)
        nameTextField.font = ShiftLedgerTypography.body
        nameTextField.textColor = ShiftLedgerColors.textPrimary
        nameTextField.backgroundColor = .clear
        nameTextField.borderStyle = .none
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.autocapitalizationType = .sentences
        nameTextField.autocorrectionType = .default
        nameTextField.returnKeyType = .done
        nameTextField.adjustsFontForContentSizeCategory = true
        nameTextField.placeholder = AddWorkTypeStrings.namePlaceholder
        nameTextField.accessibilityLabel = AddWorkTypeStrings.nameTitle
        nameTextField.accessibilityHint = AddWorkTypeStrings.nameAccessibilityHint
        nameTextField.accessibilityIdentifier = "addWorkType.name"
        nameTextField.delegate = self

        nameUnderline.backgroundColor = ShiftLedgerColors.separator
        nameUnderline.isAccessibilityElement = false

        configureTitle(payBasisTitleLabel, text: AddWorkTypeStrings.payBasisTitle)
        basisStack.axis = .vertical
        basisStack.spacing = 12

        amountSection.axis = .vertical
        amountSection.isHidden = true
        configureTitle(amountTitleLabel, text: nil)
        amountTitleLabel.accessibilityIdentifier = "addWorkType.amount.title"

        amountTextField.font = ShiftLedgerTypography.basePayAmount
        amountTextField.textColor = ShiftLedgerColors.textPrimary
        amountTextField.backgroundColor = .clear
        amountTextField.borderStyle = .none
        amountTextField.keyboardType = .decimalPad
        amountTextField.adjustsFontForContentSizeCategory = true
        amountTextField.accessibilityHint = AddWorkTypeStrings.amountAccessibilityHint
        amountTextField.accessibilityIdentifier = "addWorkType.amount"
        amountTextField.delegate = self

        amountUnderline.backgroundColor = ShiftLedgerColors.separator
        amountUnderline.isAccessibilityElement = false

        currencyTitleLabel.text = AddWorkTypeStrings.currencyTitle
        currencyTitleLabel.font = ShiftLedgerTypography.body
        currencyTitleLabel.textColor = ShiftLedgerColors.textPrimary
        currencyTitleLabel.numberOfLines = 0
        currencyTitleLabel.adjustsFontForContentSizeCategory = true

        currencyValueLabel.font = ShiftLedgerTypography.callout
        currencyValueLabel.textColor = ShiftLedgerColors.textSecondary
        currencyValueLabel.numberOfLines = 0
        currencyValueLabel.textAlignment = .right
        currencyValueLabel.adjustsFontForContentSizeCategory = true

        currencyRow.isAccessibilityElement = true
        currencyRow.accessibilityLabel = AddWorkTypeStrings.currencyTitle
        currencyRow.accessibilityIdentifier = "addWorkType.currency"
        currencySeparator.backgroundColor = ShiftLedgerColors.separator
        currencySeparator.isAccessibilityElement = false
    }

    private func configureTitle(_ label: UILabel, text: String?) {
        label.text = text
        label.font = ShiftLedgerTypography.headline
        label.textColor = ShiftLedgerColors.textPrimary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
    }

    private func configureHierarchy() {
        [scrollView, contentView, contentStack, nameTitleLabel, nameTextField,
         nameUnderline, payBasisTitleLabel, basisStack, hourlyControl,
         fixedPerShiftControl, amountSection, amountTitleLabel, amountTextField,
         amountUnderline, currencyRow, currencyTitleLabel, currencyValueLabel,
         currencySeparator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        basisStack.addArrangedSubview(hourlyControl)
        basisStack.addArrangedSubview(fixedPerShiftControl)
        amountSection.addArrangedSubview(amountTitleLabel)
        amountSection.addArrangedSubview(amountTextField)
        amountSection.addArrangedSubview(amountUnderline)
        amountSection.setCustomSpacing(6, after: amountTitleLabel)
        amountSection.setCustomSpacing(12, after: amountTextField)

        [currencyTitleLabel, currencyValueLabel, currencySeparator].forEach(currencyRow.addSubview)

        [nameTitleLabel, nameTextField, nameUnderline, payBasisTitleLabel,
         basisStack, amountSection, currencyRow].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(6, after: nameTitleLabel)
        contentStack.setCustomSpacing(8, after: nameTextField)
        contentStack.setCustomSpacing(28, after: nameUnderline)
        contentStack.setCustomSpacing(12, after: payBasisTitleLabel)
        contentStack.setCustomSpacing(24, after: basisStack)
        contentStack.setCustomSpacing(18, after: amountSection)
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

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            nameUnderline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale),
            amountTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            amountUnderline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale),
            currencyRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            currencyTitleLabel.leadingAnchor.constraint(equalTo: currencyRow.leadingAnchor),
            currencyTitleLabel.topAnchor.constraint(equalTo: currencyRow.topAnchor, constant: 8),
            currencyTitleLabel.bottomAnchor.constraint(equalTo: currencyRow.bottomAnchor, constant: -8),
            currencyTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: currencyValueLabel.leadingAnchor, constant: -12),
            currencyValueLabel.trailingAnchor.constraint(equalTo: currencyRow.trailingAnchor),
            currencyValueLabel.topAnchor.constraint(greaterThanOrEqualTo: currencyRow.topAnchor, constant: 8),
            currencyValueLabel.bottomAnchor.constraint(lessThanOrEqualTo: currencyRow.bottomAnchor, constant: -8),
            currencyValueLabel.centerYAnchor.constraint(equalTo: currencyRow.centerYAnchor),
            currencySeparator.leadingAnchor.constraint(equalTo: currencyRow.leadingAnchor),
            currencySeparator.trailingAnchor.constraint(equalTo: currencyRow.trailingAnchor),
            currencySeparator.bottomAnchor.constraint(equalTo: currencyRow.bottomAnchor),
            currencySeparator.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale)
        ])
    }

    private func configureInteractions() {
        nameTextField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onNameChanged?(nameText)
        }, for: .editingChanged)
        nameTextField.addAction(UIAction { [weak self] _ in
            self?.nameUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
        }, for: .editingDidBegin)
        nameTextField.addAction(UIAction { [weak self] _ in
            self?.nameUnderline.backgroundColor = ShiftLedgerColors.separator
        }, for: .editingDidEnd)
        amountTextField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onAmountChanged?(amountText)
        }, for: .editingChanged)
        amountTextField.addAction(UIAction { [weak self] _ in
            self?.amountUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
        }, for: .editingDidBegin)
        amountTextField.addAction(UIAction { [weak self] _ in
            self?.amountUnderline.backgroundColor = ShiftLedgerColors.separator
        }, for: .editingDidEnd)
        hourlyControl.onTapped = { [weak self] in self?.onBasePayBasisSelected?(.hourly) }
        fixedPerShiftControl.onTapped = { [weak self] in self?.onBasePayBasisSelected?(.fixedPerShift) }
    }
}

extension AddWorkTypeView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class AddWorkTypeBasisControl: UIControl {
    var onTapped: (() -> Void)?

    override var isSelected: Bool {
        didSet { renderSelection() }
    }

    private let markerLabel = UILabel()
    private let titleLabel = UILabel()

    init(title: String, accessibilityIdentifier: String) {
        super.init(frame: .zero)
        markerLabel.font = ShiftLedgerTypography.body
        markerLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = title
        titleLabel.font = ShiftLedgerTypography.body
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        [markerLabel, titleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        NSLayoutConstraint.activate([
            markerLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            markerLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            markerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: markerLabel.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        isAccessibilityElement = true
        accessibilityLabel = title
        self.accessibilityIdentifier = accessibilityIdentifier
        addAction(UIAction { [weak self] _ in self?.onTapped?() }, for: .touchUpInside)
        renderSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func renderSelection() {
        markerLabel.text = isSelected ? "●" : "○"
        let color = isSelected ? ShiftLedgerColors.accentPrimary : ShiftLedgerColors.textPrimary
        markerLabel.textColor = color
        titleLabel.textColor = color
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
