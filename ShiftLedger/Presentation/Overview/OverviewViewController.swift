import UIKit

final class OverviewViewController: UIViewController {
    var onAddShift: (() -> Void)?
    var onShowSavedShifts: (() -> Void)?
    var usesHomeComposition = false
    var onCheckPaycheck: ((PayCalculationPeriod) -> Void)?
    var onEditShift: ((Shift) -> Void)?

    private let viewModel: OverviewViewModel
    private let currencyCode: String
    private let timeZoneIdentifier: String
    private let displayLocale: Locale
    private let shiftCardMapper: OverviewShiftCardMapper
    private let displayedCurrencyValue: (Decimal, String, Locale) -> Decimal?
    private let overviewView = OverviewView(frame: .zero)
    private var historyCards: [UUID: OverviewView.ShiftCard]?
    var showsShiftHistoryOnly = false

    init(
        viewModel: OverviewViewModel,
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale,
        displayedCurrencyValue: @escaping (Decimal, String, Locale) -> Decimal? = OverviewFormatting.displayedCurrencyValue
    ) {
        self.viewModel = viewModel
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayLocale = displayLocale
        self.displayedCurrencyValue = displayedCurrencyValue
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
        if usesHomeComposition {
            overviewView.installHomeComposition()
        }
        view = overviewView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if showsShiftHistoryOnly {
            title = OverviewStrings.allShiftHistory
            let tabTitle = String(localized: "tabs.shifts", table: "Localizable")
            tabBarItem.title = tabTitle
            navigationController?.tabBarItem.title = tabTitle
            overviewView.accessibilityIdentifier = "shifts.screen"
            overviewView.showsShiftHistoryOnly = true
            viewModel.showsShiftHistoryOnly = true
            viewModel.historyDisplayLocale = displayLocale
        } else {
            let brand = OverviewNavigationBrandLabel()
            navigationItem.title = brand.text
            navigationItem.titleView = brand
        }
        bindView()
        historyCards = nil
        viewModel.load()
        render()
    }

    func reload(selectingShiftID: UUID? = nil) {
        historyCards = nil
        if let selectingShiftID {
            viewModel.reload(selectingShiftID: selectingShiftID)
        } else {
            viewModel.reload()
        }
        render()
    }

    func reload(job: Job) {
        historyCards = nil
        viewModel.reload(job: job)
        if isViewLoaded { render() }
    }

