import UIKit

final class TimeZoneSelectionView: UIView {
    var onSearchTextChanged: ((String) -> Void)?
    var onTimeZoneSelected: ((String) -> Void)?

    private let displayLocale: Locale
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var identifiers: [String] = []
    private var selectedIdentifier = ""

    init(displayLocale: Locale, frame: CGRect = .zero) {
        self.displayLocale = displayLocale
        super.init(frame: frame)

        configureAppearance()
        configureSubviews()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setIdentifiers(_ identifiers: [String], selectedIdentifier: String) {
        self.identifiers = identifiers
        self.selectedIdentifier = selectedIdentifier
        tableView.reloadData()
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        tintColor = ShiftLedgerColors.accentPrimary

        searchBar.placeholder = TimeZoneSelectionStrings.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.searchTextField.backgroundColor = .clear
        searchBar.searchTextField.textColor = ShiftLedgerColors.textPrimary
        searchBar.searchTextField.font = ShiftLedgerTypography.body
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        searchBar.tintColor = ShiftLedgerColors.accentPrimary
        searchBar.delegate = self

        tableView.backgroundColor = .clear
        tableView.separatorColor = ShiftLedgerColors.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func configureSubviews() {
        [searchBar, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

extension TimeZoneSelectionView: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        onSearchTextChanged?(searchText)
    }
}

extension TimeZoneSelectionView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        identifiers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TimeZoneCell") ?? UITableViewCell(style: .default, reuseIdentifier: "TimeZoneCell")
        let identifier = identifiers[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = TimeZoneDisplayName.value(for: identifier, locale: displayLocale)
        content.secondaryText = identifier
        content.textProperties.font = ShiftLedgerTypography.headline
        content.textProperties.color = ShiftLedgerColors.textPrimary
        content.secondaryTextProperties.font = ShiftLedgerTypography.callout
        content.secondaryTextProperties.color = ShiftLedgerColors.textSecondary
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24)
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.accessoryType = identifier == selectedIdentifier ? .checkmark : .none
        cell.tintColor = ShiftLedgerColors.accentPrimary
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(content.text ?? ""), \(identifier)"
        cell.accessibilityTraits = identifier == selectedIdentifier ? [.button, .selected] : .button
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onTimeZoneSelected?(identifiers[indexPath.row])
    }
}
