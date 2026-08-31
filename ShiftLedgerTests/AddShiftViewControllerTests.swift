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
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
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

        try tapSave(on: viewController)

        let expectedShift = try Shift(id: knownID, start: start, end: end)
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
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
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

    private func tapSave(on viewController: AddShiftViewController) throws {
        guard
            let action = viewController.navigationItem.rightBarButtonItem?.action
        else {
            throw TestError.saveActionUnavailable
        }
        _ = viewController.perform(action)
    }
}

private enum TestError: Error {
    case saveActionUnavailable
}
