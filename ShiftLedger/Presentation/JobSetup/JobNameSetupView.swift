import UIKit

final class JobNameSetupView: UIView, UITextFieldDelegate {
    var onBackTapped: (() -> Void)?
    var onNameChanged: ((String) -> Void)?
    var onContinueTapped: (() -> Void)?

    var nameText: String {
        get { nameTextField.text ?? "" }
        set { nameTextField.text = newValue }
    }

    private let scaffold = JobSetupScaffoldView(
        brandText: nil,
        stepIndicator: JobSetupStrings.step3StepIndicator,
        stepAccessibilityLabel: JobSetupStrings.step3StepIndicatorAccessibilityLabel,
        activeStep: 3,
        backAccessibilityLabel: JobSetupStrings.back
    )
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let nameTextField = UITextField()
    private let nameUnderline = UIView()

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

    func setContinueEnabled(_ enabled: Bool) {
        scaffold.setContinueEnabled(enabled)
    }

    private func configureAppearance() {
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
    }

    private func configureSubviews() {
        [scaffold, questionLabel, subtitleLabel, nameTextField, nameUnderline].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scaffold)
        [questionLabel, subtitleLabel, nameTextField, nameUnderline].forEach(scaffold.contentView.addSubview)
    }

    private func configureLayout() {
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
            nameTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            nameTextField.leadingAnchor.constraint(equalTo: scaffold.contentView.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: scaffold.contentView.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            nameUnderline.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 8),
            nameUnderline.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            nameUnderline.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            nameUnderline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            scaffold.continueButton.topAnchor.constraint(greaterThanOrEqualTo: nameUnderline.bottomAnchor, constant: 44)
        ])
    }

    private func configureInteractions() {
        scaffold.onBackTapped = { [weak self] in self?.onBackTapped?() }
        scaffold.onContinueTapped = { [weak self] in self?.endEditing(true); self?.onContinueTapped?() }
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameTextField.addTarget(self, action: #selector(nameEditingDidBegin), for: .editingDidBegin)
        nameTextField.addTarget(self, action: #selector(nameEditingDidEnd), for: .editingDidEnd)
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

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
