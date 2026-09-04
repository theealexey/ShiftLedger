import UIKit

final class TimeZoneSelectionViewController: UIViewController {
    private let currentIdentifier: String
    private let displayLocale: Locale
    private let onSelection: (String) -> Void
    private let timeZoneSelectionView: TimeZoneSelectionView
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
        self.timeZoneSelectionView = TimeZoneSelectionView(displayLocale: displayLocale)
        self.allIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()
        self.identifiers = allIdentifiers
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = timeZoneSelectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = TimeZoneSelectionStrings.title
        bindView()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    private func bindView() {
        timeZoneSelectionView.onSearchTextChanged = { [weak self] searchText in
            self?.filterIdentifiers(searchText)
        }
        timeZoneSelectionView.onTimeZoneSelected = { [weak self] identifier in
            guard let self else { return }

            onSelection(identifier)
            dismiss(animated: true)
        }
    }

    private func filterIdentifiers(_ searchText: String) {
        let query = normalized(searchText)
        guard query.isEmpty == false else {
            identifiers = allIdentifiers
            render()
            return
        }

        identifiers = allIdentifiers.filter { identifier in
            let displayName = TimeZoneDisplayName.value(for: identifier, locale: displayLocale)
            return normalized(identifier).contains(query) || normalized(displayName).contains(query)
        }
        render()
    }

    private func render() {
        timeZoneSelectionView.setIdentifiers(
            identifiers,
            selectedIdentifier: currentIdentifier
        )
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: displayLocale)
    }
}
