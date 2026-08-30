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

    private func bindView() {
        jobSetupView.onNameChanged = { [weak self] name in
            guard let self else {
                return
            }

            viewModel.updateName(name)
            jobSetupView.setContinueEnabled(viewModel.canContinue)
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
        jobSetupView.nameText = draft.name
        jobSetupView.setContinueEnabled(viewModel.canContinue)
    }
}
