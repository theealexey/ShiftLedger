import Foundation

@MainActor
final class OverviewViewModel {
    enum Failure: Error, Equatable {
        case loading
        case calculation
    }

    struct Content: Equatable {
        struct RailPeriod: Equatable {
            let period: PayCalculationPeriod
        }

        let selectedPeriod: PayCalculationPeriod?
        let showPeriodNavigation: Bool
        let railPeriods: [RailPeriod]
        let expectedBreakdown: ExpectedGrossBreakdown?
        let shiftHistoryBreakdowns: [ShiftPayBreakdown]
        let selectedShiftID: UUID?
        let expandedShiftID: UUID?
        let canNavigatePrevious: Bool
        let canNavigateNext: Bool
    }

    enum State: Equatable {
        case idle
        case content(Content)
        case failure(Failure)
    }

    private(set) var state: State = .idle

    private var job: Job
    private let loadShifts: @MainActor () throws -> [Shift]
    private let currentDate: @MainActor () -> Date

    private var shifts: [Shift] = []
    private var selectedPeriod: PayCalculationPeriod?
    private var selectedShiftID: UUID?
    private var expandedShiftID: UUID?

    init(
        job: Job,
        loadShifts: @escaping @MainActor () throws -> [Shift],
        currentDate: @escaping @MainActor () -> Date
    ) {
        self.job = job
        self.loadShifts = loadShifts
        self.currentDate = currentDate
    }

    func load() {
        refresh(preservingSelection: false)
    }

    func reload() {
        refresh(preservingSelection: true, selectingShiftID: nil)
    }

    func reload(selectingShiftID: UUID) {
        refresh(preservingSelection: true, selectingShiftID: selectingShiftID)
    }

    func reload(job: Job) {
        self.job = job
        refresh(preservingSelection: true)
    }

    func navigateToPreviousPeriod() {
        guard
            case let .content(content) = state,
            content.canNavigatePrevious,
            let selectedPeriod
        else {
            return
        }

        do {
            switch (job.payCalculationCycle, selectedPeriod) {
            case let (.scheduled(schedule), .scheduled(payPeriod)):
                guard let currentPayPeriod = try currentScheduledPayPeriod() else {
                    state = .failure(.calculation)
                    return
                }

                let previousPeriod = try schedule.period(before: payPeriod)
                try publishScheduledContent(
                    selectedPayPeriod: previousPeriod,
                    currentPayPeriod: currentPayPeriod
                )
            case (.perShift, _):
                return
            default:
                state = .failure(.calculation)
            }
        } catch {
            state = .failure(.calculation)
        }
    }

    func navigateToNextPeriod() {
        guard
            case let .content(content) = state,
            content.canNavigateNext,
            let selectedPeriod
        else {
            return
        }

        do {
            switch (job.payCalculationCycle, selectedPeriod) {
            case let (.scheduled(schedule), .scheduled(payPeriod)):
                guard let currentPayPeriod = try currentScheduledPayPeriod() else {
                    state = .failure(.calculation)
                    return
                }

                let nextPeriod = try schedule.period(after: payPeriod)
                guard nextPeriod.start <= currentPayPeriod.start else {
                    return
                }

                try publishScheduledContent(
                    selectedPayPeriod: nextPeriod,
                    currentPayPeriod: currentPayPeriod
                )
            case (.perShift, _):
                return
            default:
                state = .failure(.calculation)
            }
        } catch {
            state = .failure(.calculation)
        }
    }

    func selectPeriod(_ period: PayCalculationPeriod) {
        guard case .content = state else { return }

        do {
            switch (job.payCalculationCycle, period) {
            case let (.scheduled, .scheduled(payPeriod)):
                guard let currentPayPeriod = try currentScheduledPayPeriod(), payPeriod.start <= currentPayPeriod.start else { return }
                try publishScheduledContent(selectedPayPeriod: payPeriod, currentPayPeriod: currentPayPeriod)
            default:
                return
            }
        } catch {
            state = .failure(.calculation)
        }
    }

