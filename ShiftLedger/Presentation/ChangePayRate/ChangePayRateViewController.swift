import UIKit

final class ChangePayRateViewController: UIViewController {
    var onSaved: ((Job) -> Void)?

    private let viewModel: ChangePayRateViewModel
    private let payRateView: ChangePayRateView

    init(viewModel: ChangePayRateViewModel) {
        self.viewModel = viewModel
        payRateView = ChangePayRateView(
            workType: viewModel.workType,
            currencyCode: viewModel.currencyCode,
            timeZoneIdentifier: viewModel.timeZoneIdentifier,
            date: viewModel.effectiveDate
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = payRateView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ChangePayRateStrings.title
        navigationItem.largeTitleDisplayMode = .never
        let saveItem = UIBarButtonItem(
            title: ChangePayRateStrings.save,
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveItem.accessibilityIdentifier = "changePayRate.save"
        navigationItem.rightBarButtonItem = saveItem
        payRateView.onAmountChanged = { [weak self] value in
            self?.viewModel.updateAmountText(value)
            self?.render()
        }
        payRateView.onEffectiveDateChanged = { [weak self] value in
            self?.viewModel.updateEffectiveDate(value)
            self?.render()
        }
        render()
    }

    private func render() {
        payRateView.render(
            amountText: viewModel.amountText,
            effectiveDate: viewModel.effectiveDate,
            hasDuplicateDate: viewModel.hasDuplicateEffectiveDate
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
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: ChangePayRateStrings.errorTitle,
            message: ChangePayRateStrings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: ChangePayRateStrings.ok, style: .default))
        present(alert, animated: true)
    }
}
