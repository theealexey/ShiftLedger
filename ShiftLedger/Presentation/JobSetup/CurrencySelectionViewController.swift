import UIKit

final class CurrencySelectionViewController: UIViewController {
    private let currentCurrencyCode: String
    private let allCurrencies: [CurrencySelectionItem]
    private let displayLocale: Locale
    private let onSelection: (String) -> Void
    private let currencySelectionView = CurrencySelectionView(frame: .zero)

    private var filteredCurrencies: [CurrencySelectionItem] {
        didSet {
            currencySelectionView.setCurrencies(filteredCurrencies, selectedCurrencyCode: currentCurrencyCode)
        }
    }

    init(
        currentCurrencyCode: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale,
        onSelection: @escaping (String) -> Void
    ) {
        self.currentCurrencyCode = currentCurrencyCode
        self.displayLocale = displayLocale
        allCurrencies = CurrencySelectionItem.available(displayLocale: displayLocale)
        filteredCurrencies = allCurrencies
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = currencySelectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationAppearance()
        bindView()
        currencySelectionView.setCurrencies(filteredCurrencies, selectedCurrencyCode: currentCurrencyCode)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: ShiftLedgerColors.accentPrimary]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }

    private func bindView() {
        currencySelectionView.onCloseTapped = { [weak self] in
            self?.closeSelection()
        }
        currencySelectionView.onSearchTextChanged = { [weak self] query in
            guard let self else {
                return
            }

            filteredCurrencies = CurrencySelectionItem.filtered(
                allCurrencies,
                query: query,
                locale: displayLocale
            )
        }
        currencySelectionView.onCurrencySelected = { [weak self] code in
            guard let self else {
                return
            }

            onSelection(code)
            closeSelection()
        }
    }

    private func closeSelection() {
        guard let navigationController else {
            dismiss(animated: true)
            return
        }

        if navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            navigationController.dismiss(animated: true)
        }
    }
}
