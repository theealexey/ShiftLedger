import Foundation

struct ShiftFormWorkTypeOption: Equatable {
    let id: UUID
    let name: String?
}

enum ShiftFormValidationError: Error, Equatable {
    case missingWorkTypeAssignment
    case incomplete
    case invalidShift(ShiftValidationError)
}

struct ShiftFormState {
    private static let validationID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )

    private(set) var start: Date?
    private(set) var end: Date?
    private(set) var isUnpaidBreakEnabled: Bool
    private(set) var breakStart: Date?
    private(set) var breakEnd: Date?
    private(set) var selectedWorkTypeID: UUID?

    let workTypeOptions: [ShiftFormWorkTypeOption]

    init(
        workTypes: [WorkType],
        selectedWorkTypeID: UUID?,
        start: Date? = nil,
        end: Date? = nil,
        isUnpaidBreakEnabled: Bool = false,
        breakStart: Date? = nil,
        breakEnd: Date? = nil
    ) {
        workTypeOptions = workTypes.map {
            ShiftFormWorkTypeOption(id: $0.id, name: $0.name)
        }
        self.selectedWorkTypeID = workTypeOptions.contains(where: {
            $0.id == selectedWorkTypeID
        }) ? selectedWorkTypeID : nil
        self.start = start
        self.end = end
        self.isUnpaidBreakEnabled = isUnpaidBreakEnabled
        self.breakStart = breakStart
        self.breakEnd = breakEnd
    }

    var selectedWorkType: ShiftFormWorkTypeOption? {
        guard let selectedWorkTypeID else { return nil }
        return workTypeOptions.first { $0.id == selectedWorkTypeID }
    }

    var validationError: ShiftValidationError? {
        guard let start, let end, let selectedWorkTypeID else { return nil }

        let unpaidBreak: UnpaidBreak?
        if isUnpaidBreakEnabled {
            guard let breakStart, let breakEnd else { return nil }
            unpaidBreak = UnpaidBreak(start: breakStart, end: breakEnd)
        } else {
            unpaidBreak = nil
        }

        do {
            _ = try Shift(
                id: Self.validationID,
                workTypeID: selectedWorkTypeID,
                start: start,
                end: end,
                unpaidBreak: unpaidBreak
            )
            return nil
        } catch {
            return error
        }
    }

    var canBuildShift: Bool {
        selectedWorkTypeID != nil
            && start != nil
            && end != nil
            && (!isUnpaidBreakEnabled || (breakStart != nil && breakEnd != nil))
            && validationError == nil
    }

    mutating func setStart(_ value: Date?) {
        start = value
    }

    mutating func setEnd(_ value: Date?) {
        end = value
    }

    mutating func setUnpaidBreakEnabled(_ enabled: Bool) {
        isUnpaidBreakEnabled = enabled
    }

    mutating func setBreakStart(_ value: Date?) {
        breakStart = value
    }

    mutating func setBreakEnd(_ value: Date?) {
        breakEnd = value
    }

    mutating func selectWorkType(id: UUID) -> Bool {
        guard workTypeOptions.contains(where: { $0.id == id }) else {
            return false
        }
        selectedWorkTypeID = id
        return true
    }

    mutating func reset(selectedWorkTypeID: UUID?) {
        self.selectedWorkTypeID = workTypeOptions.contains(where: {
            $0.id == selectedWorkTypeID
        }) ? selectedWorkTypeID : nil
        start = nil
        end = nil
        isUnpaidBreakEnabled = false
        breakStart = nil
        breakEnd = nil
    }

    func makeShift(id: UUID) throws(ShiftFormValidationError) -> Shift {
        guard let selectedWorkTypeID else {
            throw .missingWorkTypeAssignment
        }
        guard let start, let end else {
            throw .incomplete
        }

        let unpaidBreak: UnpaidBreak?
        if isUnpaidBreakEnabled {
            guard let breakStart, let breakEnd else {
                throw .incomplete
            }
            unpaidBreak = UnpaidBreak(start: breakStart, end: breakEnd)
        } else {
            unpaidBreak = nil
        }

        do {
            return try Shift(
                id: id,
                workTypeID: selectedWorkTypeID,
                start: start,
                end: end,
                unpaidBreak: unpaidBreak
            )
        } catch {
            throw .invalidShift(error)
        }
    }
}
