import UIKit

final class JobNameSetupViewController: UIViewController {
    var onBack: ((JobSetupDraft) -> Void)?
    var onContinue: ((JobSetupDraft) -> Void)?

    private let viewModel: JobNameSetupViewModel
    private let jobNameSetupView = JobNameSetupView(frame: .zero)

    init(viewModel: JobNameSetupViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = jobNameSetupView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindView()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func bindView() {
        jobNameSetupView.onBackTapped = { [weak self] in
            guard let self else {
                return
            }

            onBack?(viewModel.draft)
        }
        jobNameSetupView.onNameChanged = { [weak self] value in
            guard let self else {
                return
            }

            viewModel.updateName(value)
            jobNameSetupView.setContinueEnabled(viewModel.canContinue)
        }
        jobNameSetupView.onContinueTapped = { [weak self] in
            guard let self, viewModel.canContinue else {
                return
            }

            onContinue?(viewModel.draft)
        }
    }

    private func render() {
        jobNameSetupView.nameText = viewModel.draft.name
        jobNameSetupView.setContinueEnabled(viewModel.canContinue)
    }
}
