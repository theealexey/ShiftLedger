//
//  ShiftLedgerTests.swift
//  ShiftLedgerTests
//
//  Created by Alexey Westergaard on 26.08.2026.
//

import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftLedgerTests {
    private let createdAt = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("Поддерживаются все виды расчётных периодов")
    func supportsPayPeriodSchedules() throws {
        let expectedAnchorDate = try makeLocalDate()
        let weekly = PayPeriodSchedule.weekly(anchorDate: expectedAnchorDate)
        let biweekly = PayPeriodSchedule.biweekly(anchorDate: expectedAnchorDate)
        let calendarMonthly = PayPeriodSchedule.calendarMonthly

        if case let .weekly(anchorDate) = weekly {
            #expect(anchorDate == expectedAnchorDate)
        } else {
            Issue.record("Не создан недельный период")
        }

        if case let .biweekly(anchorDate) = biweekly {
            #expect(anchorDate == expectedAnchorDate)
        } else {
            Issue.record("Не создан двухнедельный период")
        }

        guard case .calendarMonthly = calendarMonthly else {
            Issue.record("Не создан календарный месяц")
            return
        }
    }

    @Test("Недельный период включает anchor и последний день")
    func weeklyPeriodIncludesAnchorAndLastDay() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.weekly(anchorDate: anchor)
        let expectedPeriod = PayPeriod(
            start: try makeLocalDate(year: 2026, month: 8, day: 3),
            endExclusive: try makeLocalDate(year: 2026, month: 8, day: 10)
        )

        #expect(try schedule.period(containing: anchor) == expectedPeriod)
        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 8, day: 9)) == expectedPeriod)
    }

    @Test("Недельный период меняется на endExclusive")
    func weeklyPeriodAdvancesAtEndExclusive() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.weekly(anchorDate: anchor)
        let previousPeriod = try schedule.period(containing: anchor)
        let followingPeriod = try schedule.period(containing: previousPeriod.endExclusive)

        #expect(followingPeriod == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 8, day: 10),
            endExclusive: try makeLocalDate(year: 2026, month: 8, day: 17)
        ))
    }

    @Test("Недельный период корректно считается до anchor")
    func weeklyPeriodBeforeAnchorUsesFloorDivision() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.weekly(anchorDate: anchor)

        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 8, day: 2)) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 7, day: 27),
            endExclusive: anchor
        ))
        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 6, day: 1)) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 6, day: 1),
            endExclusive: try makeLocalDate(year: 2026, month: 6, day: 8)
        ))
    }

    @Test("Недельный период корректно считается после anchor")
    func weeklyPeriodAfterAnchor() throws {
        let schedule = PayPeriodSchedule.weekly(anchorDate: try makeLocalDate(year: 2026, month: 8, day: 3))

        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 9, day: 1)) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 8, day: 31),
            endExclusive: try makeLocalDate(year: 2026, month: 9, day: 7)
        ))
    }

    @Test("Двухнедельный период включает anchor и последний день")
    func biweeklyPeriodIncludesAnchorAndLastDay() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)
        let expectedPeriod = PayPeriod(
            start: anchor,
            endExclusive: try makeLocalDate(year: 2026, month: 8, day: 17)
        )

        #expect(try schedule.period(containing: anchor) == expectedPeriod)
        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 8, day: 16)) == expectedPeriod)
    }

    @Test("Двухнедельный период меняется на endExclusive")
    func biweeklyPeriodAdvancesAtEndExclusive() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)
        let previousPeriod = try schedule.period(containing: anchor)
        let followingPeriod = try schedule.period(containing: previousPeriod.endExclusive)

        #expect(followingPeriod == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 8, day: 17),
            endExclusive: try makeLocalDate(year: 2026, month: 8, day: 31)
        ))
    }

    @Test("Двухнедельный период корректно считается до anchor")
    func biweeklyPeriodBeforeAnchor() throws {
        let anchor = try makeLocalDate(year: 2026, month: 8, day: 3)
        let schedule = PayPeriodSchedule.biweekly(anchorDate: anchor)

        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 8, day: 2)) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 7, day: 20),
            endExclusive: anchor
        ))
    }

    @Test("Календарный месячный период соответствует обычному месяцу")
    func calendarMonthlyPeriodMatchesMonth() throws {
        let schedule = PayPeriodSchedule.calendarMonthly
        let period = try schedule.period(containing: try makeLocalDate(year: 2026, month: 8, day: 29))

        #expect(period == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try makeLocalDate(year: 2026, month: 9, day: 1)
        ))
        #expect(try schedule.period(containing: period.endExclusive) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try makeLocalDate(year: 2026, month: 10, day: 1)
        ))
    }

    @Test("Календарный месячный период учитывает високосный февраль")
    func calendarMonthlyPeriodHandlesLeapYearFebruary() throws {
        let schedule = PayPeriodSchedule.calendarMonthly

        #expect(try schedule.period(containing: try makeLocalDate(year: 2024, month: 2, day: 29)) == PayPeriod(
            start: try makeLocalDate(year: 2024, month: 2, day: 1),
            endExclusive: try makeLocalDate(year: 2024, month: 3, day: 1)
        ))
    }

    @Test("Календарный месячный период переходит из декабря в январь")
    func calendarMonthlyPeriodCrossesYearBoundary() throws {
        let schedule = PayPeriodSchedule.calendarMonthly

        #expect(try schedule.period(containing: try makeLocalDate(year: 2026, month: 12, day: 31)) == PayPeriod(
            start: try makeLocalDate(year: 2026, month: 12, day: 1),
            endExclusive: try makeLocalDate(year: 2027, month: 1, day: 1)
        ))
    }

    @Test("Корректная календарная дата принимается")
    func acceptsValidLocalDate() throws {
        let date = try LocalDate(year: 2026, month: 9, day: 1)

        #expect(date.year == 2026)
        #expect(date.month == 9)
        #expect(date.day == 1)
    }

    @Test("Високосный день принимается")
    func acceptsLeapDay() throws {
        let date = try LocalDate(year: 2024, month: 2, day: 29)

        #expect(date.year == 2024)
        #expect(date.month == 2)
        #expect(date.day == 29)
    }

    @Test("Некорректный високосный день отклоняется")
    func rejectsInvalidLeapDay() {
        #expect(throws: LocalDateValidationError.invalidGregorianDate) {
            try LocalDate(year: 2025, month: 2, day: 29)
        }
    }

    @Test("Некорректный день и месяц отклоняются")
    func rejectsInvalidDayAndMonth() {
        #expect(throws: LocalDateValidationError.invalidGregorianDate) {
            try LocalDate(year: 2026, month: 2, day: 31)
        }

        #expect(throws: LocalDateValidationError.invalidGregorianDate) {
            try LocalDate(year: 2026, month: 13, day: 1)
        }
    }

    @Test("Календарные даты сравниваются хронологически")
    func comparesLocalDatesChronologically() throws {
        let endOfMonth = try LocalDate(year: 2026, month: 1, day: 31)
        let startOfNextMonth = try LocalDate(year: 2026, month: 2, day: 1)
        let endOfYear = try LocalDate(year: 2026, month: 12, day: 31)
        let startOfNextYear = try LocalDate(year: 2027, month: 1, day: 1)

        #expect(endOfMonth < startOfNextMonth)
        #expect(endOfYear < startOfNextYear)
    }

    @Test("Календарная дата восстанавливается в Europe/Stockholm")
    func roundTripsLocalDateInStockholm() throws {
        guard let timeZone = TimeZone(identifier: "Europe/Stockholm") else {
            Issue.record("Не найдена зона времени Europe/Stockholm")
            return
        }

        let localDate = try makeLocalDate()
        let date = try localDate.startOfDay(in: timeZone)
        let restoredLocalDate = try LocalDate(date: date, in: timeZone)

        #expect(restoredLocalDate == localDate)
    }

    @Test("Переход на летнее время не предполагает сутки из 24 часов")
    func handlesDaylightSavingTimeInStockholm() throws {
        guard let timeZone = TimeZone(identifier: "Europe/Stockholm") else {
            Issue.record("Не найдена зона времени Europe/Stockholm")
            return
        }

        let daylightSavingDate = try LocalDate(year: 2026, month: 3, day: 29)
        let followingDate = try LocalDate(year: 2026, month: 3, day: 30)
        let daylightSavingStart = try daylightSavingDate.startOfDay(in: timeZone)
        let followingStart = try followingDate.startOfDay(in: timeZone)
        let restoredDaylightSavingDate = try LocalDate(date: daylightSavingStart, in: timeZone)
        let restoredFollowingDate = try LocalDate(date: followingStart, in: timeZone)

        #expect(followingStart.timeIntervalSince(daylightSavingStart) == 23 * 60 * 60)
        #expect(restoredDaylightSavingDate == daylightSavingDate)
        #expect(restoredFollowingDate == followingDate)
    }

    @Test("Работа принимает ровно одну initial ставку без даты")
    func acceptsExactlyOneInitialPayRate() throws {
        let initialRate = try PayRate(amount: 120, effectiveFrom: nil)
        let datedRate = try PayRate(
            amount: 130,
            effectiveFrom: try makeLocalDate(year: 2026, month: 10, day: 1)
        )

        let job = try makeJob(payRates: [datedRate, initialRate])

        #expect(job.payRates == [initialRate, datedRate])
    }

    @Test("Работа без initial ставки отклоняется")
    func rejectsMissingInitialPayRate() throws {
        let datedRate = try makePayRate(effectiveFrom: try makeLocalDate())

        #expect(throws: JobValidationError.missingInitialPayRate) {
            try makeJob(payRates: [datedRate])
        }
    }

    @Test("Две initial ставки отклоняются")
    func rejectsMultipleInitialPayRates() throws {
        let firstInitialRate = try PayRate(amount: 120, effectiveFrom: nil)
        let secondInitialRate = try PayRate(amount: 130, effectiveFrom: nil)

        #expect(throws: JobValidationError.multipleInitialPayRates) {
            try makeJob(payRates: [firstInitialRate, secondInitialRate])
        }
    }

    @Test("Неизвестная зона времени отклоняется")
    func rejectsUnknownTimeZone() throws {
        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try makeJob(timeZoneIdentifier: "Europe/Unknown", payRates: [try makePayRate()])
        }
    }

    @Test("Смещение GMT не принимается как идентификатор зоны времени")
    func rejectsGMTOffsetAsTimeZoneIdentifier() throws {
        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try makeJob(timeZoneIdentifier: "GMT+2", payRates: [try makePayRate()])
        }
    }

    @Test("Существующая зона времени принимается")
    func acceptsKnownTimeZone() throws {
        let job = try makeJob(timeZoneIdentifier: "Europe/Stockholm", payRates: [try makePayRate()])

        #expect(job.timeZoneIdentifier == "Europe/Stockholm")
    }

    @Test("Некорректный код валюты отклоняется")
    func rejectsInvalidCurrencyCode() throws {
        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try makeJob(currencyCode: "EURO", payRates: [try makePayRate()])
        }
    }

    @Test("Работа без ставок отклоняется")
    func rejectsJobWithoutPayRates() {
        #expect(throws: JobValidationError.missingPayRates) {
            try makeJob(payRates: [])
        }
    }

    @Test("Ставки с разными датами начала действия принимаются")
    func acceptsPayRatesWithDifferentEffectiveFrom() throws {
        let firstPayRate = try makePayRate()
        let secondPayRate = try PayRate(
            amount: 130,
            effectiveFrom: try makeLocalDate(year: 2026, month: 9, day: 2)
        )

        let job = try makeJob(payRates: [firstPayRate, secondPayRate])

        #expect(job.payRates == [firstPayRate, secondPayRate])
    }

    @Test("Две ставки с одинаковой датой начала действия отклоняются")
    func rejectsDuplicatePayRateEffectiveFrom() throws {
        let effectiveFrom = try makeLocalDate()
        let initialPayRate = try makePayRate()
        let firstPayRate = try PayRate(amount: 120, effectiveFrom: effectiveFrom)
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: effectiveFrom)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try makeJob(payRates: [initialPayRate, firstPayRate, secondPayRate])
        }
    }

    @Test("Порядок ставок не влияет на обнаружение повторяющейся даты")
    func rejectsDuplicatePayRateEffectiveFromInAnyOrder() throws {
        let effectiveFrom = try makeLocalDate()
        let initialPayRate = try makePayRate()
        let firstPayRate = try PayRate(amount: 120, effectiveFrom: effectiveFrom)
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: effectiveFrom)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try makeJob(payRates: [initialPayRate, secondPayRate, firstPayRate])
        }
    }

    @Test("Сортировка ставок помещает initial первой")
    func sortsInitialPayRateFirst() throws {
        let laterRate = try PayRate(
            amount: 140,
            effectiveFrom: try makeLocalDate(year: 2026, month: 10, day: 1)
        )
        let initialRate = try PayRate(amount: 120, effectiveFrom: nil)
        let earlierRate = try PayRate(
            amount: 130,
            effectiveFrom: try makeLocalDate(year: 2026, month: 9, day: 1)
        )

        let job = try makeJob(payRates: [laterRate, initialRate, earlierRate])

        #expect(job.payRates == [initialRate, earlierRate, laterRate])
    }

    @Test("Положительная ставка принимается")
    func acceptsPositivePayRate() throws {
        let payRate = try makePayRate(amount: 17)

        #expect(payRate.amount == 17)
    }

    @Test("Дробная ставка принимается без округления")
    func acceptsFractionalPayRateWithoutRounding() throws {
        let amount = try #require(
            Decimal(string: "17.125", locale: Locale(identifier: "en_US_POSIX"))
        )

        let payRate = try makePayRate(amount: amount)

        #expect(payRate.amount == amount)
    }

    @Test("Отрицательная ставка отклоняется")
    func rejectsNegativePayRate() {
        #expect(throws: PayRateValidationError.nonPositiveAmount) {
            try makePayRate(amount: -1)
        }
    }

    @Test("Нулевая ставка отклоняется")
    func rejectsZeroPayRate() {
        #expect(throws: PayRateValidationError.nonPositiveAmount) {
            try makePayRate(amount: .zero)
        }
    }

    private func makeJob(
        currencyCode: String = "EUR",
        timeZoneIdentifier: String = "Europe/Stockholm",
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            basePayBasis: .hourly,
            payCalculationCycle: .scheduled(.weekly(anchorDate: try makeLocalDate())),
            payRates: payRates,
            createdAt: createdAt
        )
    }

    private func makePayRate(
        amount: Decimal = 120,
        effectiveFrom: LocalDate? = nil
    ) throws -> PayRate {
        return try PayRate(amount: amount, effectiveFrom: effectiveFrom)
    }

    private func makeLocalDate(
        year: Int = 2026,
        month: Int = 9,
        day: Int = 1
    ) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }
}
