import UIKit

final class RenameWorkTypeView: UIView {
    var onNameChanged: ((String) -> Void)?

    var nameText: String {
        get { nameTextField.text ?? "" }
        set { nameTextField.text = newValue }
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let nameTitleLabel = UILabel()
    private let nameTextField = UITextField()
    private let nameUnderline = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "renameWorkType.screen"
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        contentStack.axis = .vertical
        contentStack.alignment = .fill

        nameTitleLabel.text = RenameWorkTypeStrings.nameTitle
        nameTitleLabel.font = ShiftLedgerTypography.headline
        nameTitleLabel.textColor = ShiftLedgerColors.textPrimary
        nameTitleLabel.numberOfLines = 0
        nameTitleLabel.adjustsFontForContentSizeCategory = true
        nameTitleLabel.accessibilityTraits = .header

        nameTextField.font = ShiftLedgerTypography.body
        nameTextField.textColor = ShiftLedgerColors.textPrimary
        nameTextField.backgroundColor = .clear
        nameTextField.borderStyle = .none
        nameTextField.clearButtonMode = .whileEditing
        nameTextField.autocapitalizationType = .sentences
        nameTextField.autocorrectionType = .default
        nameTextField.returnKeyType = .done
        nameTextField.adjustsFontForContentSizeCategory = true
        nameTextField.accessibilityLabel = RenameWorkTypeStrings.nameTitle
        nameTextField.accessibilityHint = RenameWorkTypeStrings.nameAccessibilityHint
        nameTextField.accessibilityIdentifier = "renameWorkType.name"
        nameTextField.delegate = self

        nameUnderline.backgroundColor = ShiftLedgerColors.separator
        nameUnderline.isAccessibilityElement = false
    }

    private func configureHierarchy() {
        [scrollView, contentView, contentStack, nameTitleLabel, nameTextField,
         nameUnderline].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)
        [nameTitleLabel, nameTextField, nameUnderline].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(6, after: nameTitleLabel)
        contentStack.setCustomSpacing(8, after: nameTextField)
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
            nameUnderline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale)
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
    }
}

extension RenameWorkTypeView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
