import UIKit

final class ActualGrossEntryViewController: UIViewController {
    var onContinue: ((ActualGross) -> Void)?

    private let viewModel: ActualGrossEntryViewModel
    private let currencyCode: String
    private let actualGrossEntryView = ActualGrossEntryView(frame: .zero)

    init(viewModel: ActualGrossEntryViewModel, currencyCode: String) {
        self.viewModel = viewModel
        self.currencyCode = currencyCode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = actualGrossEntryView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ActualGrossEntryStrings.title
        bindView()
        render()
    }

    private func bindView() {
        actualGrossEntryView.onAmountChanged = { [weak self] text in
            self?.viewModel.updateAmountText(text)
            self?.render()
        }
        actualGrossEntryView.onCompareTapped = { [weak self] in
            self?.compare()
        }
    }

    private func render() {
        let canContinue = viewModel.canContinue
        let validationMessage = viewModel.amountText.isEmpty || canContinue
            ? nil
            : ActualGrossEntryStrings.invalidAmount

        actualGrossEntryView.render(
            amountText: viewModel.amountText,
            currencyCode: currencyCode,
            canCompare: canContinue,
            validationMessage: validationMessage
        )
    }

    private func compare() {
        switch viewModel.makeActualGross() {
        case let .success(actualGross):
            onContinue?(actualGross)
        case .failure:
            render()
        }
    }
}