    func toggleShiftExpansion(with id: UUID) {
        guard
            case let .content(content) = state,
            content.shiftHistoryBreakdowns.contains(where: { $0.shift.id == id })
        else {
            return
        }

        if selectedShiftID == id, expandedShiftID == id {
            expandedShiftID = nil
        } else {
            selectedShiftID = id
            expandedShiftID = id
        }

        do {
            switch job.payCalculationCycle {
            case .perShift:
                guard let shift = shifts.first(where: { $0.id == id }),
                      let updatedContent = try perShiftContent(for: shift) else { return }
                publish(updatedContent)
            case .scheduled:
                publish(content.replacingSelection(
                    selectedShiftID: selectedShiftID,
                    expandedShiftID: expandedShiftID
                ))
            }
        } catch {
            state = .failure(.calculation)
        }
    }

    private func refresh(
        preservingSelection: Bool,
        selectingShiftID: UUID? = nil
    ) {
        let loadedShifts: [Shift]
        do {
            loadedShifts = try loadShifts()
        } catch {
            state = .failure(.loading)
            return
        }

        shifts = loadedShifts.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.end != rhs.end { return lhs.end < rhs.end }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        if !preservingSelection {
            selectedShiftID = nil
            expandedShiftID = nil
        }

        do {
            if let selectingShiftID,
               let selectedShift = shifts.first(where: { $0.id == selectingShiftID }) {
                try publishContent(selectingSavedShift: selectedShift)
            } else {
                try publishRefreshedContent(preservingSelection: preservingSelection)
            }
        } catch {
            state = .failure(.calculation)
        }
    }

    private func publishRefreshedContent(preservingSelection: Bool) throws {
        switch job.payCalculationCycle {
        case .scheduled:
            guard let currentPayPeriod = try currentScheduledPayPeriod() else {
                state = .failure(.calculation)
                return
            }

            let selectedPayPeriod: PayPeriod
            if preservingSelection,
               case let .scheduled(payPeriod)? = selectedPeriod {
                selectedPayPeriod = payPeriod
            } else {
                selectedPayPeriod = currentPayPeriod
            }

            try publishScheduledContent(
                selectedPayPeriod: selectedPayPeriod,
                currentPayPeriod: currentPayPeriod
            )
        case .perShift:
            let selectedShift: Shift?
            if preservingSelection,
               case let .perShift(shiftID)? = selectedPeriod,
               let preservedShift = shifts.first(where: { $0.id == shiftID }) {
                selectedShift = preservedShift
            } else {
                selectedShift = shifts.last
            }

            guard let content = try perShiftContent(for: selectedShift) else {
                state = .failure(.calculation)
                return
            }

            publish(content)
        }
    }

    private func publishContent(selectingSavedShift shift: Shift) throws {
        selectedShiftID = shift.id
        expandedShiftID = shift.id
        switch job.payCalculationCycle {
        case .scheduled:
            guard let currentPayPeriod = try currentScheduledPayPeriod(),
                  case let .scheduled(savedPayPeriod) = try job.payCalculationPeriod(for: shift),
                  savedPayPeriod.start <= currentPayPeriod.start
            else {
                try publishRefreshedContent(preservingSelection: true)
                return
            }

            try publishScheduledContent(
                selectedPayPeriod: savedPayPeriod,
                currentPayPeriod: currentPayPeriod
            )
        case .perShift:
            guard let content = try perShiftContent(for: shift) else {
                state = .failure(.calculation)
                return
            }

            publish(content)
        }
    }

    private func currentScheduledPayPeriod() throws -> PayPeriod? {
        guard case let .scheduled(payPeriod)? = try job.payCalculationPeriod(
            containing: currentDate()
        ) else {
            return nil
        }

        return payPeriod
    }

    private func publishScheduledContent(
        selectedPayPeriod: PayPeriod,
        currentPayPeriod: PayPeriod
    ) throws {
        let period = PayCalculationPeriod.scheduled(selectedPayPeriod)
        let breakdown = try job.expectedGrossBreakdown(for: period, from: shifts)
        let shiftHistoryBreakdowns = breakdown.shiftBreakdowns

        let selection = selection(in: shiftHistoryBreakdowns)
        publish(Content(
            selectedPeriod: period,
            showPeriodNavigation: true,
            railPeriods: scheduledRailPeriods(selectedPayPeriod, currentPayPeriod: currentPayPeriod),
            expectedBreakdown: breakdown,
            shiftHistoryBreakdowns: shiftHistoryBreakdowns,
            selectedShiftID: selection.selectedShiftID,
            expandedShiftID: selection.expandedShiftID,
            canNavigatePrevious: true,
            canNavigateNext: selectedPayPeriod.start < currentPayPeriod.start
        ))
    }

