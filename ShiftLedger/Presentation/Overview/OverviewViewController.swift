import UIKit

final class OverviewViewController: UIViewController {
    private enum PresentationError: Error {
        case currencyFormatting
    }

    var onAddShift: (() -> Void)?
    var onManageWorkTypes: (() -> Void)?
    var onArchivedJobs: (() -> Void)?
    var onCheckPaycheck: ((PayCalculationPeriod) -> Void)?
    var onEditShift: ((Shift) -> Void)?

    private let viewModel: OverviewViewModel
    private let currencyCode: String
    private let timeZoneIdentifier: String
    private let displayLocale: Locale
    private let shiftCardMapper: OverviewShiftCardMapper
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
        self.shiftCardMapper = OverviewShiftCardMapper(
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: displayLocale
        )
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
        configureNavigationItem()
        bindView()
        viewModel.load()
        render()
    }

    func reload(selectingShiftID: UUID? = nil) {
        if let selectingShiftID {
            viewModel.reload(selectingShiftID: selectingShiftID)
        } else {
            viewModel.reload()
        }
        render()
    }

    func reload(job: Job) {
        viewModel.reload(job: job)
        render()
    }

    private func configureNavigationItem() {
        let workTypes = UIAction(title: OverviewStrings.workTypes) { [weak self] _ in
            self?.onManageWorkTypes?()
        }
        let archivedJobs = UIAction(title: OverviewStrings.archivedJobs) { [weak self] _ in
            self?.onArchivedJobs?()
        }
        let item = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [workTypes, archivedJobs])
        )
        item.accessibilityIdentifier = "overview.more"
        navigationItem.rightBarButtonItem = item
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
        overviewView.onPeriodTapped = { [weak self] period in
            self?.viewModel.selectPeriod(period)
            self?.render()
        }
        overviewView.onShiftCardTapped = { [weak self] id in
            self?.viewModel.handleShiftCardTap(with: id)
            self?.render()
        }
        overviewView.onEditShiftTapped = { [weak self] id in
            guard
                let self,
                case let .content(content) = viewModel.state,
                let shift = content.shiftHistoryBreakdowns.first(where: {
                    $0.shift.id == id
                })?.shift
            else {
                return
            }
            onEditShift?(shift)
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

            let cards: [OverviewView.ShiftCard]
            let precisionText: OverviewView.PrecisionExplanation?
            do {
                cards = try shiftCardMapper.map(
                    content.shiftHistoryBreakdowns,
                    selectedShiftID: content.selectedShiftID,
                    expandedShiftID: content.expandedShiftID
                )
                precisionText = try precisionExplanation(for: breakdown)
            } catch {
                renderFailure(.calculation)
                return
            }

            overviewView.renderContent(
                expectedGross: OverviewFormatting.heroAmount(
                    breakdown.expectedGross,
                    currencyCode: currencyCode,
                    locale: displayLocale
                ),
                expectedGrossContext: OverviewStrings.expectedGrossContext(currencyCode: currencyCode),
                precisionExplanation: precisionText,
                period: periodText,
                periodItems: railItems(from: content.railPeriods, selectedPeriod: period),
                showPeriodNavigation: content.showPeriodNavigation,
                shiftCount: content.shiftHistoryBreakdowns.count,
                shiftCards: cards,
                canNavigatePrevious: content.canNavigatePrevious,
                canNavigateNext: content.canNavigateNext,
                canCheckPaycheck: true
            )

            if let selectedShiftID = content.selectedShiftID,
               content.expandedShiftID != nil {
                overviewView.focusShiftCard(with: selectedShiftID)
            }
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

    private func precisionExplanation(for breakdown: ExpectedGrossBreakdown) throws -> OverviewView.PrecisionExplanation? {
        // Reconcile only the display representations of the selected-period breakdown.
        // The exact gross and individual contributions remain supplied by Domain.
        let displayedRows = try breakdown.shiftBreakdowns.reduce(Decimal.zero) { sum, item in
            guard let displayed = OverviewFormatting.displayedCurrencyValue(
                item.basePay, currencyCode: currencyCode, locale: displayLocale
            ) else { throw PresentationError.currencyFormatting }
            return sum + displayed
        }
        guard let displayedGross = OverviewFormatting.displayedCurrencyValue(
            breakdown.expectedGross, currencyCode: currencyCode, locale: displayLocale
        ) else { throw PresentationError.currencyFormatting }
        guard displayedRows != displayedGross else { return nil }
        guard let exactTotal = OverviewFormatting.exactCurrency(
                breakdown.expectedGross, currencyCode: currencyCode, locale: displayLocale
              ) else { throw PresentationError.currencyFormatting }
        return OverviewView.PrecisionExplanation(
            exactTotal: exactTotal,
            displayedTotal: OverviewFormatting.currency(
                breakdown.expectedGross, currencyCode: currencyCode, locale: displayLocale
            )
        )
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

    private func railItems(
        from periods: [OverviewViewModel.Content.RailPeriod],
        selectedPeriod: PayCalculationPeriod
    ) -> [OverviewView.PeriodItem] {
        periods.compactMap { railPeriod in
            guard let title = formattedRailPeriod(railPeriod) else {
                return nil
            }

            return OverviewView.PeriodItem(
                period: railPeriod.period,
                title: title,
                isSelected: railPeriod.period == selectedPeriod
            )
        }
    }

    private func formattedRailPeriod(
        _ railPeriod: OverviewViewModel.Content.RailPeriod
    ) -> String? {
        switch railPeriod.period {
        case let .scheduled(payPeriod):
            return OverviewFormatting.compactScheduledPeriod(
                payPeriod,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: displayLocale
            )
        case .perShift:
            return nil
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
