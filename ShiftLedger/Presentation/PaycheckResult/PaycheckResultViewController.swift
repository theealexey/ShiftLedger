import UIKit

final class PaycheckResultViewController: UIViewController {
    var onDone: (() -> Void)?

    private let comparison: PaycheckComparison
    private let currencyCode: String
    private let timeZoneIdentifier: String
    private let displayLocale: Locale
    private let paycheckResultView = PaycheckResultView(frame: .zero)

    init(
        comparison: PaycheckComparison,
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale
    ) {
        self.comparison = comparison
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayLocale = displayLocale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = paycheckResultView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = PaycheckResultStrings.title
        paycheckResultView.onDoneTapped = { [weak self] in
            self?.onDone?()
        }
        paycheckResultView.render(PaycheckResultFormatting.renderModel(
            comparison: comparison,
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            locale: displayLocale
        ))
    }
}
