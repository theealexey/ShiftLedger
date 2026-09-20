import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct AddShiftViewControllerTests {
    private let start = Date(timeIntervalSince1970: 1_788_076_800)
    private let end = Date(timeIntervalSince1970: 1_788_105_600)
    private let timeZoneIdentifier = "Europe/Stockholm"
    private let knownID = UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    @Test("Успешное сохранение очищает draft и не повторяет вставку")
    func successfulSaveResetsDraftAndPreventsDuplicate() throws {
        var persistenceCallCount = 0
        var completionCallCount = 0
        var persistedShift: Shift?
        var completedShift: Shift?
        let workType = try makeWorkType(id: testWorkTypeID, name: "Lectures")
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: [workType],
            initialStart: start,
            initialEnd: end,
            saveShift: { shift in
                persistenceCallCount += 1
                persistedShift = shift
                return .success(())
            },
            makeID: { self.knownID }
        )
        let viewController = AddShiftViewController(viewModel: viewModel)
        viewController.onSaved = { shift in
            completionCallCount += 1
            completedShift = shift
        }
        _ = viewController.view

        let workTypeRow: UIControl = try requireView("addShift.workType", in: viewController.view)
        #expect(workTypeRow.accessibilityValue == "Lectures")
        #expect(workTypeRow.accessibilityTraits.contains(.button) == false)
        #expect(workTypeRow.isUserInteractionEnabled == false)

        try tapSave(on: viewController)

        let expectedShift = try Shift(
            id: knownID,
            workTypeID: testWorkTypeID,
            start: start,
            end: end
        )
        #expect(persistenceCallCount == 1)
        #expect(completionCallCount == 1)
        #expect(persistedShift != nil)
        #expect(completedShift != nil)
        #expect(persistedShift == expectedShift)
        #expect(persistedShift == completedShift)
        #expect(viewModel.start == nil)
        #expect(viewModel.end == nil)
        #expect(viewModel.isUnpaidBreakEnabled == false)
        #expect(viewModel.canSave == false)

        try tapSave(on: viewController)

        #expect(persistenceCallCount == 1)
        #expect(completionCallCount == 1)
    }

    @Test("Ошибка сохранения не очищает draft")
    func failedSavePreservesDraftAndDoesNotFinish() throws {
        var persistenceCallCount = 0
        var completionCallCount = 0
        let workType = try makeWorkType(id: testWorkTypeID, name: "Lectures")
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: [workType],
            initialStart: start,
            initialEnd: end,
            saveShift: { _ in
                persistenceCallCount += 1
                return .failure(.generic)
            },
            makeID: { self.knownID }
        )
        let viewController = AddShiftViewController(viewModel: viewModel)
        viewController.onSaved = { _ in completionCallCount += 1 }
        _ = viewController.view

        try tapSave(on: viewController)

        #expect(persistenceCallCount == 1)
        #expect(completionCallCount == 0)
        #expect(viewModel.start == start)
        #expect(viewModel.end == end)
        #expect(viewModel.canSave)
    }

    @Test("Несколько WorkTypes показывают Select и локальный picker выбирает точный ID")
    func multipleWorkTypesPresentPickerAndSelectExactID() throws {
        let firstID = UUID(uuid: (0x51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let secondID = UUID(uuid: (0x51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        var saveCallCount = 0
        var savedShift: Shift?
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: [
                try makeWorkType(id: firstID, name: "Lectures"),
                try makeWorkType(id: secondID, name: "Exams")
            ],
            initialStart: start,
            initialEnd: end,
            saveShift: { shift in
                saveCallCount += 1
                savedShift = shift
                return .success(())
            }
        )
        let viewController = AddShiftViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        viewController.loadViewIfNeeded()

        let workTypeRow: UIControl = try requireView("addShift.workType", in: viewController.view)
        #expect(workTypeRow.accessibilityValue == AddShiftStrings.select)
        #expect(workTypeRow.accessibilityTraits.contains(.button))
        #expect(viewModel.canSave == false)

        workTypeRow.sendActions(for: .touchUpInside)
        let pickerNavigationController = try #require(
            viewController.presentedViewController as? UINavigationController
        )
        let picker = try #require(
            pickerNavigationController.topViewController as? WorkTypeSelectionViewController
        )
        picker.loadViewIfNeeded()
        picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))

        #expect(viewModel.selectedWorkTypeID == secondID)
        #expect(workTypeRow.accessibilityValue == "Exams")
        #expect(viewModel.canSave)

        try tapSave(on: viewController)

        #expect(saveCallCount == 1)
        let persistedShift = try #require(savedShift)
        #expect(persistedShift.workTypeID == secondID)
    }

    @Test("Исторический nil name отображается локализованным placeholder")
    func unnamedSoleWorkTypeUsesPresentationPlaceholder() throws {
        let workType = try makeWorkType(id: testWorkTypeID, name: nil)
        let viewController = AddShiftViewController(
            viewModel: AddShiftViewModel(
                timeZoneIdentifier: timeZoneIdentifier,
                workTypes: [workType],
                saveShift: { _ in .success(()) }
            )
        )
        viewController.loadViewIfNeeded()

        let workTypeRow: UIControl = try requireView("addShift.workType", in: viewController.view)
        #expect(workTypeRow.accessibilityValue == AddShiftStrings.unnamedWorkType)
        #expect(workType.name == nil)
    }

    private func tapSave(on viewController: AddShiftViewController) throws {
        guard
            let action = viewController.navigationItem.rightBarButtonItem?.action
        else {
            throw TestError.saveActionUnavailable
        }
        _ = viewController.perform(action)
    }

    private func makeWorkType(id: UUID, name: String?) throws -> WorkType {
        WorkType(
            id: id,
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9)),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ]
            )
        )
    }

    private func requireView<View: UIView>(_ identifier: String, in root: UIView) throws -> View {
        func find(in view: UIView) -> View? {
            if view.accessibilityIdentifier == identifier {
                return view as? View
            }
            for subview in view.subviews {
                if let match = find(in: subview) {
                    return match
                }
            }
            return nil
        }

        return try #require(find(in: root))
    }
}

private enum TestError: Error {
    case saveActionUnavailable
}
