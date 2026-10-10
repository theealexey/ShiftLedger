import Foundation

enum JobPersistenceValues {
    struct StoredPayRate {
        let payRate: PayRate
        let effectiveFrom: Date?
    }

    struct StoredWorkType {
        let workType: WorkType
        let basePayKind: StoredBasePayKind
        let payRates: [StoredPayRate]
    }

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

    static func prepareStoredWorkTypes(
        _ workTypes: [WorkType],
        timeZone: TimeZone
    ) throws -> [StoredWorkType] {
        try workTypes.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            try prepareStoredWorkType($0, timeZone: timeZone)
        }
    }

    static func prepareStoredWorkType(
        _ workType: WorkType,
        timeZone: TimeZone
    ) throws -> StoredWorkType {
        let payRates = try workType.payRates.map { payRate in
            try prepareStoredPayRate(payRate, timeZone: timeZone)
        }

        return StoredWorkType(
            workType: workType,
            basePayKind: encodeBasePayBasis(workType.basePayBasis),
            payRates: payRates
        )
    }

    static func prepareStoredPayRate(
        _ payRate: PayRate,
        timeZone: TimeZone
    ) throws -> StoredPayRate {
        StoredPayRate(
            payRate: payRate,
            effectiveFrom: try payRate.effectiveFrom.map {
                try $0.startOfDay(in: timeZone)
            }
        )
    }

    private static func encodeBasePayBasis(_ basis: BasePayBasis) -> StoredBasePayKind {
        switch basis {
        case .hourly:
            .hourly
        case .fixedPerShift:
            .fixedPerShift
        }
    }

    static func makeBasePayBasis(from rawValue: String) throws -> BasePayBasis {
        guard let storedKind = StoredBasePayKind(rawValue: rawValue) else {
            throw JobStorageError.corruptedData(
                .unknownBasePayKind(rawValue)
            )
        }

        switch storedKind {
        case .hourly:
            return .hourly
        case .fixedPerShift:
            return .fixedPerShift
        }
    }

    static func makePayRateEffectiveFrom(
        from storedEffectiveFrom: Date,
        timeZone: TimeZone
    ) throws -> LocalDate {
        let effectiveFrom: LocalDate

        do {
            effectiveFrom = try LocalDate(date: storedEffectiveFrom, in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRateEffectiveFrom(underlying: error))
        }

        let canonicalDate: Date
        do {
            canonicalDate = try effectiveFrom.startOfDay(in: timeZone)
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRateEffectiveFrom(underlying: error))
        }

        guard canonicalDate == storedEffectiveFrom else {
            throw JobStorageError.corruptedData(.nonCanonicalPayRateEffectiveFrom)
        }

        return effectiveFrom
    }

    static func makePayRate(
        id: UUID,
        amount: Decimal,
        effectiveFrom: LocalDate?
    ) throws -> PayRate {
        do {
            return try PayRate(
                id: id,
                amount: amount,
                effectiveFrom: effectiveFrom
            )
        } catch {
            throw JobStorageError.corruptedData(.invalidPayRate(underlying: error))
        }
    }
}
