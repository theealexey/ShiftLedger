import UIKit

final class TimeZoneSelectionViewController: UIViewController {
    private let currentIdentifier: String
    private let displayLocale: Locale
    private let onSelection: (String) -> Void
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var identifiers: [String]
    private let allIdentifiers: [String]

    init(
        currentIdentifier: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale,
        onSelection: @escaping (String) -> Void
    ) {
        self.currentIdentifier = currentIdentifier
        self.displayLocale = displayLocale
        self.onSelection = onSelection
        allIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()
        identifiers = allIdentifiers
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = TimeZoneSelectionStrings.title
        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        view.tintColor = ShiftLedgerColors.accentPrimary
        configureSearch()
        configureTable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    private func configureSearch() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = TimeZoneSelectionStrings.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.searchTextField.backgroundColor = .clear
        searchBar.searchTextField.textColor = ShiftLedgerColors.textPrimary
        searchBar.searchTextField.font = ShiftLedgerTypography.body
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        searchBar.tintColor = ShiftLedgerColors.accentPrimary
        searchBar.delegate = self
        view.addSubview(searchBar)
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = ShiftLedgerColors.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: displayLocale)
    }
}

extension TimeZoneSelectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let query = normalized(searchText)
        guard query.isEmpty == false else {
            identifiers = allIdentifiers
            tableView.reloadData()
            return
        }

        identifiers = allIdentifiers.filter { identifier in
            let displayName = TimeZoneDisplayName.value(for: identifier, locale: displayLocale)
            return normalized(identifier).contains(query) || normalized(displayName).contains(query)
        }
        tableView.reloadData()
    }
}

extension TimeZoneSelectionViewController: UITableViewDataSource, UITableViewDelegate {
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
        cell.accessoryType = identifier == currentIdentifier ? .checkmark : .none
        cell.tintColor = ShiftLedgerColors.accentPrimary
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(content.text ?? ""), \(identifier)"
        cell.accessibilityTraits = identifier == currentIdentifier ? [.button, .selected] : .button
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelection(identifiers[indexPath.row])
        dismiss(animated: true)
    }
}
