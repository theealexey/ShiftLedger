import UIKit

final class AddWorkTypeViewController: UIViewController {
    var onSaved: ((Job) -> Void)?

    private let viewModel: AddWorkTypeViewModel
    private let addWorkTypeView = AddWorkTypeView(frame: .zero)

    init(viewModel: AddWorkTypeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = addWorkTypeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AddWorkTypeStrings.title
        navigationItem.largeTitleDisplayMode = .never
        let saveItem = UIBarButtonItem(
            title: AddWorkTypeStrings.save,
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveItem.accessibilityIdentifier = "addWorkType.save"
        navigationItem.rightBarButtonItem = saveItem
        bindView()
        render()
    }

    private func bindView() {
        addWorkTypeView.onNameChanged = { [weak self] value in
            self?.viewModel.updateNameText(value)
            self?.render()
        }
        addWorkTypeView.onBasePayBasisSelected = { [weak self] basis in
            self?.viewModel.selectBasePayBasis(basis)
            self?.render()
        }
        addWorkTypeView.onAmountChanged = { [weak self] value in
            self?.viewModel.updateAmountText(value)
            self?.render()
        }
    }

    private func render() {
        addWorkTypeView.render(
            nameText: viewModel.nameText,
            basePayBasis: viewModel.basePayBasis,
            amountText: viewModel.amountText,
            currencyCode: viewModel.currencyCode
        )
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canSave
    }

    @objc private func saveTapped() {
        switch viewModel.save() {
        case let .saved(job):
            onSaved?(job)
        case .failed:
            presentSaveError()
        case .invalid, .ignored:
            break
        }
        render()
    }

    private func presentSaveError() {
        guard presentedViewController == nil else {
            return
        }
        let alert = UIAlertController(
            title: AddWorkTypeStrings.errorTitle,
            message: AddWorkTypeStrings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AddWorkTypeStrings.ok, style: .default))
        present(alert, animated: true)
    }
}
