import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct WorkTypesViewControllerTests {
    @Test("Work Types renders supplied order, names, basis, and noneditable rows")
    func rendersSuppliedWorkTypes() throws {
        let first = try makeWorkType(id: 1, name: "  Lectures  ", basis: .hourly)
        let second = try makeWorkType(id: 2, name: nil, basis: .fixedPerShift)
        let viewController = WorkTypesViewController(workTypes: [second, first])
        viewController.loadViewIfNeeded()

        #expect(viewController.title == WorkTypesStrings.title)
        #expect(viewController.tableView.style == .insetGrouped)
        #expect(viewController.numberOfSections(in: viewController.tableView) == 1)
        #expect(viewController.tableView(viewController.tableView, numberOfRowsInSection: 0) == 2)

        let rows = [second, first].enumerated().map { index, _ in
            viewController.tableView(
                viewController.tableView,
                cellForRowAt: IndexPath(row: index, section: 0)
            )
        }
        let firstContent = try #require(rows[0].contentConfiguration as? UIListContentConfiguration)
        let secondContent = try #require(rows[1].contentConfiguration as? UIListContentConfiguration)
        #expect(firstContent.text == WorkTypesStrings.unnamed)
        #expect(firstContent.secondaryText == WorkTypesStrings.fixedPerShift)
        #expect(secondContent.text == "  Lectures  ")
        #expect(secondContent.secondaryText == WorkTypesStrings.hourly)

        for (cell, workType, name, basis) in [
            (rows[0], second, WorkTypesStrings.unnamed, WorkTypesStrings.fixedPerShift),
            (rows[1], first, "  Lectures  ", WorkTypesStrings.hourly)
        ] {
            let content = try #require(cell.contentConfiguration as? UIListContentConfiguration)
            #expect(cell.accessibilityIdentifier == "workTypes.row.\(workType.id.uuidString)")
            #expect(cell.accessibilityLabel == name)
            #expect(cell.accessibilityValue == basis)
            #expect(cell.selectionStyle == .none)
            #expect(cell.accessoryType == .none)
            #expect(content.textProperties.numberOfLines == 0)
            #expect(content.secondaryTextProperties.numberOfLines == 0)
            #expect(content.textProperties.font == UIFont.preferredFont(forTextStyle: .body))
            #expect(content.secondaryTextProperties.font == UIFont.preferredFont(forTextStyle: .subheadline))
        }
    }

    @Test("Reload replaces rows on the same Work Types screen")
    func reloadReplacesRows() throws {
        let first = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        let second = try makeWorkType(id: 2, name: "Exams", basis: .fixedPerShift)
        let viewController = WorkTypesViewController(workTypes: [first])
        viewController.loadViewIfNeeded()

        viewController.reload(workTypes: [second, first])

        #expect(viewController.tableView(viewController.tableView, numberOfRowsInSection: 0) == 2)
        let firstRow = viewController.tableView(
            viewController.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        #expect(firstRow.accessibilityIdentifier == "workTypes.row.\(second.id.uuidString)")
        #expect((firstRow.contentConfiguration as? UIListContentConfiguration)?.text == "Exams")
    }

    @Test("Add button exposes localized intent and emits once")
    func addButtonEmitsIntent() throws {
        let viewController = WorkTypesViewController(workTypes: [])
        var callCount = 0
        viewController.onAddWorkType = { callCount += 1 }
        viewController.loadViewIfNeeded()

        let item = try #require(viewController.navigationItem.rightBarButtonItem)
        #expect(item.accessibilityIdentifier == "workTypes.add")
        #expect(item.accessibilityLabel == WorkTypesStrings.add)
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action)
        #expect(callCount == 1)
    }

    private func makeWorkType(id: UInt8, name: String?, basis: BasePayBasis) throws -> WorkType {
        WorkType(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
            name: name,
            basePayBasis: basis,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(amount: 100, effectiveFrom: nil)
            ])
        )
    }
}
