import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct SL566PayRatePrecisionPersistenceTests {
    @Test(arguments: PayRateDecimalCodecTests.samples, [false, true])
    func productionWritesPreserveExactAmountAcrossReopen(_ text: String, _ hourly: Bool) async throws {
        let amount = try #require(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")))
        let basis: BasePayBasis = hourly ? .hourly : .fixedPerShift
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let effective = try LocalDate(date: start, in: timeZone)
        let jobRate = try PayRate(amount: amount, effectiveFrom: nil)
        let addedRate = try PayRate(amount: amount, effectiveFrom: nil)
        let datedRate = try PayRate(amount: amount, effectiveFrom: effective)
        let job = try Job(currencyCode: "EUR", timeZoneIdentifier: timeZone.identifier,
                          basePayBasis: basis, payCalculationCycle: .perShift, payRates: [jobRate])
        let primary = try #require(job.soleWorkType)
        let other = try WorkType(id: UUID(), name: "Other", basePayBasis: basis,
                                 payRateHistory: PayRateHistory(payRates: [addedRate]))
        let shift = try Shift(jobID: job.id, workTypeID: primary.id, start: start,
                              end: start.addingTimeInterval(3600))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("ShiftLedger.sqlite")

        do {
            let stack = try await CoreDataStack.load(storeURL: url)
            defer { try? close(stack) }
            let storage = JobStorage(stack: stack, now: { start })
            try storage.save(job)
            _ = try storage.addWorkType(other, toJobID: job.id)
            _ = try storage.addPayRate(datedRate, toWorkTypeID: primary.id, inJobID: job.id)
            try ShiftStorage(stack: stack).save(shift, forJobID: job.id)
        }

        let reopened = try await CoreDataStack.load(storeURL: url)
        defer { try? close(reopened) }
        let loaded = try #require(try JobStorage(stack: reopened).load())
        #expect(loaded.id == job.id)
        #expect(loaded.workType(id: primary.id)?.payRates == [jobRate, datedRate])
        #expect(loaded.workType(id: other.id)?.payRates == [addedRate])
        #expect(try ShiftStorage(stack: reopened).loadAll(forJobID: job.id) == [shift])
        #expect(try loaded.applicablePayRate(for: shift) == datedRate)
        let rows = try reopened.viewContext.fetch(NSFetchRequest<PayRateV7Entity>(entityName: "PayRateEntity"))
        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.amount == text })

        // Avoid invoking arithmetic near the representability limits of Decimal.
        if amount >= Decimal(1), amount < Decimal(1000) {
            #expect(try loaded.basePay(for: shift) == amount)
        }
    }

    private func close(_ stack: CoreDataStack) throws {
        stack.viewContext.reset()
        let coordinator = try #require(stack.viewContext.persistentStoreCoordinator)
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }
}
