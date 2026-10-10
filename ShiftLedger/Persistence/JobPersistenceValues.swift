import Foundation

enum JobPersistenceValues {
    enum StoredPayPeriodKind: String {
        case weekly
        case biweekly
        case calendarMonthly
        case perShift
    }

    static func encodePayCalculationCycle(
        _ payCalculationCycle: PayCalculationCycle,
        timeZone: TimeZone
    ) throws -> (kind: StoredPayPeriodKind, anchorDate: Date?) {
        switch payCalculationCycle {
        case .perShift:
            return (.perShift, nil)
        case let .scheduled(schedule):
            switch schedule {
            case let .weekly(anchorDate):
                return (.weekly, try anchorDate.startOfDay(in: timeZone))
            case let .biweekly(anchorDate):
                return (.biweekly, try anchorDate.startOfDay(in: timeZone))
            case .calendarMonthly:
                return (.calendarMonthly, nil)
            }
        }
    }

    static func decodePayPeriodKind(_ rawValue: String) throws -> StoredPayPeriodKind {
        guard let kind = StoredPayPeriodKind(rawValue: rawValue) else {
            throw JobStorageError.corruptedData(.unknownPayPeriodKind(rawValue))
        }
        return kind
    }

    static func makePayCalculationCycle(
        kind storedKind: StoredPayPeriodKind,
        anchorDate: Date?,
        timeZone: TimeZone
    ) throws -> PayCalculationCycle {
        switch storedKind {
        case .perShift:
            guard anchorDate == nil else {
                throw JobStorageError.corruptedData(
                    .unexpectedPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .perShift
        case .weekly:
            guard let anchorDate = anchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(
                .weekly(
                    anchorDate: try makePayPeriodAnchorDate(
                        from: anchorDate,
                        kind: storedKind,
                        timeZone: timeZone
                    )
                )
            )
        case .biweekly:
            guard let anchorDate = anchorDate else {
                throw JobStorageError.corruptedData(
                    .missingPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(
                .biweekly(
                    anchorDate: try makePayPeriodAnchorDate(
                        from: anchorDate,
                        kind: storedKind,
                        timeZone: timeZone
                    )
                )
            )
        case .calendarMonthly:
            guard anchorDate == nil else {
                throw JobStorageError.corruptedData(
                    .unexpectedPayPeriodAnchorDate(payPeriodKind: storedKind.rawValue)
                )
            }
            return .scheduled(.calendarMonthly)
        }
    }

    static func makeTimeZone(from identifier: String) throws -> TimeZone {
        guard
            TimeZone.knownTimeZoneIdentifiers.contains(identifier),
            let timeZone = TimeZone(identifier: identifier)
        else {
            throw JobStorageError.corruptedData(.invalidTimeZoneIdentifier(identifier))
        }

        return timeZone
    }

    private static func makePayPeriodAnchorDate(
        from storedDate: Date,
        kind: StoredPayPeriodKind,
        timeZone: TimeZone
    ) throws -> LocalDate {
        let anchorDate: LocalDate

        do {
            anchorDate = try LocalDate(date: storedDate, in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(
                .invalidPayPeriodAnchorDate(payPeriodKind: kind.rawValue, underlying: error)
            )
        }

        let canonicalDate: Date
        do {
            canonicalDate = try anchorDate.startOfDay(in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(
                .invalidPayPeriodAnchorDate(payPeriodKind: kind.rawValue, underlying: error)
            )
        }

        guard canonicalDate == storedDate else {
            throw JobStorageError.corruptedData(
                .nonCanonicalPayPeriodAnchorDate(payPeriodKind: kind.rawValue)
            )
        }

        return anchorDate
    }
}
