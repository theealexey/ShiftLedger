import UIKit

final class CurrencySelectionView: UIView {
    var onCloseTapped: (() -> Void)?
    var onSearchTextChanged: ((String) -> Void)?
    var onCurrencySelected: ((String) -> Void)?

    private let closeButton = UIButton(type: .custom)
    private let titleLabel = UILabel()
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let noResultsLabel = UILabel()
    private var currencies: [CurrencySelectionItem] = []
    private var selectedCurrencyCode = ""

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureAppearance()
        configureSubviews()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setCurrencies(_ currencies: [CurrencySelectionItem], selectedCurrencyCode: String) {
        self.currencies = currencies
        self.selectedCurrencyCode = selectedCurrencyCode
        noResultsLabel.isHidden = currencies.isEmpty == false
        tableView.reloadData()
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = ShiftLedgerColors.textSecondary
        closeButton.backgroundColor = .clear
        closeButton.accessibilityLabel = CurrencySelectionStrings.close
        closeButton.addAction(UIAction { [weak self] _ in self?.onCloseTapped?() }, for: .primaryActionTriggered)

        titleLabel.text = CurrencySelectionStrings.title
        titleLabel.font = ShiftLedgerTypography.onboardingQuestion
        titleLabel.textColor = ShiftLedgerColors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        searchBar.placeholder = CurrencySelectionStrings.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.tintColor = ShiftLedgerColors.accentPrimary
        searchBar.searchTextField.backgroundColor = .clear
        searchBar.searchTextField.borderStyle = .none
        searchBar.searchTextField.textColor = ShiftLedgerColors.textPrimary
        searchBar.searchTextField.font = ShiftLedgerTypography.body
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        searchBar.delegate = self

        tableView.backgroundColor = .clear
        tableView.separatorColor = ShiftLedgerColors.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CurrencySelectionCell.self, forCellReuseIdentifier: CurrencySelectionCell.reuseIdentifier)

        noResultsLabel.text = CurrencySelectionStrings.noResults
        noResultsLabel.font = ShiftLedgerTypography.body
        noResultsLabel.textColor = ShiftLedgerColors.textSecondary
        noResultsLabel.textAlignment = .center
        noResultsLabel.numberOfLines = 0
        noResultsLabel.adjustsFontForContentSizeCategory = true
        noResultsLabel.isHidden = true
    }

    private func configureSubviews() {
        [closeButton, titleLabel, searchBar, tableView, noResultsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

            noResultsLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            noResultsLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            noResultsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            noResultsLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }
}

extension CurrencySelectionView: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        onSearchTextChanged?(searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        onSearchTextChanged?("")
    }
}

extension CurrencySelectionView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currencies.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: CurrencySelectionCell.reuseIdentifier,
            for: indexPath
        ) as? CurrencySelectionCell else {
            return UITableViewCell()
        }

        let currency = currencies[indexPath.row]
        cell.configure(currency: currency, isSelected: currency.code == selectedCurrencyCode)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onCurrencySelected?(currencies[indexPath.row].code)
    }
}

private final class CurrencySelectionCell: UITableViewCell {
    static let reuseIdentifier = "CurrencySelectionCell"

    func configure(currency: CurrencySelectionItem, isSelected: Bool) {
        var content = defaultContentConfiguration()
        content.text = currency.code
        content.textProperties.font = ShiftLedgerTypography.headline
        content.textProperties.color = ShiftLedgerColors.textPrimary
        content.secondaryText = currency.localizedName
        content.secondaryTextProperties.font = ShiftLedgerTypography.callout
        content.secondaryTextProperties.color = ShiftLedgerColors.textSecondary
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        contentConfiguration = content

        backgroundColor = .clear
        selectionStyle = .none
        accessoryType = isSelected ? .checkmark : .none
        tintColor = ShiftLedgerColors.accentPrimary
        isAccessibilityElement = true
        accessibilityLabel = "\(currency.code), \(currency.localizedName)"
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
