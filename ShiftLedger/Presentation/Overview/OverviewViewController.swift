import UIKit

final class OverviewViewController: UIViewController {
    var onAddShift: (() -> Void)?
    var onManageWorkTypes: (() -> Void)?
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
        let item = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [workTypes])
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
            self?.viewModel.toggleShiftExpansion(with: id)
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
            do {
                cards = try shiftCardMapper.map(
                    content.shiftHistoryBreakdowns,
                    selectedShiftID: content.selectedShiftID,
                    expandedShiftID: content.expandedShiftID
                )
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
                period: periodText,
                periodItems: railItems(from: content.railPeriods, selectedPeriod: period),
                shiftCount: content.shiftHistoryBreakdowns.count,
                shiftCards: cards,
                canNavigatePrevious: content.canNavigatePrevious,
                canNavigateNext: content.canNavigateNext,
                canCheckPaycheck: true
            )

            if let selectedShiftID = content.selectedShiftID {
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
        case let .perShift(shiftID):
            guard let shift = railPeriod.shift, shift.id == shiftID else {
                return nil
            }

            return OverviewFormatting.compactPerShiftPeriod(
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
