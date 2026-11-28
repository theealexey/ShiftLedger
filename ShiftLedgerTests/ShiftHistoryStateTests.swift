import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftHistoryStateTests {
    @Test(arguments: [false, true])
    func queryAndTapsLeavePayrollContentAndHomeAlone(scheduled: Bool) throws {
        let job = try makeJob(scheduled: scheduled)
        let workID = try #require(job.soleWorkType?.id)
        let older = try shift(job: job, workID: workID, hour: 8, length: 1)
        let newer = try shift(job: job, workID: workID, hour: 10, length: 2)
        var loads = 0
        let vm = OverviewViewModel(job: job, loadShifts: { loads += 1; return [newer, older] }, currentDate: { newer.end })
        let home = OverviewViewModel(job: job, loadShifts: { [newer, older] }, currentDate: { newer.end })
        home.load()
        vm.showsShiftHistoryOnly = true
        vm.load()
        let payroll = vm.state
        let homeBefore = home.state
        vm.tapHistoryRow(newer.id)
        #expect(vm.history.expandedID == newer.id)
        #expect(vm.applyHistoryQuery(.init(sort: .oldest)))
        #expect(vm.history.visible.map(\.shift.id) == [older.id, newer.id])
        #expect(vm.history.expandedID == newer.id)
        vm.tapHistoryRow(older.id)
        #expect(vm.history.expandedID == older.id)
        #expect(vm.applyHistoryQuery(.init(minimum: 150)))
        #expect(vm.history.visible.map(\.shift.id) == [newer.id])
        #expect(vm.history.totalCount == 2)
        #expect(vm.history.selectedID == nil)
        #expect(vm.history.expandedID == nil)
        vm.tapHistoryRow(older.id)
        #expect(vm.history.expandedID == nil)
        #expect(vm.updateHistorySearch("No such work type or date"))
        #expect(vm.history.visible.isEmpty)
        #expect(vm.history.query.minimum == 150)
        #expect(vm.updateHistorySearch(""))
        #expect(vm.history.visible.map(\.shift.id) == [newer.id])
        #expect(vm.updateHistoryFilters(from: .init(sort: .oldest, searchText: "Stale draft")))
        #expect(vm.history.query == .init())
        #expect(vm.history.expandedID == nil)
        #expect(loads == 1)
        #expect(vm.state == payroll)
        #expect(home.state == homeBefore)
    }

    @Test func reloadRetainsFiltersAndOptionsAndDifferentJobClearsState() throws {
        let rate = try PayRate(amount: 100, effectiveFrom: nil)
        let active = WorkType(id: UUID(), name: "Active", basePayBasis: .hourly,
                              payRateHistory: try PayRateHistory(payRates: [rate]))
        let archived = WorkType(id: UUID(), name: "Past", basePayBasis: .hourly,
                                payRateHistory: try PayRateHistory(payRates: [rate]), isArchived: true)
        let job = try Job(id: UUID(), currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                          payCalculationCycle: .perShift, workTypes: [active, archived])
        let older = try shift(job: job, workID: archived.id, hour: 8, length: 1)
        let newer = try shift(job: job, workID: active.id, hour: 10, length: 2)
        let renamed = try job.renamingWorkType(id: active.id, to: "Renamed")
        let fixture = ShiftRows([older, newer])
        let different = try makeJob(scheduled: false)
        let vm = OverviewViewModel(job: job, loadShiftsForJob: { $0 == job.id ? fixture.rows : [] },
                                   currentDate: { newer.end })
        vm.showsShiftHistoryOnly = true
        vm.load()
        #expect(vm.applyHistoryQuery(.init(workTypeIDs: [active.id], minimum: 150, sort: .highest)))
        #expect(vm.historyWorkTypes(locale: .current).contains { $0.id == archived.id && $0.isArchived })
        #expect(vm.updateHistorySearch("Active"))
        vm.tapHistoryRow(newer.id)
        vm.reload(job: renamed)
        #expect(vm.history.query.searchText == "Active")
        #expect(vm.history.visible.isEmpty)
        #expect(vm.history.expandedID == nil)
        #expect(vm.updateHistorySearch("Renamed"))
        #expect(vm.history.expandedID == nil)
        vm.tapHistoryRow(newer.id)
        vm.reload(job: renamed)
        #expect(vm.historyWorkTypes(locale: .current).first { $0.id == active.id }?.name == "Renamed")
        #expect(vm.history.expandedID == newer.id)
        vm.reload(selectingShiftID: newer.id)
        #expect(vm.history.selectedID == newer.id)
        #expect(vm.history.expandedID == nil)
        fixture.rows = [older, try Shift(id: newer.id, jobID: job.id, workTypeID: active.id,
                                 start: newer.start, end: newer.start.addingTimeInterval(3600))]
        vm.reload(selectingShiftID: newer.id)
        #expect(vm.history.visible.isEmpty)
        #expect(vm.history.totalCount == 2)
        #expect(vm.history.selectedID == nil)
        fixture.rows.removeLast()
        vm.reload()
        #expect(vm.history.totalCount == 1)
        #expect(vm.history.query.sort == .highest)
        vm.reload(job: different)
        #expect(vm.history == OverviewViewModel.History())
    }

    private func makeJob(scheduled: Bool) throws -> Job {
        try Job(currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm", basePayBasis: .hourly,
                payCalculationCycle: scheduled ? .scheduled(.calendarMonthly) : .perShift,
                payRates: [PayRate(amount: 100, effectiveFrom: nil)])
    }

    private func shift(job: Job, workID: UUID, hour: Int, length: Int) throws -> Shift {
        let day = Date(timeIntervalSince1970: 1_800_057_600)
        let start = day.addingTimeInterval(Double(hour * 3600))
        return try Shift(jobID: job.id, workTypeID: workID, start: start,
                         end: start.addingTimeInterval(Double(length * 3600)))
    }
}

@MainActor
private final class ShiftRows {
    var rows: [Shift]

    init(_ rows: [Shift]) {
        self.rows = rows
    }
}
