import Foundation

struct UnpaidBreak: Equatable {
    let start: Date
    let end: Date
}

enum ShiftValidationError: Error, Equatable {
    case startNotBeforeEnd
    case durationExceedsLimit
    case breakStartNotBeforeEnd
    case breakOutsideShift
    case breakConsumesEntireShift
}

struct Shift: Equatable, Identifiable {
    static let maximumDuration: TimeInterval = 48 * 60 * 60

    let id: UUID
    let start: Date
    let end: Date
    let unpaidBreak: UnpaidBreak?

    init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        unpaidBreak: UnpaidBreak? = nil
    ) throws {
        guard start < end else {
            throw ShiftValidationError.startNotBeforeEnd
        }

        let duration = end.timeIntervalSince(start)
        guard duration <= Self.maximumDuration else {
            throw ShiftValidationError.durationExceedsLimit
        }

        if let unpaidBreak {
            guard unpaidBreak.start < unpaidBreak.end else {
                throw ShiftValidationError.breakStartNotBeforeEnd
            }

            guard unpaidBreak.start >= start, unpaidBreak.end <= end else {
                throw ShiftValidationError.breakOutsideShift
            }

            guard unpaidBreak.end.timeIntervalSince(unpaidBreak.start) < duration else {
                throw ShiftValidationError.breakConsumesEntireShift
            }
        }

        self.id = id
        self.start = start
        self.end = end
        self.unpaidBreak = unpaidBreak
    }

    func overlaps(with other: Shift) -> Bool {
        start < other.end && other.start < end
    }
}
