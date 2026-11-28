import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct ShiftHistoryControllerTests {
    @Test func initialOpeningAfterJobReloadShowsBothShiftsAndPreservesOrder() throws {
        let fixture = try Fixture()
        fixture.rows = [fixture.older]
        fixture.controller.reload(job: fixture.job)
        #expect(!fixture.controller.isViewLoaded)

        fixture.rows.append(fixture.newer)
        fixture.controller.loadViewIfNeeded()
        #expect(try fixture.visibleIDs() == [fixture.newer.id, fixture.older.id])

        try fixture.search("desk")
        #expect(try fixture.visibleIDs() == [fixture.newer.id, fixture.older.id])
        for (sort, expected) in [
            (ShiftHistoryQuery.Sort.highest, [fixture.older.id, fixture.newer.id]),
            (.lowest, [fixture.newer.id, fixture.older.id]),
            (.oldest, [fixture.older.id, fixture.newer.id]),
            (.newest, [fixture.newer.id, fixture.older.id])
        ] {
            try fixture.sort(sort)
            #expect(try fixture.visibleIDs() == expected)
        }
        try fixture.search("Day")
        #expect(try fixture.visibleIDs() == [fixture.older.id])
    }

    @Test func editingUpdatesDateAmountAndWorkTypeInTheRenderedRow() throws {
        let fixture = try Fixture()
        let row = try fixture.row(fixture.older.id)
        let oldDate = try fixture.label("date", in: row)
        #expect(try fixture.label("expected", in: row) == "€1.00")
        row.sendActions(for: .touchUpInside)
        #expect(try fixture.label("detail.exactContribution", in: row) == "€1.004")

        let edited = try fixture.moveOlderShiftToNewWorkType()
        fixture.controller.reload(selectingShiftID: edited.id)
        #expect(try fixture.visibleIDs() == [edited.id, fixture.newer.id])
        let updated = try fixture.row(edited.id)
        #expect(try fixture.label("date", in: updated) != oldDate)
        #expect(try fixture.label("expected", in: updated) == "€1.00")
        updated.sendActions(for: .touchUpInside)
        #expect(try fixture.label("detail.workType", in: updated) == "Night Desk")
        #expect(try fixture.label("detail.exactContribution", in: updated) == "€1.003")
    }

    @Test func renameAffectsDetailsAndSearchAndDeletedShiftStaysAbsent() throws {
        let fixture = try Fixture()
        try fixture.search("Day Desk")
        #expect(try fixture.visibleIDs() == [fixture.older.id])

        fixture.controller.reload(job: try fixture.job.renamingWorkType(id: fixture.older.workTypeID, to: "Morning Desk"))
        #expect(try fixture.visibleIDs().isEmpty)
        try fixture.search("Morning")
        #expect(try fixture.visibleIDs() == [fixture.older.id])
        let row = try fixture.row(fixture.older.id)
        row.sendActions(for: .touchUpInside)
        #expect(try fixture.label("detail.workType", in: row) == "Morning Desk")

        fixture.rows.removeAll { $0.id == fixture.older.id }
        fixture.controller.reload()
        #expect(try fixture.visibleIDs().isEmpty)
        try fixture.search("")
        #expect(try fixture.visibleIDs() == [fixture.newer.id])
    }

    @Test func retryAfterLoadFailureBuildsFromTheCurrentHistory() throws {
        let fixture = try Fixture()
        #expect(try fixture.visibleIDs() == [fixture.newer.id, fixture.older.id])

        fixture.failLoads = true
        fixture.controller.reload()
        let root = try #require(fixture.controller.view)
        let retry = try #require(fixture.find("overview.error.retry", in: root) as? UIButton)
        #expect(fixture.isVisible(retry))
        fixture.rows = [fixture.newer]
        fixture.failLoads = false
        retry.sendActions(for: .touchUpInside)
        #expect(try fixture.visibleIDs() == [fixture.newer.id])
        #expect(!fixture.isVisible(retry))
    }

    @MainActor
    private final class Fixture {
        let job: Job
        let older: Shift
        let newer: Shift
        var rows: [Shift]
        var failLoads = false
        private enum FixtureError: Error { case load }
        private let now = Date(timeIntervalSince1970: 1_800_000_000)

        private lazy var viewModel = OverviewViewModel(
            job: job, loadShifts: { [unowned self] in
                if failLoads { throw FixtureError.load }
                return rows
            }, currentDate: { [now] in now }
        )

        lazy var controller: OverviewViewController = {
            let controller = OverviewViewController(viewModel: viewModel, currencyCode: job.currencyCode,
                                                    timeZoneIdentifier: job.timeZoneIdentifier,
                                                    displayLocale: Locale(identifier: "en_US"))
            controller.showsShiftHistoryOnly = true
            return controller
        }()

        init() throws {
            let locale = Locale(identifier: "en_US_POSIX")
            let high = try #require(Decimal(string: "1.004", locale: locale))
            let low = try #require(Decimal(string: "1.003", locale: locale))
            let day = WorkType(id: UUID(), name: "Day Desk", basePayBasis: .fixedPerShift,
                               payRateHistory: try PayRateHistory(payRates: [PayRate(amount: high, effectiveFrom: nil)]))
            let night = WorkType(id: UUID(), name: "Night Desk", basePayBasis: .fixedPerShift,
                                 payRateHistory: try PayRateHistory(payRates: [PayRate(amount: low, effectiveFrom: nil)]))
            job = try Job(currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                          payCalculationCycle: .perShift, workTypes: [day, night])
            older = try Shift(jobID: job.id, workTypeID: day.id, start: now, end: now.addingTimeInterval(3600))
            let next = now.addingTimeInterval(86400)
            newer = try Shift(jobID: job.id, workTypeID: night.id, start: next, end: next.addingTimeInterval(3600))
            rows = [older, newer]
        }

        func moveOlderShiftToNewWorkType() throws -> Shift {
            let start = newer.start.addingTimeInterval(86400)
            let edited = try Shift(id: older.id, jobID: job.id, workTypeID: newer.workTypeID,
                                   start: start, end: start.addingTimeInterval(3600))
            rows = [edited, newer]
            return edited
        }

        func search(_ text: String) throws {
            let field = try #require(find("shiftHistory.search", in: controller.view) as? UISearchTextField)
            field.text = text
            field.sendActions(for: .editingChanged)
        }

        func sort(_ order: ShiftHistoryQuery.Sort) throws {
            let view = try #require(controller.view as? OverviewView)
            let action = try #require(view.onHistorySort)
            action(order)
        }

        func visibleIDs() throws -> [UUID] {
            let ledger = try #require(findLedger(in: controller.view))
            return try (ledger.accessibilityElements ?? []).compactMap { element in
                guard let row = element as? OverviewShiftLedgerRowView else { return nil }
                let identifier = try #require(row.accessibilityIdentifier)
                return try #require(UUID(uuidString: String(identifier.dropFirst("overview.shift.".count))))
            }
        }

        func row(_ id: UUID) throws -> OverviewShiftLedgerRowView {
            try #require(find("overview.shift.\(id.uuidString)", in: controller.view) as? OverviewShiftLedgerRowView)
        }

        func label(_ suffix: String, in row: UIView) throws -> String {
            let id = try #require(row.accessibilityIdentifier)
            let label = try #require(find("\(id).\(suffix)", in: row) as? UILabel)
            return try #require(label.text)
        }

        func find(_ id: String, in root: UIView) -> UIView? {
            if root.accessibilityIdentifier == id { return root }
            return root.subviews.lazy.compactMap { self.find(id, in: $0) }.first
        }

        func isVisible(_ view: UIView) -> Bool {
            if view.isHidden { return false }
            guard let parent = view.superview else { return true }
            return isVisible(parent)
        }

        private func findLedger(in root: UIView) -> OverviewShiftLedgerView? {
            if let ledger = root as? OverviewShiftLedgerView { return ledger }
            return root.subviews.lazy.compactMap { self.findLedger(in: $0) }.first
        }
    }
}
