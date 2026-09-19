import CoreData
import Foundation
import Testing

struct LegacyCoreDataStoreFixtureTests: Sendable {
    @Test("Legacy Core Data model загружается как точная именованная версия")
    func loadsExplicitLegacyModelVersion() throws {
        let model = try LegacyCoreDataStoreFixture.loadLegacyModel()

        #expect(Set(model.entitiesByName.keys) == ["JobEntity", "PayRateEntity", "ShiftEntity"])
        #expect(model.entitiesByName["WorkTypeEntity"] == nil)
    }

    @Test("Hourly V1 fixture содержит детерминированный legacy graph")
    func createsHourlyScheduledLegacyStore() throws {
        try verifyLegacyStore(
            payBasis: .hourly,
            payPeriod: .weekly,
            expectedPayPeriodKind: "weekly",
            expectsPayPeriodAnchor: true
        )
    }

    @Test("Fixed-per-shift V1 fixture сохраняет per-shift payroll encoding")
    func createsFixedPerShiftLegacyStore() throws {
        try verifyLegacyStore(
            payBasis: .fixedPerShift,
            payPeriod: .perShift,
            expectedPayPeriodKind: "perShift",
            expectsPayPeriodAnchor: false
        )
    }

    private func verifyLegacyStore(
        payBasis: LegacyCoreDataStoreFixture.PayBasis,
        payPeriod: LegacyCoreDataStoreFixture.PayPeriod,
        expectedPayPeriodKind: String,
        expectsPayPeriodAnchor: Bool
    ) throws {
        let fixture = try LegacyCoreDataStoreFixture.make(
            payBasis: payBasis,
            payPeriod: payPeriod
        )
        defer {
            do {
                try fixture.remove()
            } catch {
                Issue.record(error)
            }
        }
        let expectedJobID = try uuid("10000000-0000-0000-0000-000000000001")
        #expect(fixture.identifiers.job == expectedJobID)
        #expect(fixture.storeURL.pathExtension == "sqlite")
        #expect(FileManager.default.fileExists(atPath: fixture.storeURL.path))

        try fixture.inspect { context in
            let jobs = try fetch(entityName: "JobEntity", in: context)
            let job = try #require(jobs.first)
            #expect(jobs.count == 1)
            #expect(job.value(forKey: "id") as? UUID == fixture.identifiers.job)
            #expect(job.value(forKey: "currencyCode") as? String == "SEK")
            #expect(job.value(forKey: "timeZoneIdentifier") as? String == "Europe/Stockholm")
            #expect(job.value(forKey: "basePayKind") as? String == payBasis.rawValue)
            #expect(job.value(forKey: "payPeriodKind") as? String == expectedPayPeriodKind)
            #expect(job.value(forKey: "createdAt") as? Date == Date(timeIntervalSinceReferenceDate: 800_000))

            let persistedAnchor = job.value(forKey: "payPeriodAnchorDate") as? Date
            if expectsPayPeriodAnchor {
                let anchor = try #require(persistedAnchor)
                #expect(try localDate(from: anchor) == .init(year: 2026, month: 1, day: 5))
                #expect(try isStartOfDay(anchor))
            } else {
                #expect(persistedAnchor == nil)
            }

            let payRates = try fetch(entityName: "PayRateEntity", in: context)
            #expect(payRates.count == 3)
            #expect(
                Set(try payRates.map { try requiredUUID($0, key: "id") }) == [
                    fixture.identifiers.initialPayRate,
                    fixture.identifiers.earlierPayRate,
                    fixture.identifiers.laterPayRate
                ]
            )

            let payRatesByID = Dictionary(
                uniqueKeysWithValues: try payRates.map { payRate in
                    (try requiredUUID(payRate, key: "id"), payRate)
                }
            )
            let initialRate = try #require(payRatesByID[fixture.identifiers.initialPayRate])
            let earlierRate = try #require(payRatesByID[fixture.identifiers.earlierPayRate])
            let laterRate = try #require(payRatesByID[fixture.identifiers.laterPayRate])

            #expect(try decimalAmount(initialRate) == decimal("1234.56"))
            #expect(try decimalAmount(earlierRate) == decimal("1299.875"))
            #expect(try decimalAmount(laterRate) == decimal("1375.125"))
            #expect(initialRate.value(forKey: "effectiveFrom") == nil)

            let earlierEffectiveFrom = try #require(earlierRate.value(forKey: "effectiveFrom") as? Date)
            let laterEffectiveFrom = try #require(laterRate.value(forKey: "effectiveFrom") as? Date)
            #expect(try localDate(from: earlierEffectiveFrom) == .init(year: 2026, month: 3, day: 1))
            #expect(try localDate(from: laterEffectiveFrom) == .init(year: 2026, month: 7, day: 1))
            #expect(try isStartOfDay(earlierEffectiveFrom))
            #expect(try isStartOfDay(laterEffectiveFrom))

            let shifts = try fetch(entityName: "ShiftEntity", in: context)
            #expect(shifts.count == 3)
            #expect(
                Set(try shifts.map { try requiredUUID($0, key: "id") }) == [
                    fixture.identifiers.sameDayShift,
                    fixture.identifiers.shiftWithBreak,
                    fixture.identifiers.overnightShift
                ]
            )

