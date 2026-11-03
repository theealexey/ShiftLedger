import UIKit

final class EditShiftView: UIView {
    var onDeleteTapped: (() -> Void)?

    let shiftFormView = ShiftFormView(
        identifiers: ShiftFormIdentifiers(prefix: "editShift")
    )

    private let footerView = UIView()
    private let deleteButton = UIButton(type: .system)
    private let headingLabel = UILabel()
    private var fixedFooterConstraints: [NSLayoutConstraint] = []
    private var scrollingFormConstraint: NSLayoutConstraint?
    private var buttonLeadingConstraint: NSLayoutConstraint?
    private var buttonTrailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteraction()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.updateAccessibilityLayout()
        }
        updateAccessibilityLayout()
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
        headingLabel.text = EditShiftStrings.title
        headingLabel.font = ShiftLedgerTypography.headline
        headingLabel.textColor = ShiftLedgerColors.textPrimary
        headingLabel.numberOfLines = 0
        headingLabel.adjustsFontForContentSizeCategory = true
        headingLabel.accessibilityTraits = .header
        headingLabel.accessibilityIdentifier = "editShift.heading"

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
        fixedFooterConstraints = [
            shiftFormView.bottomAnchor.constraint(equalTo: footerView.topAnchor),
            footerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ]
        scrollingFormConstraint = shiftFormView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        buttonLeadingConstraint = deleteButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 24)
        buttonTrailingConstraint = deleteButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -24)
        NSLayoutConstraint.activate([
            shiftFormView.topAnchor.constraint(equalTo: topAnchor),
            shiftFormView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shiftFormView.trailingAnchor.constraint(equalTo: trailingAnchor),
            deleteButton.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
            deleteButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -16),
            deleteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        buttonLeadingConstraint?.isActive = true
        buttonTrailingConstraint?.isActive = true
        NSLayoutConstraint.activate(fixedFooterConstraints)
    }

    private func updateAccessibilityLayout() {
        let scrolling = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(fixedFooterConstraints)
        scrollingFormConstraint?.isActive = false
        shiftFormView.setSupplementaryViews(header: nil, footer: nil)
        if scrolling {
            footerView.removeFromSuperview()
            shiftFormView.setSupplementaryViews(header: headingLabel, footer: footerView)
            scrollingFormConstraint?.isActive = true
        } else {
            addSubview(footerView)
            NSLayoutConstraint.activate(fixedFooterConstraints)
        }
        buttonLeadingConstraint?.constant = scrolling ? 0 : 24
        buttonTrailingConstraint?.constant = scrolling ? 0 : -24
    }

    private func configureInteraction() {
        deleteButton.addAction(
            UIAction { [weak self] _ in self?.onDeleteTapped?() },
            for: .touchUpInside
        )
    }
}
