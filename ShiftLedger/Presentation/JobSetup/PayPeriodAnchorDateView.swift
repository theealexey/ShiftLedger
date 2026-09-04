import UIKit

final class PayPeriodAnchorDateView: UIView {
    var onCancelTapped: (() -> Void)?
    var onDoneTapped: (() -> Void)?

    var selectedDate: Date {
        datePicker.date
    }

    private let datePicker = UIDatePicker()
    private let headerStack = UIStackView()
    private let headerTitleLabel = UILabel()
    private let cancelControl = HeaderActionControl(
        title: PayPeriodSetupStrings.cancel,
        color: ShiftLedgerColors.textSecondary
    )
    private let doneControl = HeaderActionControl(
        title: PayPeriodSetupStrings.done,
        color: ShiftLedgerColors.accentPrimary
    )

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

    func configure(title: String?, date: Date?, timeZone: TimeZone) {
        headerTitleLabel.text = title
        datePicker.timeZone = timeZone

        if let date {
            datePicker.date = date
        }
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        tintColor = ShiftLedgerColors.accentPrimary

        headerTitleLabel.font = ShiftLedgerTypography.headline
        headerTitleLabel.textColor = ShiftLedgerColors.textPrimary
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.adjustsFontForContentSizeCategory = true
        headerTitleLabel.numberOfLines = 1

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.tintColor = ShiftLedgerColors.accentPrimary
    }

    private func configureSubviews() {
        [headerStack, datePicker].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        headerStack.addArrangedSubview(cancelControl)
        headerStack.addArrangedSubview(headerTitleLabel)
        headerStack.addArrangedSubview(doneControl)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            cancelControl.widthAnchor.constraint(equalToConstant: 72),
            doneControl.widthAnchor.constraint(equalTo: cancelControl.widthAnchor),
            cancelControl.heightAnchor.constraint(equalToConstant: 44),
            doneControl.heightAnchor.constraint(equalTo: cancelControl.heightAnchor),

            headerStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: 44),

            datePicker.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            datePicker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])
    }

    private func configureInteractions() {
        cancelControl.addAction(UIAction { [weak self] _ in
            self?.onCancelTapped?()
        }, for: .touchUpInside)
        doneControl.addAction(UIAction { [weak self] _ in
            self?.onDoneTapped?()
        }, for: .touchUpInside)
    }
}

private final class HeaderActionControl: UIControl {
    private let titleLabel = UILabel()

    init(title: String, color: UIColor) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.textColor = color
        titleLabel.font = ShiftLedgerTypography.callout
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds.insetBy(dx: 4, dy: 0)
    }
}
