import Foundation
import Testing
@testable import ShiftLedger

struct ShiftFormStateTests {
    private let start = Date(timeIntervalSinceReferenceDate: 100_000)
    private let end = Date(timeIntervalSinceReferenceDate: 128_800)
    private let shiftID = UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    @Test("Empty state неполон, exact selection и UUID сохраняются")
    func selectionAndIdentity() throws {
        let workTypes = try makeWorkTypes()
        var state = ShiftFormState(workTypes: workTypes, selectedWorkTypeID: nil)

        #expect(state.canBuildShift == false)

        let didSelectWorkType = state.selectWorkType(id: workTypes[1].id)
        #expect(didSelectWorkType)

        state.setStart(start)
        state.setEnd(end)

        let shift = try state.makeShift(id: shiftID)
        #expect(shift.id == shiftID)
        #expect(shift.workTypeID == workTypes[1].id)
        #expect(state.selectedWorkType?.id == workTypes[1].id)
    }

    @Test("Unknown WorkType не заменяет текущий выбор")
    func unknownSelectionIsRejected() throws {
        let workTypes = try makeWorkTypes()
        var state = ShiftFormState(
            workTypes: workTypes,
            selectedWorkTypeID: workTypes[1].id
        )
        let unknownID = UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))

        #expect(state.selectWorkType(id: unknownID) == false)
        #expect(state.selectedWorkTypeID == workTypes[1].id)
    }

    @Test("Domain date и break validation остаются общими")
    func domainValidationIsPreserved() throws {
        let workTypes = try makeWorkTypes()
        let workType = workTypes[0]
        var state = ShiftFormState(
            workTypes: [workType],
            selectedWorkTypeID: workType.id,
            start: start,
            end: start
        )
        #expect(state.validationError == .startNotBeforeEnd)

        state.setEnd(end)
        state.setUnpaidBreakEnabled(true)
        state.setBreakStart(start)
        state.setBreakEnd(end)
        #expect(state.validationError == .breakConsumesEntireShift)
        #expect(state.canBuildShift == false)
    }

    private func makeWorkTypes() throws -> [WorkType] {
        try [1, 2].map { value in
            WorkType(
                id: UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(value))),
                name: value == 1 ? "Lectures" : "Exams",
                basePayBasis: .hourly,
                payRateHistory: try PayRateHistory(payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(value))),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ])
            )
        }
    }
}