            let shiftsByID = Dictionary(
                uniqueKeysWithValues: try shifts.map { shift in
                    (try requiredUUID(shift, key: "id"), shift)
                }
            )
            let sameDayShift = try #require(shiftsByID[fixture.identifiers.sameDayShift])
            let shiftWithBreak = try #require(shiftsByID[fixture.identifiers.shiftWithBreak])
            let overnightShift = try #require(shiftsByID[fixture.identifiers.overnightShift])
            let sameDayStart = try #require(sameDayShift.value(forKey: "start") as? Date)
            let sameDayEnd = try #require(sameDayShift.value(forKey: "end") as? Date)
            #expect(try localComponents(from: sameDayStart) == .init(year: 2026, month: 9, day: 14, hour: 9, minute: 0))
            #expect(try localComponents(from: sameDayEnd) == .init(year: 2026, month: 9, day: 14, hour: 17, minute: 0))
            #expect(sameDayShift.value(forKey: "unpaidBreakStart") == nil)
            #expect(sameDayShift.value(forKey: "unpaidBreakEnd") == nil)

            let breakStart = try #require(shiftWithBreak.value(forKey: "unpaidBreakStart") as? Date)
            let breakEnd = try #require(shiftWithBreak.value(forKey: "unpaidBreakEnd") as? Date)
            #expect(try localComponents(from: breakStart) == .init(year: 2026, month: 9, day: 15, hour: 12, minute: 0))
            #expect(try localComponents(from: breakEnd) == .init(year: 2026, month: 9, day: 15, hour: 12, minute: 30))

            let overnightStart = try #require(overnightShift.value(forKey: "start") as? Date)
            let overnightEnd = try #require(overnightShift.value(forKey: "end") as? Date)
            #expect(overnightStart < overnightEnd)
            #expect(try localDate(from: overnightStart) == .init(year: 2026, month: 9, day: 16))
            #expect(try localDate(from: overnightEnd) == .init(year: 2026, month: 9, day: 17))

            try verifyRelationship(
                from: job,
                key: "payRates",
                expectedObjects: payRates,
                inverseKey: "job"
            )
            try verifyRelationship(
                from: job,
                key: "shifts",
                expectedObjects: shifts,
                inverseKey: "job"
            )
        }
    }

    private func fetch(
        entityName: String,
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName))
    }

    private func verifyRelationship(
        from parent: NSManagedObject,
        key: String,
        expectedObjects: [NSManagedObject],
        inverseKey: String
    ) throws {
        let relationship = try #require(parent.value(forKey: key) as? NSSet)
        let relatedObjects = try relationship.map { try #require($0 as? NSManagedObject) }

        #expect(Set(relatedObjects.map(\.objectID)) == Set(expectedObjects.map(\.objectID)))
        for object in expectedObjects {
            let inverse = try #require(object.value(forKey: inverseKey) as? NSManagedObject)
            #expect(inverse.objectID == parent.objectID)
        }
    }

    private func requiredUUID(_ object: NSManagedObject, key: String) throws -> UUID {
        try #require(object.value(forKey: key) as? UUID)
    }

    private func decimalAmount(_ object: NSManagedObject) throws -> Decimal {
        try #require(object.value(forKey: "amount") as? NSDecimalNumber).decimalValue
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }

    private func uuid(_ value: String) throws -> UUID {
        try #require(UUID(uuidString: value))
    }

    private func localDate(from date: Date) throws -> LegacyCoreDataStoreFixture.LocalDateValue {
        let components = try localComponents(from: date)
        return .init(year: components.year, month: components.month, day: components.day)
    }

    private func localComponents(from date: Date) throws -> LegacyCoreDataStoreFixture.LocalDateTimeValue {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        return .init(
            year: try #require(components.year),
            month: try #require(components.month),
            day: try #require(components.day),
            hour: try #require(components.hour),
            minute: try #require(components.minute)
        )
    }

    private func isStartOfDay(_ date: Date) throws -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        return calendar.startOfDay(for: date) == date
    }
}
