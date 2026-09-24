import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ChangePayRateViewModelTests {
    private let workTypeID = UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let newRateID = UUID(uuid: (0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))

    @Test("Blank and nonpositive amounts are invalid; injected locale preserves Decimal precision")
    func validatesAmount() throws {
        let date = try LocalDate(year: 2026, month: 5, day: 2)
            .startOfDay(in: try #require(TimeZone(identifier: "Europe/Stockholm")))
        let model = ChangePayRateViewModel(
            workType: try makeWorkType(),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            decimalInputLocale: Locale(identifier: "de_DE"),
            initialEffectiveDate: date,
            savePayRate: { _, _ in .failure(.persistence) }
        )
        #expect(model.amountText.isEmpty)
        #expect(model.effectiveDate == date)
        #expect(model.canSave == false)
        model.updateAmountText("0")
        #expect(model.canSave == false)
        model.updateAmountText("-1")
        #expect(model.canSave == false)
        model.updateAmountText("12.50")
        #expect(model.canSave == false)
        model.updateAmountText("12,345")
        #expect(model.amount == Decimal(string: "12.345"))
        #expect(model.canSave)
    }

    @Test("Effective date uses Job timezone and duplicate date clears when changed")
    func validatesEffectiveDate() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let duplicate = try LocalDate(year: 2026, month: 5, day: 2)
        let model = ChangePayRateViewModel(
            workType: try makeWorkType(dated: duplicate),
            currencyCode: "EUR",
            timeZoneIdentifier: zone.identifier,
            initialEffectiveDate: try duplicate.startOfDay(in: zone).addingTimeInterval(30 * 60),
            savePayRate: { _, _ in .failure(.persistence) }
        )
        model.updateAmountText("25")
        #expect(model.effectiveLocalDate == duplicate)
        #expect(model.hasDuplicateEffectiveDate)
        #expect(model.canSave == false)
        let previousDay = try LocalDate(year: 2026, month: 5, day: 1)
        model.updateEffectiveDate(try previousDay.startOfDay(in: zone).addingTimeInterval(30 * 60))
        #expect(model.effectiveLocalDate == previousDay)
        #expect(model.hasDuplicateEffectiveDate == false)
        #expect(model.canSave)
        let future = try LocalDate(year: 2027, month: 5, day: 1)
        model.updateEffectiveDate(try future.startOfDay(in: zone))
        #expect(model.effectiveLocalDate == future)
        #expect(model.canSave)
    }

    @Test("Save forwards exact IDs, amount and local date; success blocks duplicate submission")
    func savesExactRateOnce() throws {
        let workType = try makeWorkType()
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let localDate = try LocalDate(year: 2026, month: 7, day: 3)
        let expectedRate = try PayRate(id: newRateID, amount: 12.345, effectiveFrom: localDate)
        let updatedJob = try makeJob(workType: workType.addingPayRate(expectedRate))
        var received: [(UUID, PayRate)] = []
        let model = ChangePayRateViewModel(
            workType: workType,
            currencyCode: "EUR",
            timeZoneIdentifier: zone.identifier,
            decimalInputLocale: Locale(identifier: "en_US"),
            initialEffectiveDate: try localDate.startOfDay(in: zone),
            makePayRateID: { newRateID },
            savePayRate: { id, rate in
                received.append((id, rate))
                return .success(updatedJob)
            }
        )
        model.updateAmountText("12.345")
        #expect(model.save() == .saved(updatedJob))
        #expect(received.count == 1)
        #expect(received.first?.0 == workTypeID)
        #expect(received.first?.1 == expectedRate)
        #expect(workType.payRates.count == 1)
        #expect(model.canSave == false)
        #expect(model.save() == .ignored)
        #expect(received.count == 1)
    }

    @Test("Failure preserves amount/date and permits retry; reentrant save is ignored")
    func failureAndRetry() throws {
        let date = try LocalDate(year: 2026, month: 7, day: 3)
            .startOfDay(in: try #require(TimeZone(identifier: "Europe/Stockholm")))
        var model: ChangePayRateViewModel?
        var nested: ChangePayRateSaveResult?
        var calls = 0
        model = ChangePayRateViewModel(
            workType: try makeWorkType(),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            initialEffectiveDate: date,
            savePayRate: { _, _ in
                calls += 1
                nested = model?.save()
                return .failure(.persistence)
            }
        )
        let subject = try #require(model)
        subject.updateAmountText("55")
        #expect(subject.save() == .failed(.persistence))
        #expect(nested == .ignored)
        #expect(subject.amountText == "55")
        #expect(subject.effectiveDate == date)
        #expect(subject.canSave)
        #expect(subject.save() == .failed(.persistence))
        #expect(calls == 2)
    }

    private func makeWorkType(dated: LocalDate? = nil) throws -> WorkType {
        var rates = [try PayRate(amount: 10, effectiveFrom: nil)]
        if let dated {
            rates.append(try PayRate(amount: 15, effectiveFrom: dated))
        }
        return WorkType(
            id: workTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: rates)
        )
    }

    private func makeJob(workType: WorkType) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType]
        )
    }
}