    private func perShiftContent(
        for selectedShift: Shift?
    ) throws -> Content? {
        guard let selectedShift else {
            return Content(
                selectedPeriod: nil,
                showPeriodNavigation: false,
                railPeriods: [],
                expectedBreakdown: nil,
                shiftHistoryBreakdowns: [],
                selectedShiftID: nil,
                expandedShiftID: nil,
                canNavigatePrevious: false,
                canNavigateNext: false
            )
        }

        guard shifts.contains(where: { $0.id == selectedShift.id }) else {
            return nil
        }

        let period = try job.payCalculationPeriod(for: selectedShift)
        let breakdown = try job.expectedGrossBreakdown(for: period, from: shifts)
        let shiftHistoryBreakdowns = try allShiftHistoryBreakdowns()

        return Content(
            selectedPeriod: period,
            showPeriodNavigation: false,
            railPeriods: [],
            expectedBreakdown: breakdown,
            shiftHistoryBreakdowns: shiftHistoryBreakdowns,
            selectedShiftID: selectedShift.id,
            expandedShiftID: selectedShiftID == selectedShift.id && expandedShiftID == selectedShift.id
                ? selectedShift.id : nil,
            canNavigatePrevious: false,
            canNavigateNext: false
        )
    }

    private func scheduledRailPeriods(
        _ selected: PayPeriod,
        currentPayPeriod: PayPeriod
    ) -> [Content.RailPeriod] {
        guard case let .scheduled(schedule) = job.payCalculationCycle else { return [] }
        var periods: [Content.RailPeriod] = []
        if let previous = try? schedule.period(before: selected) {
            periods.append(.init(period: .scheduled(previous)))
        }
        periods.append(.init(period: .scheduled(selected)))
        if selected.start < currentPayPeriod.start,
           let next = try? schedule.period(after: selected),
           next.start <= currentPayPeriod.start {
            periods.append(.init(period: .scheduled(next)))
        }
        return periods
    }

    private func publish(_ content: Content) {
        selectedPeriod = content.selectedPeriod
        selectedShiftID = content.selectedShiftID
        expandedShiftID = content.expandedShiftID
        state = .content(content)
    }

    private func allShiftHistoryBreakdowns() throws -> [ShiftPayBreakdown] {
        try shifts
            .map { shift in
                let period = try job.payCalculationPeriod(for: shift)
                guard let breakdown = try job.expectedGrossBreakdown(
                    for: period,
                    from: [shift]
                ).shiftBreakdowns.first else {
                    throw Failure.calculation
                }
                return breakdown
            }
            .sorted { lhs, rhs in
                if lhs.shift.start != rhs.shift.start {
                    return lhs.shift.start < rhs.shift.start
                }
                if lhs.shift.end != rhs.shift.end {
                    return lhs.shift.end < rhs.shift.end
                }
                return lhs.shift.id.uuidString < rhs.shift.id.uuidString
            }
    }

    private func selection(
        in shiftHistoryBreakdowns: [ShiftPayBreakdown]
    ) -> (selectedShiftID: UUID?, expandedShiftID: UUID?) {
        guard
            let selectedShiftID,
            shiftHistoryBreakdowns.contains(where: { $0.shift.id == selectedShiftID })
        else {
            self.selectedShiftID = nil
            expandedShiftID = nil
            return (nil, nil)
        }

        guard expandedShiftID == selectedShiftID else {
            expandedShiftID = nil
            return (selectedShiftID, nil)
        }

        return (selectedShiftID, expandedShiftID)
    }
}

private extension OverviewViewModel.Content {
    func replacingSelection(selectedShiftID: UUID?, expandedShiftID: UUID?) -> Self {
        Self(
            selectedPeriod: selectedPeriod,
            showPeriodNavigation: showPeriodNavigation,
            railPeriods: railPeriods,
            expectedBreakdown: expectedBreakdown,
            shiftHistoryBreakdowns: shiftHistoryBreakdowns,
            selectedShiftID: selectedShiftID,
            expandedShiftID: expandedShiftID,
            canNavigatePrevious: canNavigatePrevious,
            canNavigateNext: canNavigateNext
        )
    }
}
