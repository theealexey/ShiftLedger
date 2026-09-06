import Foundation

enum OverviewFormatting {
    static func currency(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }

    static func scheduledPeriod(
        _ period: PayPeriod,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let visibleEnd = try? period.endExclusive.addingDays(-1),
            let startDate = try? period.start.startOfDay(in: timeZone),
            let endDate = try? visibleEnd.startOfDay(in: timeZone)
        else {
            return nil
        }

        let formatter = DateIntervalFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }

    static func perShiftPeriod(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateIntervalFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: shift.start, to: shift.end)
    }

    private static func configuredCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
