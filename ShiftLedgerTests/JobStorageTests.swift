import CoreData
import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct JobStorageTests {
    @Test("Job с perShift сохраняется и восстанавливается новым Core Data stack")
    func persistsPerShiftJobAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let payRate = try PayRate(
            amount: 24.50,
            effectiveFrom: nil
        )
        let job = try makeJob(
            id: try #require(UUID(uuidString: "D5E1C53B-CA4E-4C37-98DC-B8E4F6A0B56F")),
            payRates: [payRate],
            basePayBasis: .fixedPerShift,
            payCalculationCycle: .perShift
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        try JobStorage(stack: stackA).save(job)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let restoredJob = try #require(try JobStorage(stack: stackB).load())

        #expect(restoredJob == job)
        #expect(restoredJob.basePayBasis == .fixedPerShift)
    }

    @Test("Неизвестная база оплаты в SQLite отклоняется")
    func rejectsUnknownBasePayKind() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let effectiveFrom = try LocalDate(year: 2026, month: 1, day: 1)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "2A6D58B5-6B9D-4D60-9EAE-9B9A0B7F2D6A")),
            payRateID: try #require(UUID(uuidString: "4B5A3AF5-1E65-459B-A7D0-2AC5B5E77B26")),
            payRateEffectiveFrom: nil,
            basePayKind: "unknown",
            payPeriodAnchorDate: try effectiveFrom.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Неизвестная база оплаты была принята")
        } catch JobStorageError.corruptedData(.unknownBasePayKind("unknown")) {
        } catch {
            Issue.record("Неизвестная база оплаты вернула неверную ошибку")
        }
    }

    @Test("Job сохраняется в SQLite и восстанавливается новым Core Data stack")
    func persistsJobAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = try #require(UUID(uuidString: "7F807529-1C39-4980-A9C1-237D56B6A407"))
        let initialPayRateID = try #require(UUID(uuidString: "A4D3E2F1-0B9C-4D8E-8F71-4C2B6A9D3E10"))
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
        let initialPayRate = try PayRate(
            id: initialPayRateID,
            amount: 100,
            effectiveFrom: nil
        )
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
            currencyCode: "eur",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .scheduled(.weekly(anchorDate: anchorDate)),
            payRates: [laterPayRate, earlierPayRate, initialPayRate],
            createdAt: createdAt
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        let storageA = JobStorage(stack: stackA)
        try storageA.save(job)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let storageB = JobStorage(stack: stackB)
        let restoredJob = try #require(try storageB.load())

        #expect(restoredJob.id == jobID)
        #expect(restoredJob.currencyCode == "EUR")
        #expect(restoredJob.timeZoneIdentifier == "Europe/Stockholm")
        #expect(restoredJob.payCalculationCycle == .scheduled(.weekly(anchorDate: anchorDate)))
        #expect(restoredJob.createdAt == createdAt)
        #expect(restoredJob.payRates.count == 3)
        #expect(restoredJob.payRates == [initialPayRate, earlierPayRate, laterPayRate])
    }

    @Test("Пустой SQLite store не содержит Job")
    func loadsNilFromEmptyStore() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)
        let storage = JobStorage(stack: stack)
        let loadedJob = try storage.load()

        #expect(loadedJob == nil)
    }

    @Test("Вторая Job отклоняется без потери первой")
    func rejectsSecondJobAndPreservesFirstJob() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let firstPayRate = try PayRate(
            id: try #require(UUID(uuidString: "38A1902D-198E-4DA0-BDC8-A3FDCD08FA60")),
            amount: 120,
            effectiveFrom: nil
        )
        let firstJob = try makeJob(
            id: try #require(UUID(uuidString: "34199544-BFCC-4D8A-9F71-1A825CDEDF6C")),
            payRates: [firstPayRate]
        )
        let secondPayRate = try PayRate(
            id: try #require(UUID(uuidString: "7B9BA4E5-9A0F-47A1-A3E9-19BC1B9323D5")),
            amount: 130,
            effectiveFrom: nil
        )
        let secondJob = try makeJob(
            id: try #require(UUID(uuidString: "851433A4-C26C-4A23-9FBC-E58AC4AAC7A9")),
            payRates: [secondPayRate]
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
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
        stacks.append(stackB)
        let storageB = JobStorage(stack: stackB)
        let loadedFromStackB = try #require(try storageB.load())
        #expect(loadedFromStackB == firstJob)
    }

    @Test("Неканоническая дата ставки в SQLite отклоняется")
    func rejectsNonCanonicalPayRateEffectiveFrom() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let canonicalAnchorDate = try anchorDate.startOfDay(in: timeZone)
        let canonicalPayRateDate = try anchorDate.startOfDay(in: timeZone)
        let nonCanonicalPayRateDate = canonicalPayRateDate.addingTimeInterval(60 * 60)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "EF86AAAC-F75C-4E1F-AE61-D53A483FC4F4")),
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

    @Test("Некорректная сумма ставки в SQLite отклоняется typed corruption")
    func rejectsPersistedPayRateWithInvalidAmount() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "B1C2D3E4-F506-4789-ABCD-EF0123456780")),
            payRateID: try #require(UUID(uuidString: "C1D2E3F4-A506-4789-BCDE-F01234567890")),
            payRateEffectiveFrom: nil,
            payRateAmount: 0,
            payPeriodAnchorDate: try anchorDate.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Некорректная сумма ставки была принята")
        } catch JobStorageError.corruptedData(.invalidPayRate(underlying: .nonPositiveAmount)) {
        } catch {
            Issue.record("Некорректная сумма ставки вернула неверную ошибку")
        }
    }

    @Test("SQLite без initial ставки отклоняется typed corruption")
    func rejectsPersistedJobWithoutInitialPayRate() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let datedRateDate = try LocalDate(year: 2026, month: 9, day: 1)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "C9C6B1F0-0D82-4C67-A6E5-56F8D8BE1B4A")),
            payRateID: try #require(UUID(uuidString: "B95A0E3B-2D33-4D69-BF20-8C4B52B56A21")),
            payRateEffectiveFrom: try datedRateDate.startOfDay(in: timeZone),
            includeInitialPayRate: false,
            payPeriodAnchorDate: try datedRateDate.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Job без initial ставки был принят")
        } catch JobStorageError.corruptedData(.invalidJob(underlying: JobValidationError.missingInitialPayRate)) {
        } catch {
            Issue.record("Job без initial ставки вернул неверную ошибку")
        }
    }

    @Test("SQLite с двумя initial ставками отклоняется typed corruption")
    func rejectsPersistedJobWithMultipleInitialPayRates() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "D09B3C3E-4CE8-4C5B-BAA5-0E80F3AD6D27")),
            payRateID: try #require(UUID(uuidString: "F5BB5780-59C6-4A7E-8F22-6A4BEB36CD29")),
            payRateEffectiveFrom: nil,
            additionalInitialPayRate: true,
            payPeriodAnchorDate: try anchorDate.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Job с двумя initial ставками был принят")
        } catch JobStorageError.corruptedData(.invalidJob(underlying: JobValidationError.multipleInitialPayRates)) {
        } catch {
            Issue.record("Job с двумя initial ставками вернул неверную ошибку")
        }
    }

    @Test("Одинаковые ID ставок в SQLite отклоняются typed corruption")
    func rejectsPersistedJobWithDuplicatePayRateIDs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let firstEffectiveFrom = try LocalDate(year: 2026, month: 9, day: 1)
        let secondEffectiveFrom = try LocalDate(year: 2026, month: 10, day: 1)
        let duplicatePayRateID = try #require(UUID(uuidString: "6A7B8C9D-0E1F-4A2B-8C3D-4E5F60718293"))
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "A1B2C3D4-E5F6-4789-ABCD-EF0123456789")),
            payRateID: duplicatePayRateID,
            payRateEffectiveFrom: try firstEffectiveFrom.startOfDay(in: timeZone),
            payPeriodAnchorDate: try firstEffectiveFrom.startOfDay(in: timeZone),
            in: stack.viewContext
        )

        let jobEntity = try #require(
            try stack.viewContext.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity")).first
        )
        let payRateEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: stack.viewContext)
        )
        let duplicatePayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: stack.viewContext)
        duplicatePayRateEntity.id = duplicatePayRateID
        duplicatePayRateEntity.amount = NSDecimalNumber(decimal: 130)
        duplicatePayRateEntity.effectiveFrom = try secondEffectiveFrom.startOfDay(in: timeZone)
        duplicatePayRateEntity.job = jobEntity
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Job с повторяющимся ID ставки был принят")
        } catch JobStorageError.corruptedData(.invalidJob(underlying: .duplicatePayRateID)) {
        } catch {
            Issue.record("Job с повторяющимся ID ставки вернул неверную ошибку")
        }
    }

    @Test("Per-shift с anchor в SQLite отклоняется")
    func rejectsPerShiftAnchorDate() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let canonicalAnchorDate = try anchorDate.startOfDay(in: timeZone)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "E8F6E9E9-AC78-4FBA-AE10-9B2B6CA5D83F")),
            payRateID: try #require(UUID(uuidString: "9A09E6D7-73D7-4DA8-83EF-247A2B933CB4")),
            payRateEffectiveFrom: canonicalAnchorDate,
            payPeriodKind: "perShift",
            payPeriodAnchorDate: canonicalAnchorDate,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Per-shift с anchor был принят")
        } catch JobStorageError.corruptedData(.unexpectedPayPeriodAnchorDate(payPeriodKind: "perShift")) {
        } catch {
            Issue.record("Per-shift с anchor вернул неверную ошибку")
        }
    }

    @Test("Несколько Job в SQLite отклоняются как corruption")
    func rejectsMultiplePersistedJobs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let canonicalAnchorDate = try anchorDate.startOfDay(in: timeZone)
        let firstPayRateDate = try LocalDate(year: 2026, month: 9, day: 1).startOfDay(in: timeZone)
        let secondPayRateDate = try LocalDate(year: 2026, month: 10, day: 1).startOfDay(in: timeZone)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "F2C97089-8A9D-4705-8370-2CF7796E9F85")),
            payRateID: try #require(UUID(uuidString: "A00C6FB1-A739-4752-80E3-380F6DB0C1EF")),
            payRateEffectiveFrom: firstPayRateDate,
            payPeriodAnchorDate: canonicalAnchorDate,
            in: stack.viewContext
        )
        try insertPersistedJob(
            id: try #require(UUID(uuidString: "5FF3F4FA-43F0-4343-B645-D73E5A858A34")),
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

    private func removeTemporaryStoreDirectory(for storeURL: URL, stacks: [CoreDataStack]) {
        for stack in stacks {
            let context = stack.viewContext
            context.reset()

            guard let coordinator = context.persistentStoreCoordinator else {
                continue
            }

            for persistentStore in coordinator.persistentStores {
                do {
                    try coordinator.remove(persistentStore)
                } catch {
                    Issue.record(error)
                }
            }
        }

        do {
            try FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        } catch {
            Issue.record(error)
        }
    }

    private func makeJob(
        id: UUID,
        payRates: [PayRate],
        basePayBasis: BasePayBasis = .hourly,
        payCalculationCycle: PayCalculationCycle? = nil
    ) throws -> Job {
        let cycle = try payCalculationCycle ?? .scheduled(
            .weekly(anchorDate: LocalDate(year: 2026, month: 1, day: 1))
        )
        return try Job(
            id: id,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: basePayBasis,
            payCalculationCycle: cycle,
            payRates: payRates,
            createdAt: Date(timeIntervalSinceReferenceDate: 750_000)
        )
    }

    private func insertPersistedJob(
        id: UUID,
        payRateID: UUID,
        payRateEffectiveFrom: Date?,
        payRateAmount: Decimal = 120,
        includeInitialPayRate: Bool = true,
        additionalInitialPayRate: Bool = false,
        basePayKind: String? = nil,
        payPeriodKind: String = "weekly",
        payPeriodAnchorDate: Date?,
        in context: NSManagedObjectContext
    ) throws {
        let jobEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "JobEntity", in: context)
        )
        let payRateEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context)
        )

        let jobEntity = JobEntity(entity: jobEntityDescription, insertInto: context)
        jobEntity.id = id
        jobEntity.currencyCode = "EUR"
        jobEntity.timeZoneIdentifier = "Europe/Stockholm"
        jobEntity.basePayKind = basePayKind
        jobEntity.payPeriodKind = payPeriodKind
        jobEntity.payPeriodAnchorDate = payPeriodAnchorDate
        jobEntity.createdAt = Date(timeIntervalSinceReferenceDate: 900_000)

        let payRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
        payRateEntity.id = payRateID
        payRateEntity.amount = NSDecimalNumber(decimal: payRateAmount)
        payRateEntity.effectiveFrom = payRateEffectiveFrom
        payRateEntity.job = jobEntity

        if includeInitialPayRate && payRateEffectiveFrom != nil {
            let initialPayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            initialPayRateEntity.id = UUID()
            initialPayRateEntity.amount = NSDecimalNumber(decimal: 121)
            initialPayRateEntity.effectiveFrom = nil
            initialPayRateEntity.job = jobEntity
        }

        if additionalInitialPayRate {
            let initialPayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            initialPayRateEntity.id = UUID()
            initialPayRateEntity.amount = NSDecimalNumber(decimal: 121)
            initialPayRateEntity.effectiveFrom = nil
            initialPayRateEntity.job = jobEntity
        }
    }
}
