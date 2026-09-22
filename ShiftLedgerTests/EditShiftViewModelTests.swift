import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct EditShiftViewModelTests {
    private let shiftID = UUID(uuid: (0x83, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let start = Date(timeIntervalSinceReferenceDate: 200_000)
    private let end = Date(timeIntervalSinceReferenceDate: 228_800)

    @Test("Initial state точно отражает Shift и не выбирает first WorkType")
    func initialStateMirrorsShift() throws {
        let workTypes = try makeWorkTypes()
        let unpaidBreak = UnpaidBreak(
            start: start.addingTimeInterval(3_600),
            end: start.addingTimeInterval(7_200)
        )
        let shift = try Shift(
            id: shiftID,
            workTypeID: workTypes[1].id,
            start: start,
            end: end,
            unpaidBreak: unpaidBreak
        )
        let viewModel = makeViewModel(workTypes: workTypes, shift: shift)

        #expect(viewModel.selectedWorkTypeID == workTypes[1].id)
        #expect(viewModel.start == start)
        #expect(viewModel.end == end)
        #expect(viewModel.isUnpaidBreakEnabled)
        #expect(viewModel.breakStart == unpaidBreak.start)
        #expect(viewModel.breakEnd == unpaidBreak.end)
        #expect(viewModel.canSave)
    }

    @Test("Unchanged Shift сохраняется с исходным UUID один раз")
    func unchangedSavePreservesIdentityAndBlocksDuplicate() throws {
        let workTypes = try makeWorkTypes()
        let shift = try makeShift(workTypeID: workTypes[0].id)
        var persisted: [Shift] = []
        let viewModel = makeViewModel(workTypes: workTypes, shift: shift) { updated in
            persisted.append(updated)
            return .success(())
        }

        #expect(viewModel.save() == .saved(shift))
        #expect(viewModel.save() == .ignored)
        #expect(persisted == [shift])
        #expect(persisted.first?.id == shiftID)
    }

    @Test("WorkType, dates и break формируют exact updated Shift")
    func changedFieldsProduceExactShift() throws {
        let workTypes = try makeWorkTypes()
        let original = try makeShift(workTypeID: workTypes[0].id)
        let viewModel = makeViewModel(workTypes: workTypes, shift: original)
        let newStart = start.addingTimeInterval(86_400)
        let newEnd = newStart.addingTimeInterval(10_800)
        let breakStart = newStart.addingTimeInterval(3_600)
        let breakEnd = newStart.addingTimeInterval(5_400)

        #expect(viewModel.selectWorkType(id: workTypes[1].id))
        viewModel.setStart(newStart)
        viewModel.setEnd(newEnd)
        viewModel.setUnpaidBreakEnabled(true)
        viewModel.setBreakStart(breakStart)
        viewModel.setBreakEnd(breakEnd)

        let updated = try viewModel.makeShift()
        #expect(updated.id == original.id)
        #expect(updated.workTypeID == workTypes[1].id)
        #expect(updated.start == newStart)
        #expect(updated.end == newEnd)
        #expect(updated.unpaidBreak == UnpaidBreak(start: breakStart, end: breakEnd))
    }

    @Test("Invalid form не вызывает persistence")
    func invalidFormDoesNotPersist() throws {
        let workTypes = try makeWorkTypes()
        let shift = try makeShift(workTypeID: workTypes[0].id)
        var calls = 0
        let viewModel = makeViewModel(workTypes: workTypes, shift: shift) { _ in
            calls += 1
            return .success(())
        }
        viewModel.setEnd(start)

        #expect(viewModel.save() == .invalid)
        #expect(calls == 0)
    }

    @Test("Overlap и generic failure сохраняют форму и разрешают retry")
    func failuresPreserveFormAndAllowRetry() throws {
        let workTypes = try makeWorkTypes()
        let shift = try makeShift(workTypeID: workTypes[0].id)
        var outcomes: [Result<Void, EditShiftSaveFailure>] = [
            .failure(.overlap),
            .failure(.generic),
            .success(())
        ]
        let viewModel = makeViewModel(workTypes: workTypes, shift: shift) { _ in
            outcomes.removeFirst()
        }

        #expect(viewModel.save() == .failed(.overlap))
        #expect(viewModel.start == shift.start)
        #expect(viewModel.canSave)
        #expect(viewModel.save() == .failed(.generic))
        #expect(viewModel.canSave)
        #expect(viewModel.save() == .saved(shift))
    }

    @Test("Unknown initial WorkType не получает fallback")
    func unknownInitialWorkTypeRequiresExplicitSelection() throws {
        let workTypes = try makeWorkTypes()
        let unknownID = UUID(uuid: (0x83, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
        let shift = try makeShift(workTypeID: unknownID)
        let viewModel = makeViewModel(workTypes: workTypes, shift: shift)

        #expect(viewModel.selectedWorkTypeID == nil)
        #expect(viewModel.canSave == false)
        #expect(viewModel.selectWorkType(id: workTypes[1].id))
        #expect(viewModel.canSave)
    }

    private func makeViewModel(
        workTypes: [WorkType],
        shift: Shift,
        saveShift: @escaping (Shift) -> Result<Void, EditShiftSaveFailure> = { _ in .success(()) }
    ) -> EditShiftViewModel {
        EditShiftViewModel(
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: workTypes,
            shift: shift,
            saveShift: saveShift
        )
    }

    private func makeShift(workTypeID: UUID) throws -> Shift {
        try Shift(
            id: shiftID,
            workTypeID: workTypeID,
            start: start,
            end: end
        )
    }

    private func makeWorkTypes() throws -> [WorkType] {
        let lectures = WorkType(
            id: UUID(uuid: (0x84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ]
            )
        )

        let exams = WorkType(
            id: UUID(uuid: (0x84, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                        amount: 500,
                        effectiveFrom: nil
                    )
                ]
            )
        )

        return [lectures, exams]
    }
}
