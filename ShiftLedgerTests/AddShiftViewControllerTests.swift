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
        var saveCalls = 0
        var savedShift: Shift?
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            initialStart: start,
            initialEnd: end,
            saveShift: { shift in
                saveCalls += 1
                savedShift = shift
                return .success(())
            },
            makeID: { self.knownID }
        )
        let viewController = AddShiftViewController(viewModel: viewModel)
        viewController.onSaved = { savedShift = $0 }
        _ = viewController.view

        try tapSave(on: viewController)

        let expectedShift = try Shift(id: knownID, start: start, end: end)
        #expect(saveCalls == 1)
        #expect(savedShift == expectedShift)
        #expect(viewModel.start == nil)
        #expect(viewModel.end == nil)
        #expect(viewModel.isUnpaidBreakEnabled == false)
        #expect(viewModel.canSave == false)

        try tapSave(on: viewController)

        #expect(saveCalls == 1)
    }

    @Test("Ошибка сохранения не очищает draft")
    func failedSavePreservesDraftAndDoesNotFinish() throws {
        var saveCalls = 0
        var finished = false
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            initialStart: start,
            initialEnd: end,
            saveShift: { _ in
                saveCalls += 1
                return .failure(.generic)
            },
            makeID: { self.knownID }
        )
        let viewController = AddShiftViewController(viewModel: viewModel)
        viewController.onSaved = { _ in finished = true }
        _ = viewController.view

        try tapSave(on: viewController)

        #expect(saveCalls == 1)
        #expect(finished == false)
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
