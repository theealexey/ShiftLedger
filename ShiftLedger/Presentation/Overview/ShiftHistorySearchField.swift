import UIKit

final class ShiftHistorySearchField: UISearchTextField, UITextFieldDelegate {
    var onTextChanged: ((String) -> Void)?
    var onSettings: (() -> Void)?
    var onSort: ((ShiftHistoryQuery.Sort) -> Void)?

    private let accessories = UIView()
    private let clear = UIButton(type: .system)
    private let options = UIButton(type: .system)
    private var renderedMenu: (groups: Int, sort: ShiftHistoryQuery.Sort)?
    private let targetSize: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "shiftHistory.search"
        accessibilityLabel = ShiftHistoryStrings.searchLabel
        accessibilityHint = ShiftHistoryStrings.searchHint
        attributedPlaceholder = NSAttributedString(
            string: ShiftHistoryStrings.searchPlaceholder,
            attributes: [.foregroundColor: ShiftLedgerColors.textSecondary]
        )
        backgroundColor = ShiftLedgerColors.surfacePrimary
        tintColor = ShiftLedgerColors.accentPrimary
        textColor = ShiftLedgerColors.textPrimary
        font = .preferredFont(forTextStyle: .body)
        adjustsFontForContentSizeCategory = true
        adjustsFontSizeToFitWidth = false
        returnKeyType = .search
        delegate = self

        let magnifier = UIImageView(image: UIImage(
            systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18)
        ))
        magnifier.frame.size = CGSize(width: 32, height: targetSize)
        magnifier.contentMode = .center
        magnifier.tintColor = ShiftLedgerColors.textSecondary
        magnifier.isAccessibilityElement = false
        leftView = magnifier
        leftViewMode = .always

        clearButtonMode = .never
        clear.accessibilityIdentifier = "shiftHistory.clearSearch"
        clear.accessibilityLabel = ShiftHistoryStrings.clearSearch
        var clearConfiguration = UIButton.Configuration.plain()
        clearConfiguration.image = UIImage(systemName: "xmark.circle.fill")
        clearConfiguration.preferredSymbolConfigurationForImage = .init(pointSize: 18)
        clearConfiguration.baseForegroundColor = ShiftLedgerColors.textSecondary
        clearConfiguration.contentInsets = .zero
        clear.configuration = clearConfiguration
        clear.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            text = ""
            sendActions(for: .editingChanged)
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .layoutChanged, argument: self)
            }
        }, for: .touchUpInside)

        options.accessibilityIdentifier = "shiftHistory.searchOptions"
        options.accessibilityLabel = ShiftHistoryStrings.options
        options.showsMenuAsPrimaryAction = true
        accessories.addSubview(clear)
        accessories.addSubview(options)
        rightView = accessories
        rightViewMode = .always

        addTarget(self, action: #selector(textChanged), for: .editingChanged)
        let minimumHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: targetSize)
        minimumHeight.priority = UILayoutPriority(999)
        minimumHeight.isActive = true
        updateAccessories()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (field: Self, _) in
            if let menu = field.renderedMenu {
                field.updateMenu(groups: menu.groups, sort: menu.sort)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func render(_ query: ShiftHistoryQuery) {
        if text != query.searchText {
            text = query.searchText
            updateAccessories()
        }
        if renderedMenu?.groups != query.activeGroups || renderedMenu?.sort != query.sort {
            updateMenu(groups: query.activeGroups, sort: query.sort)
        }
    }

    @objc private func textChanged() {
        updateAccessories()
        guard markedTextRange == nil else { return }
        onTextChanged?(text ?? "")
    }

    private func updateAccessories() {
        let hasText = !(text ?? "").isEmpty
        clear.isHidden = !hasText
        accessories.frame.size = .init(width: hasText ? 2 * targetSize : targetSize, height: targetSize)
        clear.frame = .init(x: 0, y: 0, width: targetSize, height: targetSize)
        options.frame = .init(x: hasText ? targetSize : 0, y: 0, width: targetSize, height: targetSize)
        setNeedsLayout()
    }

    private func updateMenu(groups: Int, sort: ShiftHistoryQuery.Sort) {
        renderedMenu = (groups, sort)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: groups == 0
            ? "slider.horizontal.3" : "line.3.horizontal.decrease.circle.fill")
        configuration.preferredSymbolConfigurationForImage = .init(pointSize: 20)
        configuration.baseForegroundColor = groups == 0
            ? ShiftLedgerColors.textSecondary : ShiftLedgerColors.accentPrimary
        configuration.contentInsets = .zero
        options.configuration = configuration
        options.accessibilityValue = ShiftHistoryStrings.optionsValue(groups, sort: sort)
        let settings = UIAction(title: ShiftHistoryStrings.settings, subtitle: ShiftHistoryStrings.active(groups),
                                image: UIImage(systemName: "slider.horizontal.3")) { [weak self] _ in
            self?.onSettings?()
        }
        let choices = ShiftHistoryQuery.Sort.allCases.map { choice in
            UIAction(title: ShiftHistoryStrings.title(for: choice), state: choice == sort ? .on : .off) { [weak self] _ in
                self?.onSort?(choice)
            }
        }
        let sortTitle = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? ShiftHistoryStrings.sortCompact : ShiftHistoryStrings.sort
        options.menu = UIMenu(children: [
            settings, UIMenu(title: sortTitle, image: UIImage(systemName: "arrow.up.arrow.down"), children: choices)
        ])
    }

    func focusOptionsForAccessibility() {
        UIAccessibility.post(notification: .layoutChanged, argument: options)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
