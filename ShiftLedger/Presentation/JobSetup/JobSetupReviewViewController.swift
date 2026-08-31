import UIKit

final class JobSetupReviewViewController: UIViewController {
    var onBack: (() -> Void)?
    var onFinished: ((Job) -> Void)?

    private let viewModel: JobSetupReviewViewModel
    private let displayLocale: Locale
    private let dateFormattingLocale: Locale
    private let saveJob: (Job) throws -> Void
    private let reviewView = JobSetupReviewView(frame: .zero)
    private var isSaving = false

    init(
        viewModel: JobSetupReviewViewModel,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale,
        dateFormattingLocale: Locale = .autoupdatingCurrent,
        saveJob: @escaping (Job) throws -> Void
    ) {
        self.viewModel = viewModel
        self.displayLocale = displayLocale
        self.dateFormattingLocale = dateFormattingLocale
        self.saveJob = saveJob
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = reviewView
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

    func start() {
        guard isSaving == false, viewModel.canFinish else {
            return
        }

        isSaving = true
        reviewView.setStartEnabled(false)

        do {
            let job = try viewModel.makeJob()
            try saveJob(job)
            onFinished?(job)
        } catch {
            isSaving = false
            reviewView.setStartEnabled(viewModel.canFinish)
            presentSaveError()
        }
    }

    private func bindView() {
        reviewView.onBackTapped = { [weak self] in self?.onBack?() }
        reviewView.onTimeZoneTapped = { [weak self] in self?.presentTimeZoneSelection() }
        reviewView.onStartTapped = { [weak self] in self?.start() }
    }

    private func render() {
        reviewView.render(
            basePayLabel: viewModel.basePayLabel,
            amountText: viewModel.amountText,
            currencyCode: viewModel.draft.currencyCode,
            payPeriodLabel: viewModel.payPeriodLabel,
            periodStartText: formattedPeriodStart,
            timeZoneText: TimeZoneDisplayName.value(
                for: viewModel.draft.timeZoneIdentifier,
                locale: displayLocale
            ),
            showsPeriodStart: viewModel.showsPeriodStart,
            canFinish: viewModel.canFinish
        )
    }

    private var formattedPeriodStart: String? {
        guard let anchorDate = viewModel.draft.payPeriodAnchorDate else {
            return nil
        }

        return JobSetupDateFormatting.string(
            for: anchorDate,
            timeZoneIdentifier: viewModel.draft.timeZoneIdentifier,
            locale: dateFormattingLocale
        )
    }

    private func presentTimeZoneSelection() {
        let controller = TimeZoneSelectionViewController(
            currentIdentifier: viewModel.draft.timeZoneIdentifier,
            displayLocale: displayLocale
        ) { [weak self] identifier in
            guard let self, viewModel.selectTimeZone(identifier: identifier) else {
                return
            }

            render()
        }

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func presentSaveError() {
        guard viewIfLoaded?.window != nil else {
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: JobSetupReviewStrings.saveError,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: JobSetupReviewStrings.ok, style: .default))
        present(alert, animated: true)
    }
}
