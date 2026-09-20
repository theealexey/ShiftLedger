import Foundation

enum JobValidationError: Error, Equatable {
    case invalidCurrencyCode
    case invalidTimeZoneIdentifier
    case missingWorkTypes
    case duplicateWorkTypeID
    case missingPayRates
    case missingInitialPayRate
    case multipleInitialPayRates
    case duplicatePayRateEffectiveFrom
    case duplicatePayRateID
}

enum PayRateResolutionError: Error, Equatable {
    case workTypeNotFound(workTypeID: UUID)
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
    case missingInitialPayRate
}

enum ExpectedGrossCalculationError: Error, Equatable {
    case membershipFailed(ShiftMembershipError)
    case basePayFailed(PayRateResolutionError)
}

struct Job: Equatable {
    let id: UUID
    let currencyCode: String
    let timeZoneIdentifier: String
    let payCalculationCycle: PayCalculationCycle
    let createdAt: Date
    let workTypes: [WorkType]

    private struct ValidatedMetadata {
        let currencyCode: String
        let timeZoneIdentifier: String
    }

    var soleWorkType: WorkType? {
        guard workTypes.count == 1 else {
            return nil
        }
        return workTypes[0]
    }

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        basePayBasis: BasePayBasis,
        workTypeName: String? = nil,
        payCalculationCycle: PayCalculationCycle,
        payRates: [PayRate],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
        let metadata = try Self.validateMetadata(
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let payRateHistory = try Self.makePayRateHistory(from: payRates)
        let workType = WorkType(
            id: id,
            name: workTypeName,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory
        )

        try Self.validateWorkTypes([workType])
        self.init(
            id: id,
            metadata: metadata,
            payCalculationCycle: payCalculationCycle,
            workTypes: [workType],
            createdAt: createdAt
        )
    }

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        payCalculationCycle: PayCalculationCycle,
        workTypes: [WorkType],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let context = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: workTypes
        )
        try JobValidationChain().validate(context)

        self.init(
            id: id,
            metadata: ValidatedMetadata(
                currencyCode: normalizedCurrencyCode,
                timeZoneIdentifier: timeZoneIdentifier
            ),
            payCalculationCycle: payCalculationCycle,
            workTypes: workTypes,
            createdAt: createdAt
        )
    }

    private init(
        id: UUID,
        metadata: ValidatedMetadata,
        payCalculationCycle: PayCalculationCycle,
        workTypes: [WorkType],
        createdAt: Date
    ) {
        self.id = id
        self.currencyCode = metadata.currencyCode
        self.timeZoneIdentifier = metadata.timeZoneIdentifier
        self.payCalculationCycle = payCalculationCycle
        self.createdAt = createdAt
        self.workTypes = workTypes.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    func workType(id: UUID) -> WorkType? {
        workTypes.first { $0.id == id }
    }

    func applicablePayRate(for shift: Shift) throws(PayRateResolutionError) -> PayRate {
        let workType = try compensationWorkType(for: shift)
        let localStartDate = try localStartDate(for: shift)
        return workType.applicablePayRate(on: localStartDate)
    }

    func basePay(for shift: Shift) throws(PayRateResolutionError) -> Decimal {
        let workType = try compensationWorkType(for: shift)
        let localStartDate = try localStartDate(for: shift)
        return workType.basePay(for: shift, on: localStartDate)
    }

    func payCalculationPeriod(
        for shift: Shift
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod {
        switch payCalculationCycle {
        case .perShift:
            return .perShift(shiftID: shift.id)
        case let .scheduled(schedule):
            return .scheduled(try scheduledPayPeriod(containing: shift.start, schedule: schedule))
        }
    }

    func payCalculationPeriod(
        containing date: Date
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod? {
        switch payCalculationCycle {
        case .perShift:
            return nil
        case let .scheduled(schedule):
            return .scheduled(try scheduledPayPeriod(containing: date, schedule: schedule))
        }
    }

    func contains(
        _ shift: Shift,
        in period: PayCalculationPeriod
    ) throws(ShiftMembershipError) -> Bool {
        switch period {
        case let .perShift(shiftID):
            return shift.id == shiftID
        case let .scheduled(payPeriod):
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                throw ShiftMembershipError.invalidJobTimeZoneIdentifier
            }

            let localStartDate: LocalDate
            do {
                localStartDate = try LocalDate(date: shift.start, in: timeZone)
            } catch {
                throw ShiftMembershipError.localDateConversionFailed(error)
            }

            return localStartDate >= payPeriod.start
                && localStartDate < payPeriod.endExclusive
        }
    }

    func expectedGross(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> Decimal {
        try expectedGrossBreakdown(for: period, from: shifts).expectedGross
    }

    func expectedGrossBreakdown(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> ExpectedGrossBreakdown {
        let orderedShifts = shifts.sorted(by: Self.isShiftOrderedBefore)

        var breakdowns: [ShiftPayBreakdown] = []
        var total = Decimal.zero
        for shift in orderedShifts {
            let belongsToPeriod: Bool
            do {
                belongsToPeriod = try contains(shift, in: period)
            } catch {
                throw ExpectedGrossCalculationError.membershipFailed(error)
            }

            guard belongsToPeriod else {
                continue
            }

            do {
                let breakdown = try shiftPayBreakdown(for: shift)
                breakdowns.append(breakdown)
                total += breakdown.basePay
            } catch {
                throw ExpectedGrossCalculationError.basePayFailed(error)
            }
        }

        return ExpectedGrossBreakdown(
            period: period,
            shiftBreakdowns: breakdowns,
            expectedGross: total
        )
    }

    func paycheckComparison(
        for period: PayCalculationPeriod,
        actualGross: ActualGross,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> PaycheckComparison {
        let expected = try expectedGrossBreakdown(for: period, from: shifts)

        return PaycheckComparison(expected: expected, actualGross: actualGross)
    }

    private func shiftPayBreakdown(for shift: Shift) throws(PayRateResolutionError) -> ShiftPayBreakdown {
        let workType = try compensationWorkType(for: shift)
        let localStartDate = try localStartDate(for: shift)
        let payRate = workType.applicablePayRate(on: localStartDate)
        let amount = workType.basePay(for: shift, using: payRate)

        return ShiftPayBreakdown(
            shift: shift,
            basePayBasis: workType.basePayBasis,
            appliedPayRate: payRate,
            paidDuration: shift.paidDuration,
            basePay: amount
        )
    }

    private func compensationWorkType(for shift: Shift) throws(PayRateResolutionError) -> WorkType {
        guard let workType = workType(id: shift.workTypeID) else {
            throw PayRateResolutionError.workTypeNotFound(workTypeID: shift.workTypeID)
        }
        return workType
    }

    private static func validateMetadata(
        currencyCode: String,
        timeZoneIdentifier: String
    ) throws(JobValidationError) -> ValidatedMetadata {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let context = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: []
        )
        let timeZoneHandler = TimeZoneValidationHandler()
        try CurrencyValidationHandler(next: timeZoneHandler).validate(context)

        return ValidatedMetadata(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    private static func validateWorkTypes(
        _ workTypes: [WorkType]
    ) throws(JobValidationError) {
        try WorkTypesValidationHandler.validate(workTypes)
    }

    private static func makePayRateHistory(
        from payRates: [PayRate]
    ) throws(JobValidationError) -> PayRateHistory {
        do {
            return try PayRateHistory(payRates: payRates)
        } catch {
            switch error {
            case .missingPayRates:
                throw JobValidationError.missingPayRates
            case .missingInitialPayRate:
                throw JobValidationError.missingInitialPayRate
            case .multipleInitialPayRates:
                throw JobValidationError.multipleInitialPayRates
            case .duplicatePayRateEffectiveFrom:
                throw JobValidationError.duplicatePayRateEffectiveFrom
            case .duplicatePayRateID:
                throw JobValidationError.duplicatePayRateID
            }
        }
    }

    private func localStartDate(for shift: Shift) throws(PayRateResolutionError) -> LocalDate {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PayRateResolutionError.invalidJobTimeZoneIdentifier
        }

        do {
            return try LocalDate(date: shift.start, in: timeZone)
        } catch {
            throw PayRateResolutionError.localDateConversionFailed(error)
        }
    }

    private func scheduledPayPeriod(
        containing date: Date,
        schedule: PayPeriodSchedule
    ) throws(PayCalculationPeriodResolutionError) -> PayPeriod {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PayCalculationPeriodResolutionError.invalidJobTimeZoneIdentifier
        }

        let localDate: LocalDate
        do {
            localDate = try LocalDate(date: date, in: timeZone)
        } catch {
            throw PayCalculationPeriodResolutionError.localDateConversionFailed(error)
        }

        do {
            return try schedule.period(containing: localDate)
        } catch {
            throw PayCalculationPeriodResolutionError.scheduledPeriodResolutionFailed
        }
    }

    private static func isShiftOrderedBefore(_ lhs: Shift, _ rhs: Shift) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        if lhs.end != rhs.end {
            return lhs.end < rhs.end
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
