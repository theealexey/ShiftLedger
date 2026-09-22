import Foundation

enum AddShiftSaveFailure: Error, Equatable {
    case overlap
    case generic
}

enum AddShiftSaveResult: Equatable {
    case saved(Shift)
    case failed(AddShiftSaveFailure)
    case invalid
    case ignored
}

typealias AddShiftWorkTypeOption = ShiftFormWorkTypeOption

@MainActor
final class AddShiftViewModel {
    private(set) var isSaving = false
    private var formState: ShiftFormState

    let timeZoneIdentifier: String

    private let saveShift: (Shift) -> Result<Void, AddShiftSaveFailure>
    private let makeID: () -> UUID

    init(
        timeZoneIdentifier: String,
        workTypes: [WorkType],
        initialStart: Date? = nil,
        initialEnd: Date? = nil,
        initialUnpaidBreakEnabled: Bool = false,
        initialBreakStart: Date? = nil,
        initialBreakEnd: Date? = nil,
        saveShift: @escaping (Shift) -> Result<Void, AddShiftSaveFailure>,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        formState = ShiftFormState(
            workTypes: workTypes,
            selectedWorkTypeID: workTypes.count == 1 ? workTypes[0].id : nil,
            start: initialStart,
            end: initialEnd,
            isUnpaidBreakEnabled: initialUnpaidBreakEnabled,
            breakStart: initialBreakStart,
            breakEnd: initialBreakEnd
        )
        self.saveShift = saveShift
        self.makeID = makeID
    }

    var start: Date? { formState.start }
    var end: Date? { formState.end }
    var isUnpaidBreakEnabled: Bool { formState.isUnpaidBreakEnabled }
    var breakStart: Date? { formState.breakStart }
    var breakEnd: Date? { formState.breakEnd }
    var selectedWorkTypeID: UUID? { formState.selectedWorkTypeID }
    var workTypeOptions: [AddShiftWorkTypeOption] { formState.workTypeOptions }
    var selectedWorkType: AddShiftWorkTypeOption? { formState.selectedWorkType }

    var canSave: Bool {
        formState.canBuildShift
    }

    var validationError: ShiftValidationError? {
        formState.validationError
    }

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

    func reset() {
        let selectedWorkTypeID = workTypeOptions.count == 1 ? workTypeOptions[0].id : nil
        formState.reset(selectedWorkTypeID: selectedWorkTypeID)
        isSaving = false
    }

    func makeShift(id: UUID) throws(AddShiftValidationError) -> Shift {
        do {
            return try formState.makeShift(id: id)
        } catch {
            switch error {
            case .missingWorkTypeAssignment:
                throw AddShiftValidationError.missingWorkTypeAssignment
            case .incomplete:
                throw AddShiftValidationError.incomplete
            case let .invalidShift(error):
                throw AddShiftValidationError.invalidShift(error)
            }
        }
    }

    func save() -> AddShiftSaveResult {
        guard isSaving == false else { return .ignored }
        guard canSave else { return .invalid }

        isSaving = true
        let shift: Shift
        do {
            shift = try makeShift(id: makeID())
        } catch {
            isSaving = false
            return .invalid
        }

        let result = saveShift(shift)
        isSaving = false

        switch result {
        case .success:
            return .saved(shift)
        case let .failure(failure):
            return .failed(failure)
        }
    }
}

enum AddShiftValidationError: Error, Equatable {
    case missingWorkTypeAssignment
    case incomplete
    case invalidShift(ShiftValidationError)
}
