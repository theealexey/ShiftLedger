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

    func reload(selectingShiftID: UUID? = nil) {
        if let selectingShiftID {
            viewModel.reload(selectingShiftID: selectingShiftID)
        } else {
            viewModel.reload()
        }
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
        overviewView.onPeriodTapped = { [weak self] period in
            self?.viewModel.selectPeriod(period)
            self?.render()
        }
        overviewView.onShiftCardTapped = { [weak self] id in
            self?.viewModel.toggleShiftExpansion(with: id)
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

            let cards: [OverviewView.ShiftCard]
            do {
                cards = try shiftCards(
                    from: content.shiftHistoryBreakdowns,
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

    private func shiftCards(
        from shiftBreakdowns: [ShiftPayBreakdown],
        selectedShiftID: UUID?,
        expandedShiftID: UUID? = nil
    ) throws -> [OverviewView.ShiftCard] {
        try shiftBreakdowns.reversed().map { shiftBreakdown in
            let shift = shiftBreakdown.shift
            guard
                let frontDate = OverviewFormatting.frontShiftDate(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let endpoints = OverviewFormatting.shiftEndpoints(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let compactTimeRange = OverviewFormatting.compactShiftTimeRange(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let accessibilityDate = OverviewFormatting.shiftDate(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let accessibilityTimeRange = OverviewFormatting.shiftTimeRange(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                )
            else {
                throw OverviewViewModel.Failure.calculation
            }

            let expectedAmount = OverviewFormatting.currency(
                shiftBreakdown.basePay,
                currencyCode: currencyCode,
                locale: displayLocale
            )
            let paidDuration = OverviewFormatting.duration(shiftBreakdown.paidDuration)
            let unpaidBreak = shift.unpaidBreak.map {
                OverviewFormatting.duration($0.end.timeIntervalSince($0.start))
            }
            let unpaidBreakTimeRange = shift.unpaidBreak.flatMap {
                OverviewFormatting.unpaidBreakTimeRange(
                    $0,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                )
            }
            let payBasis: String
            switch shiftBreakdown.basePayBasis {
            case .hourly:
                payBasis = JobSetupStrings.hourlyBasis
            case .fixedPerShift:
                payBasis = JobSetupStrings.fixedPerShiftBasis
            }
            let accessibilityLabel = [
                accessibilityDate,
                accessibilityTimeRange,
                "\(PaycheckResultStrings.shiftExpected): \(expectedAmount)",
                "\(PaycheckResultStrings.paidTime): \(paidDuration)",
                unpaidBreak.map { "\(AddShiftStrings.unpaidBreak): \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            return OverviewView.ShiftCard(
                id: shift.id,
                frontDate: frontDate,
                timeRange: compactTimeRange,
                endpoints: endpoints,
                expectedAmount: expectedAmount,
                paidDuration: paidDuration,
                unpaidBreak: unpaidBreak,
                unpaidBreakTimeRange: unpaidBreakTimeRange,
                appliedRate: OverviewFormatting.rate(
                    amount: shiftBreakdown.appliedPayRate.amount,
                    basis: shiftBreakdown.basePayBasis,
                    currencyCode: currencyCode,
                    locale: displayLocale
                ),
                payBasis: payBasis,
                isSelected: shift.id == selectedShiftID,
                isExpanded: shift.id == expandedShiftID,
                accessibilityLabel: accessibilityLabel
            )
        }
    }
}
