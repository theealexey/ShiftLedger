import UIKit

final class JobSetupViewController: UIViewController {
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func bindView() {
        jobSetupView.onBasePayAmountChanged = { [weak self] text in
            guard let self else {
                return
            }

            viewModel.updateBasePayAmountText(text)
            jobSetupView.setContinueEnabled(viewModel.canContinue)
        }
        jobSetupView.onBasePayBasisSelected = { [weak self] basis in
            guard let self else { return }
            viewModel.selectBasePayBasis(basis)
            render()
        }
        jobSetupView.onCurrencyTapped = { [weak self] in
            self?.showCurrencySelection()
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
        jobSetupView.basePayAmountText = draft.basePayAmountText
        jobSetupView.setBasePayBasis(draft.basePayBasis)
        jobSetupView.setCurrencyCode(draft.currencyCode)
        jobSetupView.setContinueEnabled(viewModel.canContinue)
    }

    private func showCurrencySelection() {
        let selectionViewController = CurrencySelectionViewController(
            currentCurrencyCode: viewModel.draft.currencyCode
        ) { [weak self] code in
            guard let self, viewModel.selectCurrency(code: code) else {
                return
            }

            render()
        }

        if let navigationController {
            navigationController.pushViewController(selectionViewController, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: selectionViewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        }
    }
}
