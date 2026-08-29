import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct JobStorageTests {
    @Test("Job сохраняется в SQLite и восстанавливается новым Core Data stack")
    func persistsJobAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeTemporaryStoreDirectory(for: storeURL) }

        let jobID = try #require(UUID(uuidString: "7F807529-1C39-4980-A9C1-237D56B6A407"))
        let earlierPayRateID = try #require(UUID(uuidString: "E11289B7-AFBF-4688-ACF2-F7B343EF2CF4"))
        let laterPayRateID = try #require(UUID(uuidString: "B8D7E993-B2CA-44C6-8B67-A01A0DE190DD"))
        let earlierAmount = try #require(
            Decimal(string: "123.45", locale: Locale(identifier: "en_US_POSIX"))
        )
        let laterAmount = try #require(
            Decimal(string: "234.56", locale: Locale(identifier: "en_US_POSIX"))
        )
        let anchorDate = try LocalDate(year: 2026, month: 3, day: 29)
        let laterEffectiveFrom = try LocalDate(year: 2026, month: 4, day: 1)
        let earlierPayRate = try PayRate(
            id: earlierPayRateID,
            amount: earlierAmount,
            effectiveFrom: anchorDate
        )
        let laterPayRate = try PayRate(
            id: laterPayRateID,
            amount: laterAmount,
            effectiveFrom: laterEffectiveFrom
        )
        let createdAt = Date(timeIntervalSinceReferenceDate: 500_000)
        let job = try Job(
            id: jobID,
            name: " \n Основная работа \t",
            currencyCode: "eur",
            timeZoneIdentifier: "Europe/Stockholm",
            payPeriodSchedule: .weekly(anchorDate: anchorDate),
            payRates: [laterPayRate, earlierPayRate],
            createdAt: createdAt
        )

        do {
            let stackA = try await CoreDataStack.load(storeURL: storeURL)
            let storageA = JobStorage(stack: stackA)
            try storageA.save(job)
        }

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        let storageB = JobStorage(stack: stackB)
        let restoredJob = try #require(try storageB.load())

        #expect(restoredJob.id == jobID)
        #expect(restoredJob.name == "Основная работа")
        #expect(restoredJob.currencyCode == "EUR")
        #expect(restoredJob.timeZoneIdentifier == "Europe/Stockholm")
        #expect(restoredJob.payPeriodSchedule == .weekly(anchorDate: anchorDate))
        #expect(restoredJob.createdAt == createdAt)
        #expect(restoredJob.payRates.count == 2)
        #expect(restoredJob.payRates == [earlierPayRate, laterPayRate])
    }

    @Test("Пустой SQLite store не содержит Job")
    func loadsNilFromEmptyStore() async throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeTemporaryStoreDirectory(for: storeURL) }

        let stack = try await CoreDataStack.load(storeURL: storeURL)
        let storage = JobStorage(stack: stack)
        let loadedJob = try storage.load()

        #expect(loadedJob == nil)
    }

    @Test("Вторая Job отклоняется без потери первой")
    func rejectsSecondJobAndPreservesFirstJob() async throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeTemporaryStoreDirectory(for: storeURL) }

        let firstPayRate = try PayRate(
            id: try #require(UUID(uuidString: "38A1902D-198E-4DA0-BDC8-A3FDCD08FA60")),
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 1, day: 1)
        )
        let firstJob = try makeJob(
            id: try #require(UUID(uuidString: "34199544-BFCC-4D8A-9F71-1A825CDEDF6C")),
            name: "Первая работа",
            payRates: [firstPayRate]
        )
        let secondPayRate = try PayRate(
            id: try #require(UUID(uuidString: "7B9BA4E5-9A0F-47A1-A3E9-19BC1B9323D5")),
            amount: 130,
            effectiveFrom: try LocalDate(year: 2026, month: 2, day: 1)
        )
        let secondJob = try makeJob(
            id: try #require(UUID(uuidString: "851433A4-C26C-4A23-9FBC-E58AC4AAC7A9")),
            name: "Вторая работа",
            payRates: [secondPayRate]
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        let storageA = JobStorage(stack: stackA)
        try storageA.save(firstJob)

        do {
            try storageA.save(secondJob)
            Issue.record("Вторая работа была сохранена")
        } catch JobStorageError.jobAlreadyExists {
        } catch {
            Issue.record("Вторая работа вернула неверную ошибку")
        }

        let loadedFromStackA = try #require(try storageA.load())
        #expect(loadedFromStackA == firstJob)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        let storageB = JobStorage(stack: stackB)
        let loadedFromStackB = try #require(try storageB.load())
        #expect(loadedFromStackB == firstJob)
    }

    @Test("Неканоническая дата ставки в SQLite отклоняется")
    func rejectsNonCanonicalPayRateEffectiveFrom() async throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeTemporaryStoreDirectory(for: storeURL) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let canonicalAnchorDate = try anchorDate.startOfDay(in: timeZone)
        let canonicalPayRateDate = try anchorDate.startOfDay(in: timeZone)
        let nonCanonicalPayRateDate = canonicalPayRateDate.addingTimeInterval(60 * 60)
        let stack = try await CoreDataStack.load(storeURL: storeURL)

        insertPersistedJob(
            id: try #require(UUID(uuidString: "EF86AAAC-F75C-4E1F-AE61-D53A483FC4F4")),
            name: "Повреждённая работа",
            payRateID: try #require(UUID(uuidString: "1E8C105B-11D7-4BD1-B95D-E27A2B3DDFCA")),
            payRateEffectiveFrom: nonCanonicalPayRateDate,
            payPeriodAnchorDate: canonicalAnchorDate,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        let storage = JobStorage(stack: stack)

        do {
            _ = try storage.load()
            Issue.record("Неканоническая дата ставки была принята")
        } catch JobStorageError.corruptedData(.nonCanonicalPayRateEffectiveFrom) {
        } catch {
            Issue.record("Неканоническая дата ставки вернула неверную ошибку")
        }
    }

    @Test("Несколько Job в SQLite отклоняются как corruption")
    func rejectsMultiplePersistedJobs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        defer { removeTemporaryStoreDirectory(for: storeURL) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let canonicalAnchorDate = try anchorDate.startOfDay(in: timeZone)
        let firstPayRateDate = try LocalDate(year: 2026, month: 9, day: 1).startOfDay(in: timeZone)
        let secondPayRateDate = try LocalDate(year: 2026, month: 10, day: 1).startOfDay(in: timeZone)
        let stack = try await CoreDataStack.load(storeURL: storeURL)

        insertPersistedJob(
            id: try #require(UUID(uuidString: "F2C97089-8A9D-4705-8370-2CF7796E9F85")),
            name: "Первая сохранённая работа",
            payRateID: try #require(UUID(uuidString: "A00C6FB1-A739-4752-80E3-380F6DB0C1EF")),
            payRateEffectiveFrom: firstPayRateDate,
            payPeriodAnchorDate: canonicalAnchorDate,
            in: stack.viewContext
        )
        insertPersistedJob(
            id: try #require(UUID(uuidString: "5FF3F4FA-43F0-4343-B645-D73E5A858A34")),
            name: "Вторая сохранённая работа",
            payRateID: try #require(UUID(uuidString: "4FB0D747-EA47-49A2-BD66-A0E2CF3C1E5D")),
            payRateEffectiveFrom: secondPayRateDate,
            payPeriodAnchorDate: canonicalAnchorDate,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        let storage = JobStorage(stack: stack)

        do {
            _ = try storage.load()
            Issue.record("Несколько сохранённых работ были приняты")
        } catch JobStorageError.multipleJobsFound {
        } catch {
            Issue.record("Несколько сохранённых работ вернули неверную ошибку")
        }
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func removeTemporaryStoreDirectory(for storeURL: URL) {
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }

    private func makeJob(id: UUID, name: String, payRates: [PayRate]) throws -> Job {
        try Job(
            id: id,
            name: name,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payPeriodSchedule: .weekly(anchorDate: try LocalDate(year: 2026, month: 1, day: 1)),
            payRates: payRates,
            createdAt: Date(timeIntervalSinceReferenceDate: 750_000)
        )
    }

    private func insertPersistedJob(
        id: UUID,
        name: String,
        payRateID: UUID,
        payRateEffectiveFrom: Date,
        payPeriodAnchorDate: Date,
        in context: NSManagedObjectContext
    ) {
        let jobEntity = JobEntity(context: context)
        jobEntity.id = id
        jobEntity.name = name
        jobEntity.currencyCode = "EUR"
        jobEntity.timeZoneIdentifier = "Europe/Stockholm"
        jobEntity.payPeriodKind = "weekly"
        jobEntity.payPeriodAnchorDate = payPeriodAnchorDate
        jobEntity.createdAt = Date(timeIntervalSinceReferenceDate: 900_000)

        let payRateEntity = PayRateEntity(context: context)
        payRateEntity.id = payRateID
        payRateEntity.amount = NSDecimalNumber(decimal: 120)
        payRateEntity.effectiveFrom = payRateEffectiveFrom
        payRateEntity.job = jobEntity
    }
}