    private func bindView() {
        overviewView.onShowSavedShifts = { [weak self] in self?.onShowSavedShifts?() }
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
            guard let self else { return }
            if showsShiftHistoryOnly {
                viewModel.tapHistoryRow(id)
                render()
                if viewModel.history.expandedID == id { overviewView.focusShiftCard(with: id) }
            } else {
                viewModel.handleShiftCardTap(with: id)
                render()
            }
        }
        overviewView.onHistorySearch = { [weak self] text in
            guard let self, viewModel.updateHistorySearch(text) else { return }
            render()
        }
        overviewView.onHistoryClear = { [weak self] in
            guard let self, viewModel.updateHistorySearch("") else { return }
            render()
            overviewView.announceFilteredCount()
        }
        overviewView.onHistoryFilters = { [weak self] in self?.showHistoryFilters() }
        overviewView.onHistorySort = { [weak self] sort in
            guard let self else { return }
            var query = viewModel.history.query
            query.sort = sort
            if viewModel.applyHistoryQuery(query) { render() }
        }
        overviewView.onHistoryReset = { [weak self] in
            guard let self else { return }
            if viewModel.updateHistoryFilters(from: .init()) {
                render()
                overviewView.focusHistoryFilters()
                overviewView.announceFilteredCount()
            }
        }
        overviewView.onEditShiftTapped = { [weak self] id in
            guard
                let self,
                case let .content(content) = viewModel.state,
                let shift = (showsShiftHistoryOnly ? viewModel.history.visible : content.shiftHistoryBreakdowns).first(where: {
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
            self?.historyCards = nil
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
        if showsShiftHistoryOnly {
            let history = viewModel.history
            do {
                let cards = try cardsForVisibleHistory(history, content: content)
                overviewView.renderHistoryOnly(cards, totalCount: history.totalCount, query: history.query)
            } catch {
                renderFailure(.calculation)
            }
            return
        }

        switch (content.selectedPeriod, content.expectedBreakdown) {
        case (nil, nil):
            overviewView.renderEmpty()
        case let (period?, breakdown?):
            guard let periodText = formattedPeriod(period, breakdown: breakdown) else {
                renderFailure(.calculation)
                return
            }

            guard let cards = shiftCards(for: content) else { return }

            overviewView.renderContent(
                expectedGross: OverviewFormatting.heroAmount(
                    breakdown.expectedGross,
                    currencyCode: currencyCode,
                    locale: displayLocale
                ),
                expectedGrossContext: OverviewStrings.expectedGrossContext(currencyCode: currencyCode),
                amountLocale: displayLocale,
                precisionExplanation: precisionExplanation(for: breakdown),
                period: periodText.date,
                periodTime: periodText.time,
                periodAccessibilityLabel: periodText.accessibilityLabel,
                periodItems: railItems(from: content.railPeriods, selectedPeriod: period),
                showPeriodNavigation: content.showPeriodNavigation,
                shiftCount: content.shiftHistoryBreakdowns.count,
                shiftCards: cards,
                canNavigatePrevious: content.canNavigatePrevious,
                canNavigateNext: content.canNavigateNext,
                canCheckPaycheck: true,
                perShiftSelection: content.showPeriodNavigation ? nil : content.selectedShiftID
            )

            if !usesHomeComposition, let selectedShiftID = content.selectedShiftID,
               content.expandedShiftID != nil {
                overviewView.focusShiftCard(with: selectedShiftID)
            }
        default:
            renderFailure(.calculation)
        }
    }

    private func shiftCards(for content: OverviewViewModel.Content) -> [OverviewView.ShiftCard]? {
        do {
            return try shiftCardMapper.map(
                Array(content.shiftHistoryBreakdowns.reversed()),
                workTypeNames: content.workTypeNames,
                selectedShiftID: content.selectedShiftID,
                expandedShiftID: content.expandedShiftID
            )
        } catch {
            renderFailure(.calculation)
            return nil
        }
    }

    private enum HistoryCardError: Error {
        case inconsistentHistory
    }

    private func cardsForVisibleHistory(
        _ history: OverviewViewModel.History, content: OverviewViewModel.Content
    ) throws -> [OverviewView.ShiftCard] {
        if let historyCards, let cards = orderedCards(for: history, in: historyCards) {
            return cards
        }

        historyCards = nil
        let mapper = OverviewShiftCardMapper(
            currencyCode: viewModel.historyCurrencyCode,
            timeZoneIdentifier: viewModel.historyTimeZone?.identifier ?? timeZoneIdentifier,
            displayLocale: displayLocale
        )
        let mapped = try mapper.map(content.shiftHistoryBreakdowns, workTypeNames: content.workTypeNames,
                                    selectedShiftID: nil, expandedShiftID: nil)
        var rebuilt: [UUID: OverviewView.ShiftCard] = [:]
        rebuilt.reserveCapacity(mapped.count)
        for card in mapped {
            guard rebuilt.updateValue(card, forKey: card.id) == nil else {
                throw HistoryCardError.inconsistentHistory
            }
        }
        guard let cards = orderedCards(for: history, in: rebuilt) else {
            throw HistoryCardError.inconsistentHistory
        }
        historyCards = rebuilt
        return cards
    }

    private func orderedCards(
        for history: OverviewViewModel.History, in cache: [UUID: OverviewView.ShiftCard]
    ) -> [OverviewView.ShiftCard]? {
        var cards: [OverviewView.ShiftCard] = []
        cards.reserveCapacity(history.visible.count)
        for row in history.visible {
            guard var card = cache[row.shift.id] else { return nil }
            card.isSelected = card.id == history.selectedID
            card.isExpanded = card.id == history.expandedID
            cards.append(card)
        }
        return cards
    }

    private func showHistoryFilters() {
        guard let timeZone = viewModel.historyTimeZone else { return }
        let sheet = ShiftHistoryFiltersViewController(
            query: viewModel.history.query, options: viewModel.historyWorkTypes(locale: displayLocale),
            timeZone: timeZone, currency: viewModel.historyCurrencyCode, locale: displayLocale,
            now: viewModel.historyReferenceDate
        )
        var applied = false
        sheet.onApply = { [weak self] query in
            guard let self, viewModel.updateHistoryFilters(from: query) else { return false }
            applied = true
            render()
            return true
        }
        sheet.onDismiss = { [weak self] in
            self?.overviewView.focusHistoryFilters()
            if applied { self?.overviewView.announceFilteredCount() }
        }
        overviewView.dismissHistoryKeyboard()
        let navigation = UINavigationController(rootViewController: sheet)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.large()]
        navigation.presentationController?.delegate = sheet
        present(navigation, animated: true)
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

    private func precisionExplanation(for breakdown: ExpectedGrossBreakdown) -> OverviewView.PrecisionExplanation? {
        // Reconcile only the display representations of the selected-period breakdown.
        // The exact gross and individual contributions remain supplied by Domain.
        var displayedRows = Decimal.zero
        for item in breakdown.shiftBreakdowns {
            guard var displayed = displayedCurrencyValue(item.basePay, currencyCode, displayLocale) else {
                return nil // Optional presentation cannot invalidate a successful payroll calculation.
            }
            var sum = Decimal.zero
            guard NSDecimalAdd(&sum, &displayedRows, &displayed, .bankers) == .noError else {
                return nil
            }
            displayedRows = sum
        }
        guard let displayedGross = displayedCurrencyValue(breakdown.expectedGross, currencyCode, displayLocale) else {
            return nil
        }
        let nonzeroDisplayedAsZero = breakdown.expectedGross != .zero && displayedGross == .zero
        guard displayedRows != displayedGross || nonzeroDisplayedAsZero else { return nil }
        guard let exactTotal = OverviewFormatting.exactCurrency(
                breakdown.expectedGross, currencyCode: currencyCode, locale: displayLocale
              ) else { return nil }
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
    ) -> OverviewFormatting.PeriodHeading? {
        switch period {
        case let .scheduled(payPeriod):
            guard let date = OverviewFormatting.scheduledPeriod(
                payPeriod, timeZoneIdentifier: timeZoneIdentifier, locale: displayLocale
            ) else { return nil }
            return OverviewFormatting.PeriodHeading(date: date, time: nil, accessibilityLabel: date)
        case let .perShift(shiftID):
            guard
                breakdown.shiftBreakdowns.count == 1,
                let shift = breakdown.shiftBreakdowns.first?.shift,
                shift.id == shiftID
            else {
                return nil
            }

            return OverviewFormatting.perShiftHeading(
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

    func paycheckPeriodHeading(for period: PayCalculationPeriod) -> OverviewFormatting.PeriodHeading? {
        guard case let .content(content) = viewModel.state,
              content.selectedPeriod == period,
              let breakdown = content.expectedBreakdown else { return nil }
        if case let .scheduled(payPeriod) = period {
            guard let date = OverviewFormatting.compactScheduledPeriod(
                payPeriod, timeZoneIdentifier: timeZoneIdentifier, locale: displayLocale
            ) else { return nil }
            return OverviewFormatting.PeriodHeading(date: date, time: nil, accessibilityLabel: date)
        }
        return formattedPeriod(period, breakdown: breakdown)
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

private final class OverviewNavigationBrandLabel: UILabel {
    private static let baseFont: UIFont = {
        let base = UIFont.systemFont(ofSize: 20, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }()

    init() {
        super.init(frame: .zero)
        text = "ShiftLedger"
        textColor = ShiftLedgerColors.textPrimary
        textAlignment = .center
        accessibilityIdentifier = "overview.navigation.brand"
        accessibilityTraits = .header
        font = preferredBrandFont
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (label: Self, _) in
            label.invalidateIntrinsicContentSize()
            label.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let preferred = preferredBrandFont
        return CGSize(width: ceil(textWidth(with: preferred)), height: ceil(preferred.lineHeight))
    }

    override func layoutSubviews() {
        let preferred = preferredBrandFont
        var fitted = preferred
        let width = bounds.width
        if width > 0, textWidth(with: preferred) > width {
            var lower = min(Self.baseFont.pointSize, preferred.pointSize)
            var upper = preferred.pointSize
            for _ in 0..<14 {
                let middle = (lower + upper) / 2
                if textWidth(with: preferred.withSize(middle)) <= width {
                    lower = middle
                } else {
                    upper = middle
                }
            }
            fitted = preferred.withSize(lower)
        }
        if font != fitted {
            font = fitted
        }
        super.layoutSubviews()
    }

    private var preferredBrandFont: UIFont {
        UIFontMetrics(forTextStyle: .title3).scaledFont(
            for: Self.baseFont, maximumPointSize: 28, compatibleWith: traitCollection
        )
    }

    private func textWidth(with font: UIFont) -> CGFloat {
        ((text ?? "") as NSString).size(withAttributes: [.font: font]).width
    }
}
