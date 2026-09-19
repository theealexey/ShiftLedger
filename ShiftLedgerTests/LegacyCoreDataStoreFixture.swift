import CoreData
import Foundation

enum LegacyCoreDataStoreFixtureError: Error {
    case legacyModelPackageMissing
    case legacyModelVersionMissing(URL)
    case legacyModelCannotBeLoaded(URL)
    case legacyModelSchemaChanged(actualEntityHashes: [String: String])
    case missingEntityDescription(String)
    case invalidUUID(String)
    case invalidDecimal(String)
    case invalidTimeZoneIdentifier(String)
    case invalidLocalDateTime(LegacyCoreDataStoreFixture.LocalDateTimeValue)
    case storeWasNotCreated(URL)
    case operationAndStoreRemovalFailed(operation: Error, removal: Error)
    case fixtureCreationAndCleanupFailed(operation: Error, cleanup: Error)
}

enum LegacyCoreDataStoreFixture {
    enum PayBasis: String, Sendable {
        case hourly
        case fixedPerShift
    }

    enum PayPeriod: Sendable {
        case weekly
        case perShift
    }

    struct LocalDateValue: Equatable, Sendable {
        let year: Int
        let month: Int
        let day: Int
    }

    struct LocalDateTimeValue: Equatable, Sendable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
    }

    struct Identifiers: Equatable, Sendable {
        let job: UUID
        let initialPayRate: UUID
        let earlierPayRate: UUID
        let laterPayRate: UUID
        let sameDayShift: UUID
        let shiftWithBreak: UUID
        let overnightShift: UUID
    }

    struct Store: Sendable {
        let storeURL: URL
        let identifiers: Identifiers

        private let directoryURL: URL

        fileprivate init(
            storeURL: URL,
            identifiers: Identifiers,
            directoryURL: URL
        ) {
            self.storeURL = storeURL
            self.identifiers = identifiers
            self.directoryURL = directoryURL
        }

        func inspect<T: Sendable>(
            _ operation: @Sendable (NSManagedObjectContext) throws -> T
        ) throws -> T {
            try LegacyCoreDataStoreFixture.withLegacyContext(
                storeURL: storeURL,
                operation: operation
            )
        }

        func remove() throws {
            guard FileManager.default.fileExists(atPath: directoryURL.path) else {
                return
            }

            try FileManager.default.removeItem(at: directoryURL)
        }
    }

    private static let modelPackageName = "ShiftLedger"
    private static let legacyModelVersionName = "ShiftLedger"
    private static let timeZoneIdentifier = "Europe/Stockholm"
    private static let expectedEntityHashes = [
        "JobEntity": "0c1262d7492ef8bba7188596ba6bc8d226ec31d9efc8cfe5c7150ff0c0f0bd27",
        "PayRateEntity": "a9160c720163eb95cd82b61c930f435ed9a3795d6bb77145a48ca259b791f008",
        "ShiftEntity": "5117dfd88a3e484be99bb4848934871b809e3e9626de6e77897abaab3caabafe"
    ]

    static func loadLegacyModel(bundle: Bundle = .main) throws -> NSManagedObjectModel {
        guard let packageURL = bundle.url(
            forResource: modelPackageName,
            withExtension: "momd"
        ) else {
            throw LegacyCoreDataStoreFixtureError.legacyModelPackageMissing
        }

        let modelURL = packageURL
            .appendingPathComponent(legacyModelVersionName)
            .appendingPathExtension("mom")
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LegacyCoreDataStoreFixtureError.legacyModelVersionMissing(modelURL)
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw LegacyCoreDataStoreFixtureError.legacyModelCannotBeLoaded(modelURL)
        }

        let actualEntityHashes = Dictionary(
            uniqueKeysWithValues: model.entities.compactMap { entity in
                entity.name.map { name in
                    (name, hexadecimalString(for: entity.versionHash))
                }
            }
        )
        guard actualEntityHashes == expectedEntityHashes else {
            throw LegacyCoreDataStoreFixtureError.legacyModelSchemaChanged(
                actualEntityHashes: actualEntityHashes
            )
        }

        return model
    }

    static func make(
        payBasis: PayBasis,
        payPeriod: PayPeriod
    ) throws -> Store {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerLegacyV1Fixtures", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let storeURL = directoryURL.appendingPathComponent("ShiftLedger.sqlite")
        let identifiers = try makeIdentifiers()

        do {
            try withLegacyContext(storeURL: storeURL) { context in
                try insertFixtureData(
                    payBasis: payBasis,
                    payPeriod: payPeriod,
                    identifiers: identifiers,
                    into: context
                )
                try context.save()
            }
        } catch {
            let operationError = error
            do {
                try FileManager.default.removeItem(at: directoryURL)
            } catch {
                throw LegacyCoreDataStoreFixtureError.fixtureCreationAndCleanupFailed(
                    operation: operationError,
                    cleanup: error
                )
            }
            throw operationError
        }

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw LegacyCoreDataStoreFixtureError.storeWasNotCreated(storeURL)
        }

        return Store(
            storeURL: storeURL,
            identifiers: identifiers,
            directoryURL: directoryURL
        )
    }

    private static func withLegacyContext<T: Sendable>(
        storeURL: URL,
        operation: @Sendable (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let model = try loadLegacyModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let persistentStore = try coordinator.addPersistentStore(
            type: .sqlite,
            configuration: nil,
            at: storeURL,
            options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let operationResult: Result<T, Error>
        do {
            operationResult = .success(
                try context.performAndWait {
                    try operation(context)
                }
            )
        } catch {
            operationResult = .failure(error)
        }

        context.performAndWait {
            context.reset()
        }

        do {
            try coordinator.remove(persistentStore)
        } catch {
            switch operationResult {
            case .success:
                throw error
            case let .failure(operationError):
                throw LegacyCoreDataStoreFixtureError.operationAndStoreRemovalFailed(
                    operation: operationError,
                    removal: error
                )
            }
        }

        return try operationResult.get()
    }

    private static func insertFixtureData(
        payBasis: PayBasis,
        payPeriod: PayPeriod,
        identifiers: Identifiers,
        into context: NSManagedObjectContext
    ) throws {
        let job = try insertJob(
            id: identifiers.job,
            payBasis: payBasis,
            payPeriod: payPeriod,
            into: context
        )

        try insertPayRate(
            id: identifiers.laterPayRate,
            amount: "1375.125",
            effectiveFrom: .init(year: 2026, month: 7, day: 1),
            job: job,
            into: context
        )
        try insertPayRate(
            id: identifiers.initialPayRate,
            amount: "1234.56",
            effectiveFrom: nil,
            job: job,
            into: context
        )
        try insertPayRate(
            id: identifiers.earlierPayRate,
            amount: "1299.875",
            effectiveFrom: .init(year: 2026, month: 3, day: 1),
            job: job,
            into: context
        )

        try insertShift(
            id: identifiers.sameDayShift,
            start: .init(year: 2026, month: 9, day: 14, hour: 9, minute: 0),
            end: .init(year: 2026, month: 9, day: 14, hour: 17, minute: 0),
            unpaidBreakStart: nil,
            unpaidBreakEnd: nil,
            job: job,
            into: context
        )
        try insertShift(
            id: identifiers.shiftWithBreak,
            start: .init(year: 2026, month: 9, day: 15, hour: 8, minute: 30),
            end: .init(year: 2026, month: 9, day: 15, hour: 17, minute: 0),
            unpaidBreakStart: .init(year: 2026, month: 9, day: 15, hour: 12, minute: 0),
            unpaidBreakEnd: .init(year: 2026, month: 9, day: 15, hour: 12, minute: 30),
            job: job,
            into: context
        )
        try insertShift(
            id: identifiers.overnightShift,
            start: .init(year: 2026, month: 9, day: 16, hour: 22, minute: 0),
            end: .init(year: 2026, month: 9, day: 17, hour: 6, minute: 0),
            unpaidBreakStart: nil,
            unpaidBreakEnd: nil,
            job: job,
            into: context
        )
    }

    private static func insertJob(
        id: UUID,
        payBasis: PayBasis,
        payPeriod: PayPeriod,
        into context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        let entity = try entityDescription(named: "JobEntity", in: context)
        let job = NSManagedObject(entity: entity, insertInto: context)
        job.setValue(id, forKey: "id")
        job.setValue("SEK", forKey: "currencyCode")
        job.setValue(timeZoneIdentifier, forKey: "timeZoneIdentifier")
        job.setValue(payBasis.rawValue, forKey: "basePayKind")
        job.setValue(Date(timeIntervalSinceReferenceDate: 800_000), forKey: "createdAt")

        switch payPeriod {
        case .weekly:
            job.setValue("weekly", forKey: "payPeriodKind")
            job.setValue(
                try startOfDay(.init(year: 2026, month: 1, day: 5)),
                forKey: "payPeriodAnchorDate"
            )
        case .perShift:
            job.setValue("perShift", forKey: "payPeriodKind")
            job.setValue(nil, forKey: "payPeriodAnchorDate")
        }

        return job
    }

    private static func insertPayRate(
        id: UUID,
        amount: String,
        effectiveFrom: LocalDateValue?,
        job: NSManagedObject,
        into context: NSManagedObjectContext
    ) throws {
        let entity = try entityDescription(named: "PayRateEntity", in: context)
        let payRate = NSManagedObject(entity: entity, insertInto: context)
        payRate.setValue(id, forKey: "id")
        payRate.setValue(NSDecimalNumber(decimal: try decimal(amount)), forKey: "amount")
        payRate.setValue(try effectiveFrom.map(startOfDay), forKey: "effectiveFrom")
        payRate.setValue(job, forKey: "job")
    }

    private static func insertShift(
        id: UUID,
        start: LocalDateTimeValue,
        end: LocalDateTimeValue,
        unpaidBreakStart: LocalDateTimeValue?,
        unpaidBreakEnd: LocalDateTimeValue?,
        job: NSManagedObject,
        into context: NSManagedObjectContext
    ) throws {
        let entity = try entityDescription(named: "ShiftEntity", in: context)
        let shift = NSManagedObject(entity: entity, insertInto: context)
        shift.setValue(id, forKey: "id")
        shift.setValue(try date(from: start), forKey: "start")
        shift.setValue(try date(from: end), forKey: "end")
        shift.setValue(try unpaidBreakStart.map(date), forKey: "unpaidBreakStart")
        shift.setValue(try unpaidBreakEnd.map(date), forKey: "unpaidBreakEnd")
        shift.setValue(job, forKey: "job")
    }

    private static func entityDescription(
        named name: String,
        in context: NSManagedObjectContext
    ) throws -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            throw LegacyCoreDataStoreFixtureError.missingEntityDescription(name)
        }
        return entity
    }

    private static func uuid(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw LegacyCoreDataStoreFixtureError.invalidUUID(value)
        }
        return id
    }

    private static func makeIdentifiers() throws -> Identifiers {
        try Identifiers(
            job: uuid("10000000-0000-0000-0000-000000000001"),
            initialPayRate: uuid("20000000-0000-0000-0000-000000000001"),
            earlierPayRate: uuid("20000000-0000-0000-0000-000000000002"),
            laterPayRate: uuid("20000000-0000-0000-0000-000000000003"),
            sameDayShift: uuid("30000000-0000-0000-0000-000000000001"),
            shiftWithBreak: uuid("30000000-0000-0000-0000-000000000002"),
            overnightShift: uuid("30000000-0000-0000-0000-000000000003")
        )
    }

    private static func decimal(_ value: String) throws -> Decimal {
        guard let decimal = Decimal(
            string: value,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw LegacyCoreDataStoreFixtureError.invalidDecimal(value)
        }
        return decimal
    }

    private static func startOfDay(_ localDate: LocalDateValue) throws -> Date {
        let value = LocalDateTimeValue(
            year: localDate.year,
            month: localDate.month,
            day: localDate.day,
            hour: 0,
            minute: 0
        )
        let resolvedDate = try date(from: value)
        let calendar = try gregorianCalendar()
        guard calendar.startOfDay(for: resolvedDate) == resolvedDate else {
            throw LegacyCoreDataStoreFixtureError.invalidLocalDateTime(value)
        }
        return resolvedDate
    }

    private static func date(from value: LocalDateTimeValue) throws -> Date {
        let calendar = try gregorianCalendar()
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: value.year,
            month: value.month,
            day: value.day,
            hour: value.hour,
            minute: value.minute
        )
        guard let date = calendar.date(from: components) else {
            throw LegacyCoreDataStoreFixtureError.invalidLocalDateTime(value)
        }

        let resolved = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        guard
            resolved.year == value.year,
            resolved.month == value.month,
            resolved.day == value.day,
            resolved.hour == value.hour,
            resolved.minute == value.minute
        else {
            throw LegacyCoreDataStoreFixtureError.invalidLocalDateTime(value)
        }

        return date
    }

    private static func gregorianCalendar() throws -> Calendar {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw LegacyCoreDataStoreFixtureError.invalidTimeZoneIdentifier(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func hexadecimalString(for data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
