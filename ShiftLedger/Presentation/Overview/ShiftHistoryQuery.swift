import Foundation

struct ShiftHistoryQuery: Equatable {
    enum Dates: Equatable {
        case all
        case thisMonth
        case custom(LocalDate, LocalDate)
    }

    enum Sort: CaseIterable, Equatable {
        case newest, oldest, highest, lowest
    }

    enum ValidationError: Error {
        case dates, amount, amountRange
    }

    struct WorkTypeOption: Equatable {
        let id: UUID
        let name: String
        let isArchived: Bool
    }

    var dates: Dates = .all
    var workTypeIDs: Set<UUID> = []
    var minimum: Decimal?
    var maximum: Decimal?
    var sort: Sort = .newest

    var activeGroups: Int {
        (dates == .all ? 0 : 1) + (workTypeIDs.isEmpty ? 0 : 1) + (minimum == nil && maximum == nil ? 0 : 1)
    }

    func dateBounds(now: Date, timeZone: TimeZone) throws -> Range<Date>? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch dates {
        case .all:
            return nil
        case .thisMonth:
            guard let month = calendar.dateInterval(of: .month, for: now) else { throw ValidationError.dates }
            return month.start..<month.end
        case let .custom(first, last):
            guard first <= last,
                  let start = try? first.startOfDay(in: timeZone),
                  let lastDay = try? last.startOfDay(in: timeZone),
                  let day = calendar.dateInterval(of: .day, for: lastDay),
                  start < day.end else { throw ValidationError.dates }
            return start..<day.end
        }
    }

    func results(_ history: [ShiftPayBreakdown], now: Date, timeZone: TimeZone) throws -> [ShiftPayBreakdown] {
        for bound in [minimum, maximum].compactMap({ $0 }) where bound.isNaN || bound < 0 {
            throw ValidationError.amount
        }
        if let minimum, let maximum, minimum > maximum { throw ValidationError.amountRange }
        let bounds = try dateBounds(now: now, timeZone: timeZone)
        return history.filter { row in
            (bounds?.contains(row.shift.start) ?? true)
                && (workTypeIDs.isEmpty || workTypeIDs.contains(row.shift.workTypeID))
                && (minimum.map { row.basePay >= $0 } ?? true)
                && (maximum.map { row.basePay <= $0 } ?? true)
        }.sorted { lhs, rhs in
            if lhs.basePay != rhs.basePay {
                if sort == .highest { return lhs.basePay > rhs.basePay }
                if sort == .lowest { return lhs.basePay < rhs.basePay }
            }
            return sort == .oldest
                ? Self.earlier(lhs.shift, rhs.shift)
                : Self.earlier(rhs.shift, lhs.shift)
        }
    }

    static func workTypeOptions(
        for job: Job, history: [ShiftPayBreakdown], selected: Set<UUID>, locale: Locale
    ) -> [WorkTypeOption] {
        let referenced = Set(history.map { $0.shift.workTypeID })
        return job.workTypes.filter { !$0.isArchived || referenced.contains($0.id) || selected.contains($0.id) }
            .map { WorkTypeOption(id: $0.id, name: $0.name ?? AddShiftStrings.unnamedWorkType, isArchived: $0.isArchived) }
            .sorted {
                let order = $0.name.compare($1.name, options: [.caseInsensitive, .numeric], locale: locale)
                return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
            }
    }

    private static func earlier(_ lhs: Shift, _ rhs: Shift) -> Bool {
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        if lhs.end != rhs.end { return lhs.end < rhs.end }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func amount(_ input: String, locale: Locale) throws -> Decimal? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let parts = text.components(separatedBy: locale.decimalSeparator ?? ".")
        guard parts.count <= 2 else { throw ValidationError.amount }
        let digits = try parts.map { part in
            guard !part.isEmpty else { throw ValidationError.amount }
            return try part.map { character in
                guard character.unicodeScalars.count == 1,
                      character.unicodeScalars.first?.properties.numericType == .decimal,
                      let digit = character.wholeNumberValue else { throw ValidationError.amount }
                return String(digit)
            }.joined()
        }
        let integer = String(digits[0].drop(while: { $0 == "0" }))
        let fraction = digits.count == 2 ? String(digits[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
        let canonical = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
        let invariant = Locale(identifier: "en_US_POSIX")
        guard var value = Decimal(string: canonical, locale: invariant),
              !value.isNaN, NSDecimalString(&value, invariant) == canonical else { throw ValidationError.amount }
        return value
    }
}
