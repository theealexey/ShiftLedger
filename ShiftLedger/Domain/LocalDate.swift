import Foundation

enum LocalDateValidationError: Error, Equatable {
    case invalidGregorianDate
}

enum LocalDateConversionError: Error, Equatable {
    case missingGregorianDateComponents
    case invalidGregorianDateComponents
    case dateDoesNotExistInTimeZone
    case calendarArithmeticFailed
}

struct LocalDate: Equatable, Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) throws(LocalDateValidationError) {
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

    init(date: Date, in timeZone: TimeZone) throws(LocalDateConversionError) {
        let calendar = Self.gregorianCalendar(in: timeZone)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            throw LocalDateConversionError.missingGregorianDateComponents
        }

        do {
            try self.init(year: year, month: month, day: day)
        } catch {
            throw LocalDateConversionError.invalidGregorianDateComponents
        }
    }

    func startOfDay(in timeZone: TimeZone) throws(LocalDateConversionError) -> Date {
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

    func addingDays(_ days: Int) throws -> LocalDate {
        let calendar = Self.gregorianCalendar(in: .gmt)
        let date = try startOfDay(in: .gmt)

        guard let shiftedDate = calendar.date(byAdding: .day, value: days, to: date) else {
            throw LocalDateConversionError.calendarArithmeticFailed
        }

        return try LocalDate(date: shiftedDate, in: .gmt)
    }

    func daysUntil(_ other: LocalDate) throws -> Int {
        let calendar = Self.gregorianCalendar(in: .gmt)
        let startDate = try startOfDay(in: .gmt)
        let endDate = try other.startOfDay(in: .gmt)

        guard let days = calendar.dateComponents([.day], from: startDate, to: endDate).day else {
            throw LocalDateConversionError.calendarArithmeticFailed
        }

        return days
    }

    func firstDayOfNextMonth() throws -> LocalDate {
        let calendar = Self.gregorianCalendar(in: .gmt)
        let firstDayOfMonth = try LocalDate(year: year, month: month, day: 1)
        let date = try firstDayOfMonth.startOfDay(in: .gmt)

        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: date) else {
            throw LocalDateConversionError.calendarArithmeticFailed
        }

        return try LocalDate(date: nextMonthDate, in: .gmt)
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
