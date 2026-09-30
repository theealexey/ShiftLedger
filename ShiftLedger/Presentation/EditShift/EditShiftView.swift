import UIKit

final class EditShiftView: UIView {
    var onDeleteTapped: (() -> Void)?

    let shiftFormView = ShiftFormView(
        identifiers: ShiftFormIdentifiers(prefix: "editShift")
    )

    private let footerView = UIView()
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setDeleteEnabled(_ isEnabled: Bool) {
        deleteButton.isEnabled = isEnabled
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        footerView.backgroundColor = ShiftLedgerColors.backgroundPrimary

        var configuration = UIButton.Configuration.plain()
        configuration.title = EditShiftStrings.delete
        configuration.baseForegroundColor = ShiftLedgerColors.statusNegative
        deleteButton.configuration = configuration
        deleteButton.titleLabel?.font = ShiftLedgerTypography.button
        deleteButton.titleLabel?.adjustsFontForContentSizeCategory = true
        deleteButton.titleLabel?.numberOfLines = 0
        deleteButton.titleLabel?.lineBreakMode = .byWordWrapping
        deleteButton.titleLabel?.textAlignment = .center
        deleteButton.accessibilityLabel = EditShiftStrings.delete
        deleteButton.accessibilityIdentifier = "editShift.delete"
    }

    private func configureHierarchy() {
        [shiftFormView, footerView, deleteButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        addSubview(shiftFormView)
        addSubview(footerView)
        footerView.addSubview(deleteButton)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            shiftFormView.topAnchor.constraint(equalTo: topAnchor),
            shiftFormView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shiftFormView.trailingAnchor.constraint(equalTo: trailingAnchor),
            shiftFormView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

            footerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            deleteButton.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
            deleteButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 24),
            deleteButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -24),
            deleteButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -16),
            deleteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteraction() {
        deleteButton.addAction(
            UIAction { [weak self] _ in self?.onDeleteTapped?() },
            for: .touchUpInside
        )
    }
}
