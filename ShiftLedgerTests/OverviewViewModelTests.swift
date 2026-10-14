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
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
        #expect(content.shiftHistoryBreakdowns.isEmpty)
        #expect(content.railPeriods.isEmpty)
        #expect(content.showPeriodNavigation == false)
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
            shifts: [latest, older],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )

        viewModel.load()

        let content = try requireContent(viewModel.state)
        let breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [latest])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, latest])
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.railPeriods.isEmpty)
        #expect(content.showPeriodNavigation == false)
        #expect(content.canNavigatePrevious == false)
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
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [augustShift])
        #expect(content.showPeriodNavigation)
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
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
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, septemberFirst, septemberSecond, october])
        #expect(content.showPeriodNavigation)
    }

    @Test("Tapping an older card selects its payroll context while retaining every persisted Shift")
    func perShiftCardSelectsPayrollContext() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10, durationHours: 4)
        let latest = try makeShift(id: 2, day: 20, durationHours: 8)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )

        viewModel.load()

        var content = try requireContent(viewModel.state)
        #expect(content.expectedBreakdown?.expectedGross == Decimal(160))
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, latest])
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expandedShiftID == nil)

        viewModel.handleShiftCardTap(with: older.id)

        content = try requireContent(viewModel.state)
        #expect(content.expectedBreakdown?.expectedGross == Decimal(80))
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, latest])
        #expect(content.selectedShiftID == older.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.selectedPeriod == .perShift(shiftID: older.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [older])
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

    @Test("Per-shift Previous cannot create a second selector")
    func perShiftPreviousNavigationDoesNotChangeSelection() throws {
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
        let selectedState = viewModel.state

        viewModel.navigateToPreviousPeriod()

        let content = try requireContent(viewModel.state)
        #expect(viewModel.state == selectedState)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [latest])
    }

    @Test("Per-shift Next cannot override card selection")
    func perShiftNextNavigationDoesNotChangeSelection() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10)
        let latest = try makeShift(id: 2, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, latest],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        viewModel.load()
        viewModel.handleShiftCardTap(with: older.id)
        let selectedState = viewModel.state

        viewModel.navigateToNextPeriod()

        let content = try requireContent(viewModel.state)
        #expect(viewModel.state == selectedState)
        #expect(content.selectedPeriod == .perShift(shiftID: older.id))
        #expect(content.selectedShiftID == older.id)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [older])
    }

    @Test("Per-shift selectPeriod cannot override the selected card")
    func perShiftSelectPeriodDoesNotChangeSelection() throws {
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

        viewModel.selectPeriod(.perShift(shiftID: oldest.id))
        #expect(viewModel.state == latestState)

        viewModel.selectPeriod(.scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )))
        #expect(viewModel.state == latestState)
        let content = try requireContent(viewModel.state)
        #expect(content.selectedShiftID == latest.id)
        #expect(content.canNavigatePrevious == false)
        #expect(content.canNavigateNext == false)
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

    @Test("Reload selecting a saved Shift keeps its current scheduled period and exposes its ID")
    func reloadSelectingSavedShiftKeepsCurrentScheduledPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let existing = try makeShift(id: 1, day: 10)
        let saved = try makeShift(id: 2, day: 20)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [existing] : [existing, saved]
            },
            currentDate: { now }
        )
        viewModel.load()
        let initialPeriod = try requireContent(viewModel.state).selectedPeriod

        viewModel.reload(selectingShiftID: saved.id)

        let content = try requireContent(viewModel.state)
        #expect(loadCalls == 2)
        #expect(content.selectedPeriod == initialPeriod)
        #expect(content.selectedShiftID == saved.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [existing, saved])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [existing, saved])
    }

    @Test("Reload selecting a saved Shift switches to its scheduled period")
    func reloadSelectingSavedShiftSwitchesToHistoricalScheduledPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let historical = try makeShift(id: 1, month: 8, day: 20)
        let current = try makeShift(id: 2, month: 9, day: 20)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [current] : [historical, current]
            },
            currentDate: { now }
        )
        viewModel.load()

        viewModel.reload(selectingShiftID: historical.id)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 1),
            endExclusive: try localDate(year: 2026, month: 9, day: 1)
        )))
        #expect(content.selectedShiftID == historical.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [historical])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [historical, current])
    }

    @Test("Reload follows an edited Shift with the same ID into its historical period")
    func reloadSelectingEditedShiftMovesToHistoricalPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let original = try makeShift(id: 1, month: 9, day: 20)
        let editedStart = try date(year: 2026, month: 8, day: 20, hour: 8)
        let edited = try Shift(
            id: original.id,
            jobID: job.id,
            workTypeID: original.workTypeID,
            start: editedStart,
            end: editedStart.addingTimeInterval(4 * hour)
        )
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [original] : [edited]
            },
            currentDate: { now }
        )
        viewModel.load()

        viewModel.reload(selectingShiftID: original.id)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 1),
            endExclusive: try localDate(year: 2026, month: 9, day: 1)
        )))
        #expect(content.selectedShiftID == original.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [edited])
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [edited])
        #expect(content.expectedBreakdown?.expectedGross == Decimal(80))
    }

    @Test("Reload selecting a saved Shift uses its persisted per-shift period")
    func reloadSelectingSavedShiftUsesPersistedPerShiftPeriod() throws {
        let job = try makeJob(cycle: .perShift)
        let existing = try makeShift(id: 1, day: 10)
        let saved = try makeShift(id: 2, day: 20)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [existing] : [existing, saved]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()

        viewModel.reload(selectingShiftID: saved.id)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: saved.id))
        #expect(content.selectedShiftID == saved.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [saved])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [existing, saved])
    }

    @Test("Reload with a missing saved Shift ID falls back to normal persisted content")
    func reloadSelectingMissingShiftFallsBackToNormalContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let existing = try makeShift(id: 1, day: 10)
        let missingID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [existing], now: now)
        viewModel.load()

        viewModel.reload(selectingShiftID: missingID)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [existing])
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
        viewModel.handleShiftCardTap(with: selected.id)
        viewModel.handleShiftCardTap(with: selected.id)

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: selected.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [selected])
        #expect(content.selectedShiftID == selected.id)
        #expect(content.expandedShiftID == selected.id)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [oldest, selected, latest, newLatest])
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
        viewModel.handleShiftCardTap(with: selected.id)
        viewModel.handleShiftCardTap(with: selected.id)

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expandedShiftID == nil)
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
        viewModel.handleShiftCardTap(with: shift.id)

        viewModel.reload()

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == nil)
        #expect(content.expectedBreakdown == nil)
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
        #expect(content.shiftHistoryBreakdowns.isEmpty)
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

    @Test("Scheduled rail exposes a real previous period and never a future period")
    func scheduledRailUsesCurrentPeriodAsForwardBoundary() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [], now: now)

        viewModel.load()

        let content = try requireContent(viewModel.state)
        #expect(content.railPeriods.map(\.period) == [
            .scheduled(PayPeriod(
                start: try localDate(year: 2026, month: 8, day: 1),
                endExclusive: try localDate(year: 2026, month: 9, day: 1)
            )),
            .scheduled(PayPeriod(
                start: try localDate(year: 2026, month: 9, day: 1),
                endExclusive: try localDate(year: 2026, month: 10, day: 1)
            ))
        ])
    }

    @Test("Selecting a scheduled rail period updates the period and its breakdown")
    func selectingScheduledRailPeriodUpdatesContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 20)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = makeViewModel(job: job, shifts: [august, september], now: now)
        viewModel.load()
        let historicalPeriod = try #require(requireContent(viewModel.state).railPeriods.first?.period)

        viewModel.selectPeriod(historicalPeriod)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == historicalPeriod)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [august])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
        #expect(content.canNavigateNext)
    }

    @Test("Per-shift mode exposes only the Shift deck as its selector")
    func perShiftDoesNotExposeRailNavigation() throws {
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
        #expect(content.railPeriods.isEmpty)
        #expect(content.showPeriodNavigation == false)
        #expect(content.canNavigatePrevious == false)
        #expect(content.canNavigateNext == false)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, latest])
        #expect(content.selectedPeriod == .perShift(shiftID: latest.id))
        #expect(content.selectedShiftID == latest.id)
    }

    @Test("Tapping the selected per-shift card toggles details without changing payroll selection")
    func perShiftExpansionDoesNotChangePayrollSelection() throws {
        let job = try makeJob(cycle: .perShift)
        let shift = try makeShift(id: 1, day: 10, durationHours: 4)
        let viewModel = makeViewModel(
            job: job,
            shifts: [shift],
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        viewModel.load()
        let initial = try requireContent(viewModel.state)
        #expect(initial.expandedShiftID == nil)

        viewModel.handleShiftCardTap(with: shift.id)
        var content = try requireContent(viewModel.state)
        #expect(content.expandedShiftID == shift.id)
        #expect(content.selectedShiftID == shift.id)
        #expect(content.selectedPeriod == initial.selectedPeriod)
        #expect(content.expectedBreakdown == initial.expectedBreakdown)

        viewModel.handleShiftCardTap(with: shift.id)
        content = try requireContent(viewModel.state)
        #expect(content.expandedShiftID == nil)
        #expect(content.selectedShiftID == shift.id)
        #expect(content.selectedPeriod == initial.selectedPeriod)
        #expect(content.expectedBreakdown == initial.expectedBreakdown)

        viewModel.handleShiftCardTap(with: shift.id)
        content = try requireContent(viewModel.state)
        #expect(content.expandedShiftID == shift.id)
        #expect(content.selectedShiftID == shift.id)
        #expect(content.selectedPeriod == initial.selectedPeriod)
        #expect(content.expectedBreakdown == initial.expectedBreakdown)
    }

    @Test("Reload selecting an edited per-shift ID uses only its fresh persisted value")
    func perShiftReloadSelectsEditedPersistedIdentity() throws {
        let job = try makeJob(cycle: .perShift)
        let original = try makeShift(id: 1, day: 10, durationHours: 8)
        let edited = try makeShift(id: 1, day: 5, durationHours: 4)
        let newer = try makeShift(id: 2, day: 20)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [original, newer] : [newer, edited]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()

        viewModel.reload(selectingShiftID: original.id)

        let content = try requireContent(viewModel.state)
        #expect(loadCalls == 2)
        #expect(content.selectedPeriod == .perShift(shiftID: original.id))
        #expect(content.selectedShiftID == original.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [edited])
        #expect(content.expectedBreakdown?.expectedGross == Decimal(80))
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [edited, newer])
    }

    @Test("Scheduled Previous and Next change payroll while preserving global history and expansion")
    func scheduledNavigationPreservesGlobalHistory() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20, durationHours: 4)
        let september = try makeShift(id: 2, month: 9, day: 20, durationHours: 8)
        let viewModel = makeViewModel(
            job: job,
            shifts: [august, september],
            now: try date(year: 2026, month: 9, day: 18, hour: 12)
        )
        viewModel.load()
        viewModel.handleShiftCardTap(with: september.id)
        viewModel.handleShiftCardTap(with: september.id)
        let currentPeriod = try #require(requireContent(viewModel.state).selectedPeriod)

        viewModel.navigateToPreviousPeriod()

        var content = try requireContent(viewModel.state)
        var breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == breakdown.period)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 8, day: 1),
            endExclusive: try localDate(year: 2026, month: 9, day: 1)
        )))
        #expect(breakdown.expectedGross == Decimal(80))
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [august])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
        #expect(content.selectedShiftID == september.id)
        #expect(content.expandedShiftID == september.id)

        viewModel.handleShiftCardTap(with: august.id)
        viewModel.handleShiftCardTap(with: august.id)
        viewModel.navigateToNextPeriod()

        content = try requireContent(viewModel.state)
        breakdown = try #require(content.expectedBreakdown)
        #expect(content.selectedPeriod == currentPeriod)
        #expect(content.selectedPeriod == breakdown.period)
        #expect(breakdown.expectedGross == Decimal(160))
        #expect(breakdown.shiftBreakdowns.map(\.shift) == [september])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
        #expect(content.selectedShiftID == august.id)
        #expect(content.expandedShiftID == august.id)
    }

    @Test("Selecting a scheduled rail period preserves an out-of-period expanded card")
    func scheduledRailSelectionPreservesGlobalCardState() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [august, september],
            now: try date(year: 2026, month: 9, day: 18, hour: 12)
        )
        viewModel.load()
        viewModel.handleShiftCardTap(with: september.id)
        viewModel.handleShiftCardTap(with: september.id)
        let historical = try #require(requireContent(viewModel.state).railPeriods.first?.period)

        viewModel.selectPeriod(historical)

        let content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == historical)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [august])
        #expect(content.selectedShiftID == september.id)
        #expect(content.expandedShiftID == september.id)
        viewModel.handleShiftCardTap(with: september.id)
        let collapsed = try requireContent(viewModel.state)
        #expect(collapsed.selectedPeriod == historical)
        #expect(collapsed.selectedShiftID == september.id)
        #expect(collapsed.expandedShiftID == nil)
    }

    @Test("Populated and empty scheduled periods preserve global history, expansion and reload identity")
    func scheduledGlobalHistoryAcrossEmptyPeriodAndReload() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20, durationHours: 4)
        let october = try makeShift(id: 2, month: 10, day: 10, durationHours: 8)
        var loadCalls = 0
        let now = try date(year: 2026, month: 10, day: 18, hour: 12)
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls < 3 ? [october, august] : [october]
            },
            currentDate: { now }
        )
        viewModel.load()
        let initial = try requireContent(viewModel.state)
        #expect(initial.expectedBreakdown?.expectedGross == Decimal(160))
        #expect(initial.shiftHistoryBreakdowns.map(\.shift) == [august, october])
        #expect(initial.shiftHistoryBreakdowns.map(\.basePay) == [Decimal(80), Decimal(160)])
        viewModel.handleShiftCardTap(with: august.id)
        viewModel.handleShiftCardTap(with: august.id)
        #expect(try requireContent(viewModel.state).selectedPeriod == initial.selectedPeriod)
        #expect(try requireContent(viewModel.state).expectedBreakdown == initial.expectedBreakdown)

        viewModel.navigateToPreviousPeriod()
        var content = try requireContent(viewModel.state)
        let september = PayCalculationPeriod.scheduled(PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        ))
        #expect(content.selectedPeriod == september)
        #expect(content.expectedBreakdown?.expectedGross == .zero)
        #expect(content.shiftHistoryBreakdowns == initial.shiftHistoryBreakdowns)
        #expect(content.selectedShiftID == august.id)
        #expect(content.expandedShiftID == august.id)
        viewModel.navigateToPreviousPeriod()
        content = try requireContent(viewModel.state)
        #expect(content.expectedBreakdown?.expectedGross == Decimal(80))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [august])
        #expect(content.shiftHistoryBreakdowns == initial.shiftHistoryBreakdowns)
        viewModel.navigateToNextPeriod()
        viewModel.navigateToNextPeriod()
        content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == initial.selectedPeriod)
        #expect(content.expectedBreakdown == initial.expectedBreakdown)
        #expect(content.selectedShiftID == august.id)
        #expect(content.expandedShiftID == august.id)
        viewModel.selectPeriod(september)
        viewModel.reload()
        content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == september)
        #expect(content.selectedShiftID == august.id)
        #expect(content.expandedShiftID == august.id)
        #expect(content.shiftHistoryBreakdowns == initial.shiftHistoryBreakdowns)
        viewModel.reload()
        content = try requireContent(viewModel.state)
        #expect(content.selectedPeriod == september)
        #expect(content.expectedBreakdown?.expectedGross == .zero)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [october])
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
    }

    @Test("Card taps separate selection from expansion without changing scheduled payroll")
    func selectingShiftControlsSingleExpandedCard() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, day: 10)
        let newer = try makeShift(id: 2, day: 20)
        let viewModel = makeViewModel(
            job: job,
            shifts: [older, newer],
            now: try date(year: 2026, month: 9, day: 18, hour: 12)
        )
        viewModel.load()
        let initial = try requireContent(viewModel.state)
        #expect(initial.selectedShiftID == nil)
        #expect(initial.expandedShiftID == nil)

        for (id, expectedExpansion) in [
            (newer.id, nil), (newer.id, newer.id),
            (older.id, nil), (older.id, older.id), (older.id, nil)
        ] as [(UUID, UUID?)] {
            viewModel.handleShiftCardTap(with: id)
            let content = try requireContent(viewModel.state)
            #expect(content.selectedShiftID == id)
            #expect(content.expandedShiftID == expectedExpansion)
            #expect(content.selectedPeriod == initial.selectedPeriod)
            #expect(content.expectedBreakdown == initial.expectedBreakdown)
        }
    }

    @Test("Deleting another Shift preserves selected expanded payroll context")
    func removingNonSelectedShiftPreservesSelectionAndExpansion() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, day: 10)
        let latest = try makeShift(id: 2, day: 20)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [older, latest] : [latest]
            },
            currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
        )
        viewModel.load()
        viewModel.handleShiftCardTap(with: latest.id)
        let before = try requireContent(viewModel.state)
        viewModel.reload()
        let content = try requireContent(viewModel.state)
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expandedShiftID == latest.id)
        #expect(content.selectedPeriod == before.selectedPeriod)
        #expect(content.expectedBreakdown == before.expectedBreakdown)
    }

    @Test("Ordinary reload preserves an expanded persisted Shift and clears it when persistence removes it")
    func reloadPreservesOrClearsExpandedShift() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, day: 10)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        var loadCalls = 0
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls < 3 ? [shift] : []
            },
            currentDate: { now }
        )
        viewModel.load()
        viewModel.handleShiftCardTap(with: shift.id)
        viewModel.handleShiftCardTap(with: shift.id)

        viewModel.reload()
        var content = try requireContent(viewModel.state)
        #expect(content.selectedShiftID == shift.id)
        #expect(content.expandedShiftID == shift.id)

        viewModel.reload()
        content = try requireContent(viewModel.state)
        #expect(content.selectedShiftID == nil)
        #expect(content.expandedShiftID == nil)
    }

    @Test("reload(job:) заменяет aggregate и рассчитывает Shift нового WorkType")
    func reloadJobUsesUpdatedWorkTypes() throws {
        let initialJob = try makeJob(cycle: .perShift)
        let secondID = UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let second = WorkType(
            id: secondID,
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(
                    id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                    amount: 500,
                    effectiveFrom: nil
                )
            ])
        )
        let updatedJob = try Job(
            id: initialJob.id,
            currencyCode: initialJob.currencyCode,
            timeZoneIdentifier: initialJob.timeZoneIdentifier,
            payCalculationCycle: initialJob.payCalculationCycle,
            workTypes: initialJob.workTypes + [second],
            createdAt: initialJob.createdAt
        )
        let start = try date(year: 2026, month: 9, day: 20, hour: 8)
        let shift = try Shift(
            jobID: initialJob.id,
            workTypeID: secondID,
            start: start,
            end: start.addingTimeInterval(hour)
        )
        let viewModel = OverviewViewModel(
            job: initialJob,
            loadShifts: { [shift] },
            currentDate: { start }
        )

        viewModel.reload(job: updatedJob)

        let content = try requireContent(viewModel.state)
        #expect(content.expectedBreakdown?.expectedGross == Decimal(500))
        #expect(content.shiftHistoryBreakdowns.first?.shift.workTypeID == secondID)
        #expect(content.shiftHistoryBreakdowns.first?.basePayBasis == .fixedPerShift)
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
            id: testWorkTypeID,
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
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
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
