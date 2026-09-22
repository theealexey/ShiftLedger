import Foundation

enum EditShiftSaveFailure: Error, Equatable {
    case overlap
    case generic
}

enum EditShiftSaveResult: Equatable {
    case saved(Shift)
    case failed(EditShiftSaveFailure)
    case invalid
    case ignored
}

@MainActor
final class EditShiftViewModel {
    private let shiftID: UUID
    private let saveShift: (Shift) -> Result<Void, EditShiftSaveFailure>
    private var formState: ShiftFormState

    private(set) var isSaving = false
    let timeZoneIdentifier: String

    init(
        timeZoneIdentifier: String,
        workTypes: [WorkType],
        shift: Shift,
        saveShift: @escaping (Shift) -> Result<Void, EditShiftSaveFailure>
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        shiftID = shift.id
        formState = ShiftFormState(
            workTypes: workTypes,
            selectedWorkTypeID: shift.workTypeID,
            start: shift.start,
            end: shift.end,
            isUnpaidBreakEnabled: shift.unpaidBreak != nil,
            breakStart: shift.unpaidBreak?.start,
            breakEnd: shift.unpaidBreak?.end
        )
        self.saveShift = saveShift
    }

    var start: Date? { formState.start }
    var end: Date? { formState.end }
    var isUnpaidBreakEnabled: Bool { formState.isUnpaidBreakEnabled }
    var breakStart: Date? { formState.breakStart }
    var breakEnd: Date? { formState.breakEnd }
    var selectedWorkTypeID: UUID? { formState.selectedWorkTypeID }
    var workTypeOptions: [ShiftFormWorkTypeOption] { formState.workTypeOptions }
    var selectedWorkType: ShiftFormWorkTypeOption? { formState.selectedWorkType }
    var validationError: ShiftValidationError? { formState.validationError }
    var canSave: Bool { formState.canBuildShift && isSaving == false }

    func setStart(_ value: Date?) {
        formState.setStart(value)
    }

    func setEnd(_ value: Date?) {
        formState.setEnd(value)
    }

    func setUnpaidBreakEnabled(_ enabled: Bool) {
        formState.setUnpaidBreakEnabled(enabled)
    }

    func setBreakStart(_ value: Date?) {
        formState.setBreakStart(value)
    }

    func setBreakEnd(_ value: Date?) {
        formState.setBreakEnd(value)
    }

    func selectWorkType(id: UUID) -> Bool {
        formState.selectWorkType(id: id)
    }

    func makeShift() throws(ShiftFormValidationError) -> Shift {
        try formState.makeShift(id: shiftID)
    }

    func save() -> EditShiftSaveResult {
        guard isSaving == false else { return .ignored }
        guard canSave else { return .invalid }

        let shift: Shift
        do {
            shift = try makeShift()
        } catch {
            return .invalid
        }

        isSaving = true
        switch saveShift(shift) {
        case .success:
            return .saved(shift)
        case let .failure(failure):
            isSaving = false
            return .failed(failure)
        }
    }
}
