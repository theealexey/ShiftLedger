import Foundation

enum LocalDateValidationError: Error, Equatable {
    case invalidGregorianDate
}

enum LocalDateConversionError: Error, Equatable {
    case missingGregorianDateComponents
    case dateDoesNotExistInTimeZone
}

struct LocalDate: Equatable, Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) throws {
        let calendar = Self.gregorianCalendar(in: .gmt)
        let requestedComponents = DateComponents(year: year, month: month, day: day)

        guard let date = calendar.date(from: requestedComponents) else {
            throw LocalDateValidationError.invalidGregorianDate
        }

        let resolvedComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            resolvedComponents.year == year,
            resolvedComponents.month == month,
            resolvedComponents.day == day
        else {
            throw LocalDateValidationError.invalidGregorianDate
        }

        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, in timeZone: TimeZone) throws {
        let calendar = Self.gregorianCalendar(in: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            throw LocalDateConversionError.missingGregorianDateComponents
        }

        try self.init(year: year, month: month, day: day)
    }

    func startOfDay(in timeZone: TimeZone) throws -> Date {
        let calendar = Self.gregorianCalendar(in: timeZone)
        let requestedComponents = DateComponents(year: year, month: month, day: day)

        guard let candidate = calendar.date(from: requestedComponents) else {
            throw LocalDateConversionError.dateDoesNotExistInTimeZone
        }

        let startOfDay = calendar.startOfDay(for: candidate)
        let resolvedComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        guard
            resolvedComponents.year == year,
            resolvedComponents.month == month,
            resolvedComponents.day == day
        else {
            throw LocalDateConversionError.dateDoesNotExistInTimeZone
        }

        return startOfDay
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }

        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }

        return lhs.day < rhs.day
    }

    private static func gregorianCalendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
