import UIKit

final class PayRateHistoryViewController: UIViewController {
    private let viewModel: PayRateHistoryViewModel
    private let historyView = PayRateHistoryView()

    init(viewModel: PayRateHistoryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = historyView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = PayRateHistoryStrings.title
        navigationItem.largeTitleDisplayMode = .never
        historyView.render(workTypeName: viewModel.workTypeName, rows: viewModel.rows)
    }
}
