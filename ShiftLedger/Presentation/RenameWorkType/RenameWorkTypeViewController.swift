import UIKit

final class RenameWorkTypeViewController: UIViewController {
    var onSaved: ((Job) -> Void)?

    private let viewModel: RenameWorkTypeViewModel
    private let renameView = RenameWorkTypeView(frame: .zero)

    init(viewModel: RenameWorkTypeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = renameView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = RenameWorkTypeStrings.title
        navigationItem.largeTitleDisplayMode = .never
        let saveItem = UIBarButtonItem(
            title: RenameWorkTypeStrings.save,
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveItem.accessibilityIdentifier = "renameWorkType.save"
        navigationItem.rightBarButtonItem = saveItem
        renameView.onNameChanged = { [weak self] value in
            self?.viewModel.updateNameText(value)
            self?.render()
        }
        render()
    }

    private func render() {
        renameView.nameText = viewModel.nameText
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canSave
    }

    @objc private func saveTapped() {
        switch viewModel.save() {
        case let .saved(job):
            onSaved?(job)
        case .failed:
            presentSaveError()
        case .invalid, .unchanged, .ignored:
            break
        }
        render()
    }

    private func presentSaveError() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: RenameWorkTypeStrings.errorTitle,
            message: RenameWorkTypeStrings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: RenameWorkTypeStrings.ok, style: .default))
        present(alert, animated: true)
    }
}
