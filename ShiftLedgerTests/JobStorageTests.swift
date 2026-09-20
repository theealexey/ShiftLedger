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
        let savedWorkTypes = try stackA.viewContext.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        #expect(savedWorkTypes.count == 1)
        #expect(savedWorkTypes.first?.id == job.soleWorkType?.id)
        #expect(savedWorkTypes.first?.basePayKind == "fixedPerShift")

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let restoredJob = try #require(try JobStorage(stack: stackB).load())

        #expect(restoredJob == job)
        #expect(restoredJob.soleWorkType?.basePayBasis == .fixedPerShift)
        #expect(
            try stackB.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).count == 1
        )
    }

    @Test("Multi-WorkType Job сохраняет независимые истории и восстанавливается новым stack")
    func persistsMultiWorkTypeJobAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000001"))
        let firstWorkTypeID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000002"))
        let secondWorkTypeID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000003"))
        let firstInitialRateID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000004"))
        let firstDatedRateID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000005"))
        let secondInitialRateID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000006"))
        let secondDatedRateID = try #require(UUID(uuidString: "01000000-0000-0000-0000-000000000007"))
        let firstEffectiveFrom = try LocalDate(year: 2026, month: 2, day: 1)
        let secondEffectiveFrom = try LocalDate(year: 2026, month: 3, day: 1)
        let first = WorkType(
            id: firstWorkTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(id: firstInitialRateID, amount: 100, effectiveFrom: nil),
                    try PayRate(
                        id: firstDatedRateID,
                        amount: 125,
                        effectiveFrom: firstEffectiveFrom
                    )
                ]
            )
        )
        let second = WorkType(
            id: secondWorkTypeID,
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(id: secondInitialRateID, amount: 500, effectiveFrom: nil),
                    try PayRate(
                        id: secondDatedRateID,
                        amount: 650,
                        effectiveFrom: secondEffectiveFrom
                    )
                ]
            )
        )
        let job = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [second, first],
            createdAt: Date(timeIntervalSinceReferenceDate: 100_000)
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        try JobStorage(stack: stackA).save(job)

        let persistedJobs = try stackA.viewContext.fetch(
            NSFetchRequest<JobEntity>(entityName: "JobEntity")
        )
        let persistedWorkTypes = try stackA.viewContext.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let persistedPayRates = try stackA.viewContext.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let persistedJob = try #require(persistedJobs.first)
        let persistedFirst = try #require(
            persistedWorkTypes.first { $0.id == firstWorkTypeID }
        )
        let persistedSecond = try #require(
            persistedWorkTypes.first { $0.id == secondWorkTypeID }
        )

        #expect(persistedJobs.count == 1)
        #expect(persistedWorkTypes.count == 2)
        #expect(persistedPayRates.count == 4)
        #expect(persistedJob.basePayKind == nil)
        #expect(persistedFirst.name == "Lectures")
        #expect(persistedSecond.name == "Exams")
        #expect(persistedFirst.basePayKind == "hourly")
        #expect(persistedSecond.basePayKind == "fixedPerShift")
        #expect(persistedFirst.job.objectID == persistedJob.objectID)
        #expect(persistedSecond.job.objectID == persistedJob.objectID)
        #expect(
            Set(persistedFirst.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set([firstInitialRateID, firstDatedRateID])
        )
        #expect(
            Set(persistedSecond.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set([secondInitialRateID, secondDatedRateID])
        )
        #expect(persistedPayRates.allSatisfy { $0.job.objectID == persistedJob.objectID })
        #expect(
            persistedPayRates
                .filter { [firstInitialRateID, firstDatedRateID].contains($0.id) }
                .allSatisfy { $0.workType?.objectID == persistedFirst.objectID }
        )
        #expect(
            persistedPayRates
                .filter { [secondInitialRateID, secondDatedRateID].contains($0.id) }
                .allSatisfy { $0.workType?.objectID == persistedSecond.objectID }
        )

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let restoredJob = try #require(try JobStorage(stack: stackB).load())

        #expect(restoredJob == job)
        #expect(restoredJob.workType(id: firstWorkTypeID) == first)
        #expect(restoredJob.workType(id: secondWorkTypeID) == second)
        #expect(restoredJob.workType(id: firstWorkTypeID)?.name == "Lectures")
        #expect(restoredJob.workType(id: secondWorkTypeID)?.name == "Exams")
        #expect(
            try stackB.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).count == 2
        )
    }

    @Test("WorkType добавляется к существующему Job и восстанавливается новым stack")
    func addsWorkTypeToPersistedJobAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let lecturesID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        let examsID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
        let lecturesInitialRateID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
        let lecturesDatedRateID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5))
        let examsInitialRateID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6))
        let examsDatedRateID = UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7))
        let lecturesEffectiveFrom = try LocalDate(year: 2026, month: 2, day: 1)
        let examsEffectiveFrom = try LocalDate(year: 2026, month: 3, day: 1)
        let lectures = WorkType(
            id: lecturesID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(id: lecturesInitialRateID, amount: 100, effectiveFrom: nil),
                    try PayRate(
                        id: lecturesDatedRateID,
                        amount: 125,
                        effectiveFrom: lecturesEffectiveFrom
                    )
                ]
            )
        )
        let exams = WorkType(
            id: examsID,
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(id: examsInitialRateID, amount: 500, effectiveFrom: nil),
                    try PayRate(
                        id: examsDatedRateID,
                        amount: 650,
                        effectiveFrom: examsEffectiveFrom
                    )
                ]
            )
        )
        let originalJob = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [lectures],
            createdAt: Date(timeIntervalSinceReferenceDate: 700_000)
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        let storageA = JobStorage(stack: stackA)
        try storageA.save(originalJob)

        let originalPersistedWorkType = try #require(
            try stackA.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).first
        )
        let originalPersistedPayRates = try stackA.viewContext.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let originalWorkTypeObjectID = originalPersistedWorkType.objectID
        let originalPayRateObjectIDs = Set(originalPersistedPayRates.map(\.objectID))

        let updatedJob = try storageA.addWorkType(exams)

        #expect(updatedJob.id == originalJob.id)
        #expect(updatedJob.currencyCode == originalJob.currencyCode)
        #expect(updatedJob.timeZoneIdentifier == originalJob.timeZoneIdentifier)
        #expect(updatedJob.payCalculationCycle == originalJob.payCalculationCycle)
        #expect(updatedJob.createdAt == originalJob.createdAt)
        #expect(updatedJob.workTypes.count == 2)
        #expect(updatedJob.workType(id: lecturesID) == lectures)
        #expect(updatedJob.workType(id: examsID) == exams)

        let persistedJobs = try stackA.viewContext.fetch(
            NSFetchRequest<JobEntity>(entityName: "JobEntity")
        )
        let persistedWorkTypes = try stackA.viewContext.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let persistedPayRates = try stackA.viewContext.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let persistedJob = try #require(persistedJobs.first)
        let persistedLectures = try #require(
            persistedWorkTypes.first { $0.id == lecturesID }
        )
        let persistedExams = try #require(
            persistedWorkTypes.first { $0.id == examsID }
        )
        let persistedLecturesInitialRate = try #require(
            persistedPayRates.first { $0.id == lecturesInitialRateID }
        )
        let persistedLecturesDatedRate = try #require(
            persistedPayRates.first { $0.id == lecturesDatedRateID }
        )
        let persistedExamsInitialRate = try #require(
            persistedPayRates.first { $0.id == examsInitialRateID }
        )
        let persistedExamsDatedRate = try #require(
            persistedPayRates.first { $0.id == examsDatedRateID }
        )
        let timeZone = try #require(TimeZone(identifier: originalJob.timeZoneIdentifier))
        let persistedLecturesEffectiveFrom = try lecturesEffectiveFrom.startOfDay(in: timeZone)
        let persistedExamsEffectiveFrom = try examsEffectiveFrom.startOfDay(in: timeZone)
        #expect(persistedLectures.objectID == originalWorkTypeObjectID)

        let persistedLecturesRateObjectIDs = Set(
            persistedPayRates
                .filter { [lecturesInitialRateID, lecturesDatedRateID].contains($0.id) }
                .map(\.objectID)
        )
        #expect(persistedLecturesRateObjectIDs == originalPayRateObjectIDs)
        #expect(persistedJobs.count == 1)
        #expect(persistedWorkTypes.count == 2)
        #expect(persistedPayRates.count == 4)
        #expect(persistedJob.id == originalJob.id)
        #expect(persistedJob.currencyCode == originalJob.currencyCode)
        #expect(persistedJob.timeZoneIdentifier == originalJob.timeZoneIdentifier)
        #expect(persistedJob.payPeriodKind == "perShift")
        #expect(persistedJob.payPeriodAnchorDate == nil)
        #expect(persistedJob.createdAt == originalJob.createdAt)
        #expect(persistedJob.basePayKind == nil)
        #expect(persistedLectures.name == "Lectures")
        #expect(persistedLectures.basePayKind == "hourly")
        #expect(persistedLectures.job.objectID == persistedJob.objectID)
        #expect(
            Set(persistedLectures.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set([lecturesInitialRateID, lecturesDatedRateID])
        )
        #expect(persistedLecturesInitialRate.amount.decimalValue == 100)
        #expect(persistedLecturesInitialRate.effectiveFrom == nil)
        #expect(persistedLecturesDatedRate.amount.decimalValue == 125)
        #expect(persistedLecturesDatedRate.effectiveFrom == persistedLecturesEffectiveFrom)
        #expect(persistedExams.id == examsID)
        #expect(persistedExams.name == "Exams")
        #expect(persistedExams.basePayKind == "fixedPerShift")
        #expect(persistedExams.job.objectID == persistedJob.objectID)
        #expect(
            Set(persistedExams.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set([examsInitialRateID, examsDatedRateID])
        )
        #expect(persistedExamsInitialRate.amount.decimalValue == 500)
        #expect(persistedExamsInitialRate.effectiveFrom == nil)
        #expect(persistedExamsDatedRate.amount.decimalValue == 650)
        #expect(persistedExamsDatedRate.effectiveFrom == persistedExamsEffectiveFrom)
        #expect(
            persistedPayRates
                .filter { [examsInitialRateID, examsDatedRateID].contains($0.id) }
                .allSatisfy {
                    $0.job.objectID == persistedJob.objectID
                        && $0.workType?.objectID == persistedExams.objectID
                }
        )

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let restoredJob = try #require(try JobStorage(stack: stackB).load())

        #expect(restoredJob == updatedJob)
        #expect(restoredJob.workType(id: lecturesID) == lectures)
        #expect(restoredJob.workType(id: examsID) == exams)
    }

    @Test("Повторяющийся WorkType ID отклоняется без изменения persisted Job")
    func rejectsDuplicateWorkTypeAdditionWithoutMutation() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let workTypeID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        let originalRateID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
        let suppliedRateID = UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
        let originalWorkType = WorkType(
            id: workTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(id: originalRateID, amount: 100, effectiveFrom: nil)]
            )
        )
        let duplicateWorkType = WorkType(
            id: workTypeID,
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(id: suppliedRateID, amount: 500, effectiveFrom: nil)]
            )
        )
        let originalJob = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [originalWorkType],
            createdAt: Date(timeIntervalSinceReferenceDate: 710_000)
        )

        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        let storageA = JobStorage(stack: stackA)
        try storageA.save(originalJob)

        var receivedExpectedError = false
        do {
            _ = try storageA.addWorkType(duplicateWorkType)
            Issue.record("WorkType с повторяющимся ID был добавлен")
        } catch JobStorageError.invalidWorkTypeAddition(underlying: .duplicateWorkTypeID) {
            receivedExpectedError = true
        } catch {
            Issue.record("Повторяющийся WorkType ID вернул неверную ошибку")
        }

        let persistedJobs = try stackA.viewContext.fetch(
            NSFetchRequest<JobEntity>(entityName: "JobEntity")
        )
        let persistedWorkTypes = try stackA.viewContext.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let persistedPayRates = try stackA.viewContext.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let persistedJob = try #require(persistedJobs.first)

        #expect(receivedExpectedError)
        #expect(try storageA.load() == originalJob)
        #expect(persistedWorkTypes.count == 1)
        #expect(persistedPayRates.count == 1)
        #expect(persistedJob.basePayKind == "hourly")
        #expect(persistedPayRates.contains { $0.id == originalRateID })
        #expect(persistedPayRates.contains { $0.id == suppliedRateID } == false)
        #expect(stackA.viewContext.hasChanges == false)

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        #expect(try JobStorage(stack: stackB).load() == originalJob)
    }

    @Test("Добавление WorkType в пустой store возвращает jobNotFound")
    func rejectsWorkTypeAdditionWhenNoJobExists() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let workType = WorkType(
            id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            name: nil,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ]
            )
        )
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        var receivedExpectedError = false
        do {
            _ = try JobStorage(stack: stack).addWorkType(workType)
            Issue.record("WorkType был добавлен без persisted Job")
        } catch JobStorageError.jobNotFound {
            receivedExpectedError = true
        } catch {
            Issue.record("Пустой store вернул неверную ошибку")
        }

        #expect(receivedExpectedError)
        #expect(
            try stack.viewContext.fetch(
                NSFetchRequest<JobEntity>(entityName: "JobEntity")
            ).isEmpty
        )
        #expect(
            try stack.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).isEmpty
        )
        #expect(
            try stack.viewContext.fetch(
                NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
            ).isEmpty
        )
        #expect(stack.viewContext.hasChanges == false)
    }

    @Test("Sole WorkType с произвольной identity сохраняется и восстанавливается")
    func persistsSoleArbitraryWorkTypeIdentityAcrossNewCoreDataStack() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = try #require(UUID(uuidString: "03000000-0000-0000-0000-000000000001"))
        let workTypeID = try #require(UUID(uuidString: "03000000-0000-0000-0000-000000000002"))
        let payRateID = try #require(UUID(uuidString: "03000000-0000-0000-0000-000000000003"))
        let workType = WorkType(
            id: workTypeID,
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)]
            )
        )
        let job = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let stackA = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackA)
        try JobStorage(stack: stackA).save(job)

        let persistedJob = try #require(
            try stackA.viewContext.fetch(
                NSFetchRequest<JobEntity>(entityName: "JobEntity")
            ).first
        )
        let persistedWorkType = try #require(
            try stackA.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).first
        )
        #expect(persistedWorkType.id == workTypeID)
        #expect(persistedWorkType.id != persistedJob.id)
        #expect(persistedWorkType.name == nil)
        #expect(persistedJob.basePayKind == "fixedPerShift")

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let restoredJob = try #require(try JobStorage(stack: stackB).load())

        #expect(restoredJob == job)
        #expect(restoredJob.soleWorkType?.id == workTypeID)
        #expect(restoredJob.soleWorkType?.name == nil)
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
            workTypeBasePayKind: "unknown",
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

    @Test("Job без canonical WorkType отклоняется")
    func rejectsMissingWorkType() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)
        try insertPersistedJob(
            id: try #require(UUID(uuidString: "7A000000-0000-0000-0000-000000000001")),
            payRateID: try #require(UUID(uuidString: "7A000000-0000-0000-0000-000000000002")),
            payRateEffectiveFrom: nil,
            includeWorkType: false,
            payPeriodAnchorDate: nil,
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Job без WorkType была принята")
        } catch JobStorageError.corruptedData(.missingWorkType) {
        } catch {
            Issue.record("Job без WorkType вернула неверную ошибку: \(error)")
        }
    }

    @Test("Повторяющиеся WorkType ID в SQLite отклоняются Domain validation")
    func rejectsPersistedJobWithDuplicateWorkTypeIDs() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let jobID = try #require(UUID(uuidString: "7B000000-0000-0000-0000-000000000001"))
        let duplicateWorkTypeID = try #require(
            UUID(uuidString: "7B000000-0000-0000-0000-000000000002")
        )
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)
        let persisted = try insertPersistedJob(
            id: jobID,
            payRateID: try #require(UUID(uuidString: "7B000000-0000-0000-0000-000000000003")),
            payRateEffectiveFrom: nil,
            workTypeID: duplicateWorkTypeID,
            payPeriodKind: "perShift",
            payPeriodAnchorDate: nil,
            in: stack.viewContext
        )
        let workTypeEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: stack.viewContext)
        )
        let payRateEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: stack.viewContext)
        )
        let duplicateWorkType = WorkTypeEntity(
            entity: workTypeEntityDescription,
            insertInto: stack.viewContext
        )
        duplicateWorkType.id = duplicateWorkTypeID
        duplicateWorkType.basePayKind = "fixedPerShift"
        duplicateWorkType.job = persisted.job

        let duplicateWorkTypeRate = PayRateEntity(
            entity: payRateEntityDescription,
            insertInto: stack.viewContext
        )
        duplicateWorkTypeRate.id = try #require(
            UUID(uuidString: "7B000000-0000-0000-0000-000000000004")
        )
        duplicateWorkTypeRate.amount = NSDecimalNumber(decimal: 500)
        duplicateWorkTypeRate.effectiveFrom = nil
        duplicateWorkTypeRate.job = persisted.job
        duplicateWorkTypeRate.workType = duplicateWorkType
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Job с повторяющимся WorkType ID была принята")
        } catch JobStorageError.corruptedData(.invalidJob(underlying: .duplicateWorkTypeID)) {
        } catch {
            Issue.record("Job с повторяющимся WorkType ID вернула неверную ошибку: \(error)")
        }
    }

    @Test("Неизвестная часовая зона в SQLite отклоняется с точной ошибкой")
    func rejectsPersistedJobWithInvalidTimeZone() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "13A2E4F6-8B10-4C2D-9E7F-6A5B4C3D2E1F")),
            payRateID: try #require(UUID(uuidString: "24B3F5A7-9C21-4D3E-8F60-7B6C5D4E3F20")),
            payRateEffectiveFrom: nil,
            timeZoneIdentifier: "Europe/Unknown",
            payPeriodAnchorDate: try anchorDate.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        do {
            _ = try JobStorage(stack: stack).load()
            Issue.record("Неизвестная часовая зона была принята")
        } catch JobStorageError.corruptedData(.invalidTimeZoneIdentifier(let identifier)) {
            #expect(identifier == "Europe/Unknown")
        } catch {
            Issue.record("Неизвестная часовая зона вернула неверную ошибку")
        }
    }

    @Test("Canonical WorkType определяет basis независимо от legacy Job mirror")
    func readsBasePayKindFromCanonicalWorkType() async throws {
        let storeURL = try makeTemporaryStoreURL()
        var stacks: [CoreDataStack] = []
        defer { removeTemporaryStoreDirectory(for: storeURL, stacks: stacks) }

        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let anchorDate = try LocalDate(year: 2026, month: 9, day: 1)
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stack)

        try insertPersistedJob(
            id: try #require(UUID(uuidString: "35C4A6F8-0B32-4E5D-9C71-8A6B5C4D3E2F")),
            payRateID: try #require(UUID(uuidString: "46D5B7A9-1C43-5F6E-8D82-9B7C6D5E4F30")),
            payRateEffectiveFrom: nil,
            workTypeBasePayKind: "fixedPerShift",
            legacyBasePayKind: nil,
            payPeriodAnchorDate: try anchorDate.startOfDay(in: timeZone),
            in: stack.viewContext
        )
        try stack.viewContext.save()

        let restoredJob = try #require(try JobStorage(stack: stack).load())

        #expect(restoredJob.soleWorkType?.basePayBasis == .fixedPerShift)
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

        let persistedJobs = try stackA.viewContext.fetch(
            NSFetchRequest<JobEntity>(entityName: "JobEntity")
        )
        let persistedWorkTypes = try stackA.viewContext.fetch(
            NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
        )
        let persistedPayRates = try stackA.viewContext.fetch(
            NSFetchRequest<PayRateEntity>(entityName: "PayRateEntity")
        )
        let persistedJob = try #require(persistedJobs.first)
        let persistedWorkType = try #require(persistedWorkTypes.first)
        let persistedInitialRate = try #require(
            persistedPayRates.first { $0.id == initialPayRateID }
        )
        let persistedEarlierRate = try #require(
            persistedPayRates.first { $0.id == earlierPayRateID }
        )
        let persistedLaterRate = try #require(
            persistedPayRates.first { $0.id == laterPayRateID }
        )
        let timeZone = try #require(TimeZone(identifier: job.timeZoneIdentifier))
        let persistedEarlierEffectiveFrom = try anchorDate.startOfDay(in: timeZone)
        let persistedLaterEffectiveFrom = try laterEffectiveFrom.startOfDay(in: timeZone)

        #expect(persistedJobs.count == 1)
        #expect(persistedWorkTypes.count == 1)
        #expect(persistedWorkType.id == job.soleWorkType?.id)
        #expect(persistedWorkType.id == persistedJob.id)
        #expect(persistedWorkType.basePayKind == "hourly")
        #expect(persistedWorkType.job.objectID == persistedJob.objectID)
        #expect(persistedJob.basePayKind == "hourly")
        #expect(
            Set(persistedWorkType.payRates?.compactMap { ($0 as? PayRateEntity)?.id } ?? [])
                == Set(job.soleWorkType?.payRates.map(\.id) ?? [])
        )
        #expect(
            persistedPayRates.allSatisfy {
                $0.workType?.objectID == persistedWorkType.objectID
            }
        )
        #expect(
            persistedPayRates.allSatisfy {
                $0.job.objectID == persistedJob.objectID
            }
        )
        #expect(persistedInitialRate.amount.decimalValue == 100)
        #expect(persistedInitialRate.effectiveFrom == nil)
        #expect(persistedEarlierRate.amount.decimalValue == earlierAmount)
        #expect(persistedEarlierRate.effectiveFrom == persistedEarlierEffectiveFrom)
        #expect(persistedLaterRate.amount.decimalValue == laterAmount)
        #expect(persistedLaterRate.effectiveFrom == persistedLaterEffectiveFrom)

        try close(stackA)

        let stackB = try await CoreDataStack.load(storeURL: storeURL)
        stacks.append(stackB)
        let storageB = JobStorage(stack: stackB)
        let restoredJob = try #require(try storageB.load())

        #expect(restoredJob.id == jobID)
        #expect(restoredJob.currencyCode == "EUR")
        #expect(restoredJob.timeZoneIdentifier == "Europe/Stockholm")
        #expect(restoredJob.payCalculationCycle == .scheduled(.weekly(anchorDate: anchorDate)))
        #expect(restoredJob.createdAt == createdAt)
        #expect(restoredJob.soleWorkType?.payRates.count == 3)
        #expect(restoredJob.soleWorkType?.payRates == [initialPayRate, earlierPayRate, laterPayRate])
        #expect(
            try stackB.viewContext.fetch(
                NSFetchRequest<WorkTypeEntity>(entityName: "WorkTypeEntity")
            ).count == 1
        )
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
        let workTypeEntity = try #require(
            jobEntity.workTypes?.anyObject() as? WorkTypeEntity
        )
        let payRateEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: stack.viewContext)
        )
        let duplicatePayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: stack.viewContext)
        duplicatePayRateEntity.id = duplicatePayRateID
        duplicatePayRateEntity.amount = NSDecimalNumber(decimal: 130)
        duplicatePayRateEntity.effectiveFrom = try secondEffectiveFrom.startOfDay(in: timeZone)
        duplicatePayRateEntity.job = jobEntity
        duplicatePayRateEntity.workType = workTypeEntity
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

    private func close(_ stack: CoreDataStack) throws {
        let context = stack.viewContext
        context.reset()
        guard let coordinator = context.persistentStoreCoordinator else {
            return
        }
        for persistentStore in coordinator.persistentStores {
            try coordinator.remove(persistentStore)
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

    @discardableResult
    private func insertPersistedJob(
        id: UUID,
        payRateID: UUID,
        payRateEffectiveFrom: Date?,
        payRateAmount: Decimal = 120,
        includeInitialPayRate: Bool = true,
        additionalInitialPayRate: Bool = false,
        workTypeBasePayKind: String = "hourly",
        legacyBasePayKind: String? = "hourly",
        workTypeID: UUID? = nil,
        includeWorkType: Bool = true,
        timeZoneIdentifier: String = "Europe/Stockholm",
        payPeriodKind: String = "weekly",
        payPeriodAnchorDate: Date?,
        in context: NSManagedObjectContext
    ) throws -> (job: JobEntity, workType: WorkTypeEntity?, payRates: [PayRateEntity]) {
        let jobEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "JobEntity", in: context)
        )
        let workTypeEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "WorkTypeEntity", in: context)
        )
        let payRateEntityDescription = try #require(
            NSEntityDescription.entity(forEntityName: "PayRateEntity", in: context)
        )

        let jobEntity = JobEntity(entity: jobEntityDescription, insertInto: context)
        jobEntity.id = id
        jobEntity.currencyCode = "EUR"
        jobEntity.timeZoneIdentifier = timeZoneIdentifier
        jobEntity.basePayKind = legacyBasePayKind
        jobEntity.payPeriodKind = payPeriodKind
        jobEntity.payPeriodAnchorDate = payPeriodAnchorDate
        jobEntity.createdAt = Date(timeIntervalSinceReferenceDate: 900_000)

        let workTypeEntity: WorkTypeEntity?
        if includeWorkType {
            let entity = WorkTypeEntity(
                entity: workTypeEntityDescription,
                insertInto: context
            )
            entity.id = workTypeID ?? id
            entity.basePayKind = workTypeBasePayKind
            entity.job = jobEntity
            workTypeEntity = entity
        } else {
            workTypeEntity = nil
        }

        let payRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
        payRateEntity.id = payRateID
        payRateEntity.amount = NSDecimalNumber(decimal: payRateAmount)
        payRateEntity.effectiveFrom = payRateEffectiveFrom
        payRateEntity.job = jobEntity
        payRateEntity.workType = workTypeEntity
        var payRateEntities = [payRateEntity]

        if includeInitialPayRate && payRateEffectiveFrom != nil {
            let initialPayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            initialPayRateEntity.id = UUID()
            initialPayRateEntity.amount = NSDecimalNumber(decimal: 121)
            initialPayRateEntity.effectiveFrom = nil
            initialPayRateEntity.job = jobEntity
            initialPayRateEntity.workType = workTypeEntity
            payRateEntities.append(initialPayRateEntity)
        }

        if additionalInitialPayRate {
            let initialPayRateEntity = PayRateEntity(entity: payRateEntityDescription, insertInto: context)
            initialPayRateEntity.id = UUID()
            initialPayRateEntity.amount = NSDecimalNumber(decimal: 121)
            initialPayRateEntity.effectiveFrom = nil
            initialPayRateEntity.job = jobEntity
            initialPayRateEntity.workType = workTypeEntity
            payRateEntities.append(initialPayRateEntity)
        }

        return (jobEntity, workTypeEntity, payRateEntities)
    }
}
