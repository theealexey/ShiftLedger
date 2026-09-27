import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct WorkTypesViewControllerTests {
    @Test("Work Types renders supplied order, names, basis, and actionable rows")
    func rendersSuppliedWorkTypes() throws {
        let first = try makeWorkType(id: 1, name: "  Lectures  ", basis: .hourly)
        let second = try makeWorkType(id: 2, name: nil, basis: .fixedPerShift)
        let viewController = makeViewController(workTypes: [second, first])
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
            #expect(cell.accessibilityHint == WorkTypesStrings.actionsHint)
            #expect(cell.selectionStyle != .none)
            #expect(cell.accessoryType == .disclosureIndicator)
            #expect(cell.accessibilityTraits.contains(.button))
            #expect(content.textProperties.numberOfLines == 0)
            #expect(content.secondaryTextProperties.numberOfLines == 0)
            #expect(content.textProperties.font == UIFont.preferredFont(forTextStyle: .body))
            #expect(content.secondaryTextProperties.font == UIFont.preferredFont(forTextStyle: .subheadline))
        }
    }

    @Test("Selecting a row opens its exact WorkType action sheet and deselects it")
    func selectingRowOpensActions() throws {
        let first = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        let second = try makeWorkType(id: 2, name: "Lectures", basis: .fixedPerShift)
        let viewController = makeViewController(workTypes: [first, second])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        let indexPath = IndexPath(row: 1, section: 0)
        viewController.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)

        viewController.tableView(viewController.tableView, didSelectRowAt: indexPath)

        let sheet = try #require(viewController.presentedViewController as? UIAlertController)
        #expect(sheet.preferredStyle == .actionSheet)
        #expect(sheet.title == second.name)
        #expect(sheet.actions.map(\.title) == [
            WorkTypesStrings.rename,
            WorkTypesStrings.changePayRate,
            WorkTypesStrings.payRateHistory,
            WorkTypesStrings.archive,
            WorkTypesStrings.cancel
        ])
        #expect(sheet.actions.map(\.style) == [.default, .default, .default, .destructive, .cancel])
        #expect(sheet.popoverPresentationController?.sourceView != nil)
        #expect(viewController.tableView.indexPathForSelectedRow == nil)
        viewController.tableView(viewController.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        #expect(viewController.presentedViewController === sheet)
        window.isHidden = true
    }

    @Test("Unnamed row uses truthful action-sheet fallback")
    func unnamedRowActionSheet() throws {
        let unnamed = try makeWorkType(id: 1, name: nil, basis: .hourly)
        let viewController = makeViewController(workTypes: [unnamed])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.tableView(viewController.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        #expect((viewController.presentedViewController as? UIAlertController)?.title == WorkTypesStrings.unnamed)
        window.isHidden = true
    }

    @Test("Reload replaces rows on the same Work Types screen")
    func reloadReplacesRows() throws {
        let first = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        let second = try makeWorkType(id: 2, name: "Exams", basis: .fixedPerShift)
        let viewController = makeViewController(workTypes: [first])
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
        let viewController = makeViewController(workTypes: [])
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

    @Test("Active and archived rows use ordered nonempty sections and archived accessibility status")
    func groupedRows() throws {
        let active1 = try makeWorkType(id: 1, name: "A", basis: .hourly)
        let archived1 = try makeWorkType(id: 2, name: "B", basis: .fixedPerShift).archived()
        let active2 = try makeWorkType(id: 3, name: "C", basis: .hourly)
        let archived2 = try makeWorkType(id: 4, name: "D", basis: .hourly).archived()
        let controller = makeViewController(workTypes: [active1, archived1, active2, archived2])
        controller.loadViewIfNeeded()

        #expect(controller.numberOfSections(in: controller.tableView) == 2)
        #expect(controller.tableView(controller.tableView, titleForHeaderInSection: 0) == WorkTypesStrings.activeSection)
        #expect(controller.tableView(controller.tableView, titleForHeaderInSection: 1) == WorkTypesStrings.archivedSection)
        let activeRows = (0..<2).map { controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: $0, section: 0)) }
        let archivedRows = (0..<2).map { controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: $0, section: 1)) }
        #expect(activeRows.map(\.accessibilityLabel) == ["A", "C"])
        #expect(archivedRows.map(\.accessibilityLabel) == ["B", "D"])
        #expect(archivedRows.allSatisfy { $0.accessibilityValue?.contains(WorkTypesStrings.archivedStatus) == true })
        #expect(activeRows.allSatisfy { $0.accessibilityValue?.contains(WorkTypesStrings.archivedStatus) == false })
    }

    @Test("Archived row omits Archive but retains existing actions")
    func archivedActions() throws {
        let archived = try makeWorkType(id: 1, name: "Lectures", basis: .hourly).archived()
        let controller = makeViewController(workTypes: [archived])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        #expect(controller.numberOfSections(in: controller.tableView) == 1)
        #expect(controller.tableView(controller.tableView, titleForHeaderInSection: 0) == WorkTypesStrings.archivedSection)

        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        let sheet = try #require(controller.presentedViewController as? UIAlertController)
        #expect(sheet.actions.map(\.title) == [
            WorkTypesStrings.rename, WorkTypesStrings.changePayRate,
            WorkTypesStrings.payRateHistory, WorkTypesStrings.cancel
        ])
        #expect(sheet.actions.map(\.style) == [.default, .default, .default, .cancel])
        window.isHidden = true
    }

    @Test("Archive confirmation explains irreversible effect and cancel is nonmutating")
    func archiveConfirmation() throws {
        let workType = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        var calls = 0
        let controller = WorkTypesViewController(viewModel: WorkTypesViewModel(workTypes: [workType]) { _ in
            calls += 1
            return .failure(.generic)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.presentArchiveConfirmation(for: workType)

        let alert = try #require(controller.presentedViewController as? UIAlertController)
        #expect(alert.preferredStyle == .alert)
        #expect(alert.title == String(format: WorkTypesStrings.archiveConfirmationTitle, "Lectures"))
        #expect(alert.message == WorkTypesStrings.archiveConfirmationMessage)
        #expect(alert.actions.map(\.title) == [WorkTypesStrings.cancel, WorkTypesStrings.archive])
        #expect(alert.actions.map(\.style) == [.cancel, .destructive])
        #expect(calls == 0)
        window.isHidden = true
    }

    @Test("Successful archive updates the same list and reports Job without navigation")
    func successfulArchive() throws {
        let workType = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        let job = try makeJob(workTypes: [workType])
        let archivedJob = try job.archivingWorkType(id: workType.id)
        var calls: [UUID] = []
        var deliveredJob: Job?
        let controller = WorkTypesViewController(viewModel: WorkTypesViewModel(workTypes: job.workTypes) { id in
            calls.append(id)
            return .success(archivedJob)
        })
        controller.onArchived = { deliveredJob = $0 }
        controller.loadViewIfNeeded()

        controller.archive(workType)

        #expect(calls == [workType.id])
        #expect(deliveredJob == archivedJob)
        #expect(controller.numberOfSections(in: controller.tableView) == 1)
        #expect(controller.tableView(controller.tableView, titleForHeaderInSection: 0) == WorkTypesStrings.archivedSection)
        #expect(controller.navigationController == nil)
    }

    @Test("Failed archive keeps active row and shows localized error")
    func failedArchive() throws {
        let workType = try makeWorkType(id: 1, name: "Lectures", basis: .hourly)
        let controller = makeViewController(workTypes: [workType])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        controller.archive(workType)

        #expect(controller.tableView(controller.tableView, titleForHeaderInSection: 0) == WorkTypesStrings.activeSection)
        let alert = try #require(controller.presentedViewController as? UIAlertController)
        #expect(alert.title == WorkTypesStrings.archiveErrorTitle)
        #expect(alert.message == WorkTypesStrings.archiveErrorMessage)
        window.isHidden = true
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

    private func makeViewController(workTypes: [WorkType]) -> WorkTypesViewController {
        WorkTypesViewController(viewModel: WorkTypesViewModel(workTypes: workTypes) { _ in
            .failure(.generic)
        })
    }

    private func makeJob(workTypes: [WorkType]) throws -> Job {
        try Job(
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: workTypes
        )
    }
}
