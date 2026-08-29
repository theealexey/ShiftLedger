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

    @Test("Пустое название работы отклоняется")
    func rejectsEmptyJobName() throws {
        #expect(throws: JobValidationError.emptyName) {
            try makeJob(name: "", payRates: [try makePayRate()])
        }
    }

    @Test("Название только из пробелов отклоняется")
    func rejectsWhitespaceOnlyJobName() throws {
        #expect(throws: JobValidationError.emptyName) {
            try makeJob(name: " \n\t ", payRates: [try makePayRate()])
        }
    }

    @Test("Внешние пробелы в названии удаляются")
    func normalizesJobName() throws {
        let job = try makeJob(name: " \n Основная работа \t", payRates: [try makePayRate()])

        #expect(job.name == "Основная работа")
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
        let firstPayRate = try PayRate(amount: 120, effectiveFrom: effectiveFrom)
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: effectiveFrom)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try makeJob(payRates: [firstPayRate, secondPayRate])
        }
    }

    @Test("Порядок ставок не влияет на обнаружение повторяющейся даты")
    func rejectsDuplicatePayRateEffectiveFromInAnyOrder() throws {
        let effectiveFrom = try makeLocalDate()
        let firstPayRate = try PayRate(amount: 120, effectiveFrom: effectiveFrom)
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: effectiveFrom)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try makeJob(payRates: [secondPayRate, firstPayRate])
        }
    }

    @Test("Отрицательная ставка отклоняется")
    func rejectsNegativePayRate() {
        #expect(throws: PayRateValidationError.negativeAmount) {
            try makePayRate(amount: -1)
        }
    }

    private func makeJob(
        name: String = "Основная работа",
        currencyCode: String = "EUR",
        timeZoneIdentifier: String = "Europe/Stockholm",
        payRates: [PayRate]
    ) throws -> Job {
        try Job(
            name: name,
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            payPeriodSchedule: .weekly(anchorDate: try makeLocalDate()),
            payRates: payRates,
            createdAt: createdAt
        )
    }

    private func makePayRate(amount: Decimal = 120) throws -> PayRate {
        let effectiveFrom = try makeLocalDate()
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
