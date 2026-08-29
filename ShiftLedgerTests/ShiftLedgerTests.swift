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
    private let date = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("Поддерживаются все виды расчётных периодов")
    func supportsPayPeriodSchedules() {
        let weekly = PayPeriodSchedule.weekly(anchorDate: date)
        let biweekly = PayPeriodSchedule.biweekly(anchorDate: date)
        let calendarMonthly = PayPeriodSchedule.calendarMonthly

        if case let .weekly(anchorDate) = weekly {
            #expect(anchorDate == date)
        } else {
            Issue.record("Не создан недельный период")
        }

        if case let .biweekly(anchorDate) = biweekly {
            #expect(anchorDate == date)
        } else {
            Issue.record("Не создан двухнедельный период")
        }

        guard case .calendarMonthly = calendarMonthly else {
            Issue.record("Не создан календарный месяц")
            return
        }
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
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: date.addingTimeInterval(1))

        let job = try makeJob(payRates: [firstPayRate, secondPayRate])

        #expect(job.payRates == [firstPayRate, secondPayRate])
    }

    @Test("Две ставки с одинаковой датой начала действия отклоняются")
    func rejectsDuplicatePayRateEffectiveFrom() throws {
        let firstPayRate = try makePayRate()
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: date)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try makeJob(payRates: [firstPayRate, secondPayRate])
        }
    }

    @Test("Порядок ставок не влияет на обнаружение повторяющейся даты")
    func rejectsDuplicatePayRateEffectiveFromInAnyOrder() throws {
        let firstPayRate = try makePayRate()
        let secondPayRate = try PayRate(amount: 130, effectiveFrom: date)

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
            payPeriodSchedule: .weekly(anchorDate: date),
            payRates: payRates,
            createdAt: date
        )
    }

    private func makePayRate(amount: Decimal = 120) throws -> PayRate {
        try PayRate(amount: amount, effectiveFrom: date)
    }
}
