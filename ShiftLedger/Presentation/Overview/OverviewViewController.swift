import UIKit

final class OverviewViewController: UIViewController {
    var onAddShift: (() -> Void)?
    var onCheckPaycheck: ((PayCalculationPeriod) -> Void)?

    private let viewModel: OverviewViewModel
    private let currencyCode: String
    private let timeZoneIdentifier: String
    private let displayLocale: Locale
    private let overviewView = OverviewView(frame: .zero)

    init(
        viewModel: OverviewViewModel,
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale
    ) {
        self.viewModel = viewModel
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayLocale = displayLocale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = overviewView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = OverviewStrings.title
        bindView()
        viewModel.load()
        render()
    }

    func reload() {
        viewModel.reload()
        render()
    }

    private func bindView() {
        overviewView.onPreviousPeriodTapped = { [weak self] in
            self?.viewModel.navigateToPreviousPeriod()
            self?.render()
        }
        overviewView.onNextPeriodTapped = { [weak self] in
            self?.viewModel.navigateToNextPeriod()
            self?.render()
        }
        overviewView.onAddShiftTapped = { [weak self] in
            self?.onAddShift?()
        }
        overviewView.onCheckPaycheckTapped = { [weak self] in
            self?.checkPaycheck()
        }
        overviewView.onRetryTapped = { [weak self] in
            self?.viewModel.load()
            self?.render()
        }
    }

    private func render() {
        switch viewModel.state {
        case .idle:
            overviewView.renderIdle()
        case let .failure(failure):
            renderFailure(failure)
        case let .content(content):
            renderContent(content)
        }
    }

    private func renderContent(_ content: OverviewViewModel.Content) {
        switch (content.selectedPeriod, content.expectedBreakdown) {
        case (nil, nil):
            overviewView.renderEmpty()
        case let (period?, breakdown?):
            guard let periodText = formattedPeriod(period, breakdown: breakdown) else {
                renderFailure(.calculation)
                return
            }

            overviewView.renderContent(
                expectedGross: OverviewFormatting.currency(
                    breakdown.expectedGross,
                    currencyCode: currencyCode,
                    locale: displayLocale
                ),
                period: periodText,
                shiftCount: breakdown.shiftBreakdowns.count,
                canNavigatePrevious: content.canNavigatePrevious,
                canNavigateNext: content.canNavigateNext,
                canCheckPaycheck: true
            )
        default:
            renderFailure(.calculation)
        }
    }

    private func renderFailure(_ failure: OverviewViewModel.Failure) {
        switch failure {
        case .loading:
            overviewView.renderFailure(
                title: OverviewStrings.loadingErrorTitle,
                message: OverviewStrings.loadingErrorMessage
            )
        case .calculation:
            overviewView.renderFailure(
                title: OverviewStrings.calculationErrorTitle,
                message: OverviewStrings.calculationErrorMessage
            )
        }
    }

    private func formattedPeriod(
        _ period: PayCalculationPeriod,
        breakdown: ExpectedGrossBreakdown
    ) -> String? {
        switch period {
        case let .scheduled(payPeriod):
            return OverviewFormatting.scheduledPeriod(
                payPeriod,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: displayLocale
            )
        case let .perShift(shiftID):
            guard
                breakdown.shiftBreakdowns.count == 1,
                let shift = breakdown.shiftBreakdowns.first?.shift,
                shift.id == shiftID
            else {
                return nil
            }

            return OverviewFormatting.perShiftPeriod(
                shift,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: displayLocale
            )
        }
    }

    private func checkPaycheck() {
        guard
            case let .content(content) = viewModel.state,
            let period = content.selectedPeriod,
            content.expectedBreakdown != nil
        else {
            return
        }

        onCheckPaycheck?(period)
    }
}
