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
            let shift: Shift?
        }

        let selectedPeriod: PayCalculationPeriod?
        let railPeriods: [RailPeriod]
        let expectedBreakdown: ExpectedGrossBreakdown?
        let selectedShiftID: UUID?
        let totalStoredShiftCount: Int
        let canNavigatePrevious: Bool
        let canNavigateNext: Bool
    }

    enum State: Equatable {
        case idle
        case content(Content)
        case failure(Failure)
    }

    private(set) var state: State = .idle

    private let job: Job
    private let loadShifts: @MainActor () throws -> [Shift]
    private let currentDate: @MainActor () -> Date

    private var shifts: [Shift] = []
    private var selectedPeriod: PayCalculationPeriod?

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
            case let (.perShift, .perShift(shiftID)):
                guard
                    let index = shifts.firstIndex(where: { $0.id == shiftID }),
                    index > shifts.startIndex,
                    let content = try perShiftContent(for: shifts[index - 1])
                else {
                    return
                }

                publish(content)
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
            case let (.perShift, .perShift(shiftID)):
                guard
                    let index = shifts.firstIndex(where: { $0.id == shiftID }),
                    index < shifts.index(before: shifts.endIndex),
                    let content = try perShiftContent(for: shifts[index + 1])
                else {
                    return
                }

                publish(content)
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
            case let (.perShift, .perShift(shiftID)):
                guard let shift = shifts.first(where: { $0.id == shiftID }), let content = try perShiftContent(for: shift) else { return }
                publish(content)
            default:
                return
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

        shifts = loadedShifts

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
                currentPayPeriod: currentPayPeriod,
                selectedShiftID: shift.id
            )
        case .perShift:
            guard let content = try perShiftContent(for: shift, selectedShiftID: shift.id) else {
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
        currentPayPeriod: PayPeriod,
        selectedShiftID: UUID? = nil
    ) throws {
        let period = PayCalculationPeriod.scheduled(selectedPayPeriod)
        let breakdown = try job.expectedGrossBreakdown(for: period, from: shifts)

        publish(Content(
            selectedPeriod: period,
            railPeriods: scheduledRailPeriods(selectedPayPeriod, currentPayPeriod: currentPayPeriod),
            expectedBreakdown: breakdown,
            selectedShiftID: selectedShiftID,
            totalStoredShiftCount: shifts.count,
            canNavigatePrevious: true,
            canNavigateNext: selectedPayPeriod.start < currentPayPeriod.start
        ))
    }

    private func perShiftContent(
        for selectedShift: Shift?,
        selectedShiftID: UUID? = nil
    ) throws -> Content? {
        guard let selectedShift else {
            return Content(
                selectedPeriod: nil,
                railPeriods: [],
                expectedBreakdown: nil,
                selectedShiftID: nil,
                totalStoredShiftCount: shifts.count,
                canNavigatePrevious: false,
                canNavigateNext: false
            )
        }

        guard let index = shifts.firstIndex(where: { $0.id == selectedShift.id }) else {
            return nil
        }

        let period = try job.payCalculationPeriod(for: selectedShift)
        let breakdown = try job.expectedGrossBreakdown(for: period, from: shifts)

        return Content(
            selectedPeriod: period,
            railPeriods: shifts.map {
                Content.RailPeriod(period: .perShift(shiftID: $0.id), shift: $0)
            },
            expectedBreakdown: breakdown,
            selectedShiftID: selectedShiftID,
            totalStoredShiftCount: shifts.count,
            canNavigatePrevious: index > shifts.startIndex,
            canNavigateNext: index < shifts.index(before: shifts.endIndex)
        )
    }

    private func scheduledRailPeriods(
        _ selected: PayPeriod,
        currentPayPeriod: PayPeriod
    ) -> [Content.RailPeriod] {
        guard case let .scheduled(schedule) = job.payCalculationCycle else { return [] }
        var periods: [Content.RailPeriod] = []
        if let previous = try? schedule.period(before: selected) {
            periods.append(.init(period: .scheduled(previous), shift: nil))
        }
        periods.append(.init(period: .scheduled(selected), shift: nil))
        if selected.start < currentPayPeriod.start,
           let next = try? schedule.period(after: selected),
           next.start <= currentPayPeriod.start {
            periods.append(.init(period: .scheduled(next), shift: nil))
        }
        return periods
    }

    private func publish(_ content: Content) {
        selectedPeriod = content.selectedPeriod
        state = .content(content)
    }
}
