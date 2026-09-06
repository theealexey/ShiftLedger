import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewViewModelTests {
    private let hour: TimeInterval = 60 * 60

    @Test("Initial scheduled selection uses the injected current Date")
    func initialScheduledSelectionUsesInjectedDate() throws {
        let anchor = try localDate(year: 2026, month: 9, day: 7)
        let job = try makeJob(cycle: .scheduled(.weekly(anchorDate: anchor)))
        let now = try date(year: 2026, month: 9, day: 16, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return []
            },
            currentDate: { now }
        )

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(loadCalls == 1)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 14),
            endExclusive: try localDate(year: 2026, month: 9, day: 21)
        )))
        #expect(content.canNavigatePrevious)
        #expect(content.canNavigateNext == false)
    }

    @Test("Scheduled selection uses Job timezone")
    func scheduledSelectionUsesJobTimeZone() throws {
        let job = try makeJob(
            timeZoneIdentifier: "America/New_York",
            cycle: .scheduled(.calendarMonthly)
        )
        let now = try date(
            year: 2026,
            month: 9,
            day: 1,
            hour: 0,
            minute: 30,
            timeZoneIdentifier: "UTC"
        )
        let viewModel = makeViewModel(job: job, shifts: [], now: now)

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 1),
            endExclusive: try localDate(year: 2026, month: 9, day: 1)
        )))
    }

    @Test("Calendar monthly Job selects the current local month")
    func calendarMonthlySelectsCurrentMonth() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [], now: now)

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )))
    }

    @Test("Per-shift Job with no stored shifts has no selection")
    func perShiftWithoutStoredShiftsHasNoSelection() throws {
        let job = try makeJob(cycle: .perShift)
        let viewModel = makeViewModel(
            job: job,
            shifts: [],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == nil)
        #expect(content.expectedBreakdown == nil)
        #expect(content.totalStoredShiftCount == 0)
        #expect(content.canNavigatePrevious == false)
        #expect(content.canNavigateNext == false)
    }

    @Test("Per-shift Job defaults to the latest stored Shift")
    func perShiftDefaultsToLatestStoredShift() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10)
        let latest = try makeShift(id: 2, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )

        viewModel.load()

        let content = try requireContent(viewModel.state)
        let breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [latest])
        #expect(content.totalStoredShiftCount == 2)
        #expect(content.canNavigatePrevious)
        #expect(content.canNavigateNext == false)
    }

    @Test("Scheduled period with zero matching shifts remains valid content")
    func scheduledZeroShiftPeriodIsValidContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let augustShift = try makeShift(id: 1, month: 8, day: 20)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [augustShift], now: now)

        viewModel.load()

        let content = try requireContent(viewModel.state)
        let breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == breakdown.period)
        #expect(breakdown.shiftBreakdowns.isEmpty)
        #expect(breakdown.expectedGross == .zero)
        #expect(content.totalStoredShiftCount == 1)
    }

    @Test("Scheduled breakdown includes only shifts in the selected period")
    func scheduledBreakdownIncludesOnlySelectedPeriodShifts() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 31)
        let septemberFirst = try makeShift(id: 2, month: 9, day: 10)
        let septemberSecond = try makeShift(id: 3, month: 9, day: 20)
        let october = try makeShift(id: 4, month: 10, day: 1)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(
            job: job,
            shifts: [august, septemberFirst, septemberSecond, october],
            now: now
        )

        viewModel.load()

        let content = try requireContent(viewModel.state)
        let breakdown = try #require(content.expectedBreakdown)
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [septemberFirst, septemberSecond])
        #expect(breakdown.expectedGross == Decimal(320))
        #expect(content.totalStoredShiftCount == 4)
    }

    @Test("Scheduled previous navigation uses Domain weekly arithmetic")
    func scheduledPreviousNavigationUsesWeeklyArithmetic() throws {
        let anchor = try localDate(year: 2026, month: 9, day: 7)
        let job = try makeJob(cycle: .scheduled(.weekly(anchorDate: anchor)))
        let historicalShift = try makeShift(id: 1, day: 10)
        let now = try date(year: 2026, month: 9, day: 16, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [historicalShift], now: now)
        viewModel.load()

        viewModel.navigateToPreviousPeriod()

        let content = try requireContent(viewModel.state)
        let breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 7),
            endExclusive: try localDate(year: 2026, month: 9, day: 14)
        )))
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [historicalShift])
        #expect(content.canNavigateNext)
    }

    @Test("Scheduled next navigation moves through a biweekly schedule toward current")
    func scheduledNextNavigationMovesTowardCurrentBiweeklyPeriod() throws {
        let anchor = try localDate(year: 2026, month: 9, day: 1)
        let job = try makeJob(cycle: .scheduled(.biweekly(anchorDate: anchor)))
        let now = try date(year: 2026, month: 9, day: 20, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [], now: now)
        viewModel.load()
        viewModel.navigateToPreviousPeriod()

        viewModel.navigateToNextPeriod()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 15),
            endExclusive: try localDate(year: 2026, month: 9, day: 29)
        )))
        #expect(content.canNavigateNext == false)
    }

    @Test("Scheduled next navigation is disabled at the current month")
    func scheduledNextNavigationStopsAtCurrentPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [], now: now)
        viewModel.load()
        let stateBeforeNavigation = viewModel.state

        viewModel.navigateToNextPeriod()

        #expect(viewModel.state == stateBeforeNavigation)
        let content = try requireContent(viewModel.state)
        #expect(content.canNavigateNext == false)
    }

    @Test("Per-shift previous navigation selects the older Shift")
    func perShiftPreviousNavigationSelectsOlderShift() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10)
        let middle = try makeShift(id: 2, day: 15)
        let latest = try makeShift(id: 3, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, middle, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        viewModel.load()

        viewModel.navigateToPreviousPeriod()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: middle.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [middle])
    }

    @Test("Per-shift next navigation returns to the newer Shift")
    func perShiftNextNavigationReturnsToNewerShift() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10)
        let latest = try makeShift(id: 2, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        viewModel.load()
        viewModel.navigateToPreviousPeriod()

        viewModel.navigateToNextPeriod()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [latest])
    }

    @Test("Per-shift navigation stops at oldest and latest boundaries")
    func perShiftNavigationStopsAtBoundaries() throws {
        let job = try makeJob(cycle: .perShift)
        let oldest = try makeShift(id: 1, day: 10)
        let latest = try makeShift(id: 2, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [oldest, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        viewModel.load()
        let latestState = viewModel.state

        viewModel.navigateToNextPeriod()
        #expect(viewModel.state == latestState)

        viewModel.navigateToPreviousPeriod()
        let oldestState = viewModel.state
        let oldestContent = try requireContent(oldestState)
        #expect(oldestContent.selectedPeriod == .perShift(shiftID: oldest.id))
        #expect(oldestContent.canNavigatePrevious == false)
        #expect(oldestContent.canNavigateNext)

        viewModel.navigateToPreviousPeriod()
        #expect(viewModel.state == oldestState)
    }

    @Test("Reload calls the storage loader again")
    func reloadCallsLoaderAgain() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return []
            },
            currentDate: { now }
        )
        viewModel.load()

        viewModel.reload()

        #expect(loadCalls == 2)
        #expect(content(from: viewModel.state) != nil)
    }

    @Test("Scheduled reload preserves the selected historical period")
    func scheduledReloadPreservesHistoricalPeriod() throws {
        let anchor = try localDate(year: 2026, month: 9, day: 7)
        let job = try makeJob(cycle: .scheduled(.weekly(anchorDate: anchor)))
        let historicalShift = try makeShift(id: 1, day: 10)
        let now = try date(year: 2026, month: 9, day: 16, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [] : [historicalShift]
            },
            currentDate: { now }
        )
        viewModel.load()
        viewModel.navigateToPreviousPeriod()
        let selectedPeriod = try requireContent(viewModel.state).selectedPeriod

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == selectedPeriod)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [historicalShift])
    }

    @Test("Per-shift reload preserves the selected Shift when it still exists")
    func perShiftReloadPreservesExistingSelection() throws {
        let job = try makeJob(cycle: .perShift)
        let oldest = try makeShift(id: 1, day: 5)
        let selected = try makeShift(id: 2, day: 10)
        let latest = try makeShift(id: 3, day: 15)
        let newLatest = try makeShift(id: 4, day: 20)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1
                    ? [oldest, selected, latest]
                    : [oldest, selected, latest, newLatest]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()
        viewModel.navigateToPreviousPeriod()

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: selected.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [selected])
        #expect(content.totalStoredShiftCount == 4)
    }

    @Test("Per-shift reload falls back to latest when selection disappears")
    func perShiftReloadFallsBackWhenSelectionDisappears() throws {
        let job = try makeJob(cycle: .perShift)
        let oldest = try makeShift(id: 1, day: 5)
        let selected = try makeShift(id: 2, day: 10)
        let latest = try makeShift(id: 3, day: 15)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [oldest, selected, latest] : [oldest, latest]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()
        viewModel.navigateToPreviousPeriod()

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [latest])
    }

    @Test("Per-shift reload transitions to the no-shift state")
    func perShiftReloadTransitionsToNoShiftState() throws {
        let job = try makeJob(cycle: .perShift)
        let shift = try makeShift(id: 1, day: 10)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [shift] : []
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == nil)
        #expect(content.expectedBreakdown == nil)
        #expect(content.totalStoredShiftCount == 0)
        #expect(content.canNavigatePrevious == false)
        #expect(content.canNavigateNext == false)
    }

    @Test("Storage load failure produces a typed presentation failure")
    func storageFailureProducesTypedFailure() throws {
        let job = try makeJob(cycle: .perShift)
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: { throw TestFailure.loading },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )

        viewModel.load()

        #expect(viewModel.state == .failure(.loading))
    }

    @Test("Retry after storage failure recovers to content")
    func retryAfterStorageFailureRecovers() throws {
        let job = try makeJob(cycle: .perShift)
        let shift = try makeShift(id: 1, day: 10)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                if loadCalls == 1 {
                    throw TestFailure.loading
                }
                return [shift]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()
        #expect(viewModel.state == .failure(.loading))

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(loadCalls == 2)
        #expect(content.selectedPeriod == .perShift(shiftID: shift.id))
    }

    @Test("Expected gross preserves exact Decimal precision")
    func expectedGrossPreservesExactDecimal() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let rate = try #require(Decimal(string: "17.125", locale: locale))
        let expected = try #require(Decimal(string: "25.6875", locale: locale))
        let job = try makeJob(cycle: .scheduled(.calendarMonthly), rate: rate)
        let shift = try makeShift(id: 1, day: 10, durationHours: 1.5)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [shift], now: now)

        viewModel.load()

        let breakdown = try #require(requireContent(viewModel.state).expectedBreakdown)
        #expect(breakdown.shiftBreakdowns.map(\.basePay) == [expected])
        #expect(breakdown.expectedGross == expected)
    }

    private func makeViewModel(job: Job, shifts: [Shift], now: Date) -> OverviewViewModel {
        OverviewViewModel(
            job: job,
            loadShifts: { shifts },
            currentDate: { now }
        )
    }

    private func makeJob(
        timeZoneIdentifier: String = "Europe/Stockholm",
        cycle: PayCalculationCycle,
        rate: Decimal = 20
    ) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: cycle,
            payRates: [try PayRate(amount: rate, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(
        id: UInt8,
        year: Int = 2026,
        month: Int = 9,
        day: Int,
        hour: Int = 8,
        durationHours: TimeInterval = 8
    ) throws -> Shift {
        let start = try date(year: year, month: month, day: day, hour: hour)
        return try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
            start: start,
            end: start.addingTimeInterval(durationHours * self.hour)
        )
    }

    private func localDate(year: Int, month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        timeZoneIdentifier: String = "Europe/Stockholm"
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        return try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    private func requireContent(
        _ state: OverviewViewModel.State
    ) throws -> OverviewViewModel.Content {
        try #require(content(from: state))
    }

    private func content(
        from state: OverviewViewModel.State
    ) -> OverviewViewModel.Content? {
        guard case let .content(content) = state else {
            return nil
        }
        return content
    }
}

private enum TestFailure: Error {
    case loading
}
