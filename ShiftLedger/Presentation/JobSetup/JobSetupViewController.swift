import UIKit

final class JobSetupViewController: UIViewController {
    var onCurrencySelectionRequested: (() -> Void)?
    var onContinue: ((JobSetupDraft) -> Void)?

    private let viewModel: JobSetupViewModel
    private let jobSetupView = JobSetupView(frame: .zero)

    init(viewModel: JobSetupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = jobSetupView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindView()
        render()
    }

    private func bindView() {
        jobSetupView.onHourlyRateChanged = { [weak self] text in
            guard let self else {
                return
            }

            viewModel.updateHourlyRateText(text)
            jobSetupView.setContinueEnabled(viewModel.canContinue)
        }
        jobSetupView.onCurrencyTapped = { [weak self] in
            self?.onCurrencySelectionRequested?()
        }
        jobSetupView.onContinueTapped = { [weak self] in
            guard let self, viewModel.canContinue else {
                return
            }

            onContinue?(viewModel.draft)
        }
    }

    private func render() {
        let draft = viewModel.draft
        jobSetupView.hourlyRateText = draft.hourlyRateText
        jobSetupView.setCurrencyCode(draft.currencyCode)
        jobSetupView.setContinueEnabled(viewModel.canContinue)
    }
}
