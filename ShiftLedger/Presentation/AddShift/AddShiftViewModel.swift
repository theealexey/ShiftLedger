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

@MainActor
final class AddShiftViewModel {
    private static let validationID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    private(set) var start: Date?
    private(set) var end: Date?
    private(set) var isUnpaidBreakEnabled = false
    private(set) var breakStart: Date?
    private(set) var breakEnd: Date?
    private(set) var isSaving = false

    let timeZoneIdentifier: String

    private let saveShift: (Shift) -> Result<Void, AddShiftSaveFailure>
    private let makeID: () -> UUID

    init(
        timeZoneIdentifier: String,
        initialStart: Date? = nil,
        initialEnd: Date? = nil,
        initialUnpaidBreakEnabled: Bool = false,
        initialBreakStart: Date? = nil,
        initialBreakEnd: Date? = nil,
        saveShift: @escaping (Shift) -> Result<Void, AddShiftSaveFailure>,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        start = initialStart
        end = initialEnd
        isUnpaidBreakEnabled = initialUnpaidBreakEnabled
        breakStart = initialBreakStart
        breakEnd = initialBreakEnd
        self.saveShift = saveShift
        self.makeID = makeID
    }

    var canSave: Bool {
        validationError == nil && start != nil && end != nil && (!isUnpaidBreakEnabled || (breakStart != nil && breakEnd != nil))
    }

    var validationError: ShiftValidationError? {
        guard let start, let end else { return nil }
        let unpaidBreak = isUnpaidBreakEnabled ? (breakStart.flatMap { breakStart in breakEnd.map { UnpaidBreak(start: breakStart, end: $0) } }) : nil
        guard isUnpaidBreakEnabled == false || unpaidBreak != nil else { return nil }

        do {
            _ = try Shift(id: Self.validationID, start: start, end: end, unpaidBreak: unpaidBreak)
            return nil
        } catch {
            return error
        }
    }

    func setStart(_ value: Date?) {
        start = value
    }

    func setEnd(_ value: Date?) {
        end = value
    }

    func setUnpaidBreakEnabled(_ enabled: Bool) {
        isUnpaidBreakEnabled = enabled
    }

    func setBreakStart(_ value: Date?) {
        breakStart = value
    }

    func setBreakEnd(_ value: Date?) {
        breakEnd = value
    }

    func makeShift(id: UUID) throws(AddShiftValidationError) -> Shift {
        guard let start, let end else {
            throw AddShiftValidationError.incomplete
        }

        let unpaidBreak: UnpaidBreak?
        if isUnpaidBreakEnabled {
            guard let breakStart, let breakEnd else {
                throw AddShiftValidationError.incomplete
            }
            unpaidBreak = UnpaidBreak(start: breakStart, end: breakEnd)
        } else {
            unpaidBreak = nil
        }

        do {
            return try Shift(id: id, start: start, end: end, unpaidBreak: unpaidBreak)
        } catch {
            throw .invalidShift(error)
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
    case incomplete
    case invalidShift(ShiftValidationError)
}
