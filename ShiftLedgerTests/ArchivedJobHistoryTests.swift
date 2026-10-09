import CoreData
import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct ArchivedJobHistoryTests {
    @Test("Archived reads retain exact fractional contributions, scope and SQLite reopen")
    func fractionalHistoryAndReopen() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let a = try fixture.insertJob(index: 1)
        let b = try fixture.insertJob(index: 2, archived: true, name: "  Archive  ")
        let workType = try #require(b.workTypes?.allObjects.first as? WorkTypeEntity)
        let rate = try #require(workType.payRates?.allObjects.first as? PayRateEntity)
        rate.amount = NSDecimalNumber(string: "1.004")
        try insertShift(index: 1, job: b, workType: workType, context: fixture.stack.viewContext)
        try insertShift(index: 2, job: b, workType: workType, context: fixture.stack.viewContext)
        let foreignWorkType = try #require(a.workTypes?.allObjects.first as? WorkTypeEntity)
        try insertShift(index: 3, job: a, workType: foreignWorkType, context: fixture.stack.viewContext)
        try fixture.stack.viewContext.save()
        let before = try ShiftStorage(stack: fixture.stack).loadAll(forJobID: b.id)
        let id = b.id
        let content = try ArchivedJobHistoryAssembly.load(id: id, stack: fixture.stack, locale: Locale(identifier: "en_US"))
        #expect(content.identity.id == id)
        #expect(content.identity.name == "  Archive  ")
        #expect(content.total == Decimal(string: "2.008"))
        #expect(content.totalText == "2.008 EUR")
        #expect(content.rows.map(\.contribution) == [Decimal(string: "1.004"), Decimal(string: "1.004")])
        #expect(content.rows.map(\.id) == before.reversed().map(\.id))
        #expect(content.rows.allSatisfy { $0.detail.contains("1.004 EUR") })
        #expect(!fixture.stack.viewContext.hasChanges)
        #expect(try ShiftStorage(stack: fixture.stack).loadAll(forJobID: b.id) == before)
        fixture.stack.viewContext.reset()
        let coordinator = try #require(fixture.stack.viewContext.persistentStoreCoordinator)
        for store in coordinator.persistentStores { try coordinator.remove(store) }
        let reopened = try await CoreDataStack.load(storeURL: fixture.storeURL)
        #expect(try ArchivedJobHistoryAssembly.load(id: id, stack: reopened, locale: Locale(identifier: "en_US")) == content)
        #expect(!reopened.viewContext.hasChanges)
        let reopenedCoordinator = try #require(reopened.viewContext.persistentStoreCoordinator)
        reopened.viewContext.reset()
        for store in reopenedCoordinator.persistentStores { try reopenedCoordinator.remove(store) }
    }

    @Test("Empty archived history is readable and has no editable UIKit actions", arguments: [false, true])
    func emptyReadOnlyLayout(accessible: Bool) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let job = try fixture.insertJob(index: 2, archived: true, name: "A long archived hospital department with a readable identity")
        let content = try ArchivedJobHistoryAssembly.load(id: job.id, stack: fixture.stack)
        #expect(content.rows.isEmpty)
        #expect(content.total == .zero)
        let controller = ArchivedJobHistoryViewController(content: content)
        controller.traitOverrides.preferredContentSizeCategory = accessible ? .accessibilityExtraExtraLarge : .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }
        let view = try #require(controller.view as? ArchivedJobHistoryView)
        view.tableView.layoutIfNeeded()
        #expect(!view.tableView.allowsSelection)
        #expect(controller.navigationItem.rightBarButtonItem == nil)
        #expect(controller.tableView(view.tableView, titleForFooterInSection: 1) == ArchivedJobHistoryStrings.emptyHistory)
        let identity = try #require(view.tableView.cellForRow(at: IndexPath(row: 0, section: 0)))
        #expect(identity.accessibilityTraits == .staticText)
        #expect(identity.accessibilityValue?.contains(job.id.uuidString) == true)
        #expect(identity.accessibilityCustomActions == nil)
        #expect(!controller.tableView(view.tableView, canEditRowAt: IndexPath(row: 0, section: 0)))
        let configuration = try #require(identity.contentConfiguration as? UIListContentConfiguration)
        #expect(configuration.textProperties.numberOfLines == 0)
        #expect(configuration.secondaryTextProperties.numberOfLines == 0)
        #expect(identity.bounds.height >= 44)
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Fresh identity validation rejects active and missing Jobs without mutation", arguments: [false, true])
    func rejectsUnavailable(missing: Bool) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let job = try fixture.insertJob(index: 2)
        let id = missing ? try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")) : job.id
        do {
            _ = try ArchivedJobHistoryAssembly.load(id: id, stack: fixture.stack)
            Issue.record("Invalid archived identity was accepted")
        } catch let error as ArchivedJobHistoryError {
            switch error {
            case .jobNotFound(let actual): #expect(missing && actual == id)
            case .jobNotArchived(let actual): #expect(!missing && actual == id)
            default: Issue.record("Unexpected archived error: \(error)")
            }
        }
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Corrupted full catalog prevents partial archived history")
    func corruptedCatalog() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let archived = try fixture.insertJob(index: 2, archived: true)
        let invalid = try fixture.insertJob(index: 1)
        invalid.timeZoneIdentifier = "Invalid/Zone"
        try fixture.stack.viewContext.save()
        do {
            _ = try ArchivedJobHistoryAssembly.load(id: archived.id, stack: fixture.stack)
            Issue.record("Corrupt catalog was accepted")
        } catch JobStorageError.corruptedData(.invalidTimeZoneIdentifier(let value)) {
            #expect(value == "Invalid/Zone")
        }
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Hourly archive uses Domain duration, breaks, overnight, DST and historical rates", arguments: ["break", "overnight", "dst", "datedRate"])
    func hourlyHistory(caseName: String) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let job = try fixture.insertJob(index: 2, archived: true)
        let workType = try #require(job.workTypes?.allObjects.first as? WorkTypeEntity)
        workType.basePayKind = "hourly"
        let rate = try #require(workType.payRates?.allObjects.first as? PayRateEntity)
        rate.amount = NSDecimalNumber(value: 10)
        try insertShift(index: 1, job: job, workType: workType, context: fixture.stack.viewContext)
        let shift = try #require(job.shifts?.allObjects.first as? ShiftEntity)
        let parser = ISO8601DateFormatter()
        let startText: String
        let endText: String
        let expected: Decimal
        switch caseName {
        case "break":
            startText = "2026-10-08T08:00:00Z"
            endText = "2026-10-08T10:00:00Z"
            expected = 15
        case "overnight":
            startText = "2026-10-08T21:00:00Z"
            endText = "2026-10-09T01:00:00Z"
            expected = 40
        case "dst":
            startText = "2026-03-29T00:00:00Z"
            endText = "2026-03-29T03:00:00Z"
            expected = 30
        default:
            startText = "2026-10-08T08:00:00Z"
            endText = "2026-10-08T09:00:00Z"
            expected = 20
            let dated = PayRateEntity(entity: try #require(NSEntityDescription.entity(forEntityName: "PayRateEntity", in: fixture.stack.viewContext)), insertInto: fixture.stack.viewContext)
            dated.id = try #require(UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001"))
            dated.amount = NSDecimalNumber(value: 20)
            let effectiveDate: Date = try #require(parser.date(from: "2026-10-07T22:00:00Z"))
            dated.effectiveFrom = effectiveDate
            dated.job = job
            dated.workType = workType
        }
        shift.start = try #require(parser.date(from: startText))
        shift.end = try #require(parser.date(from: endText))
        if caseName == "break" {
            shift.unpaidBreakStart = shift.start.addingTimeInterval(1800)
            shift.unpaidBreakEnd = shift.start.addingTimeInterval(3600)
        }
        try fixture.stack.viewContext.save()
        let content = try ArchivedJobHistoryAssembly.load(id: job.id, stack: fixture.stack, locale: Locale(identifier: "en_US"))
        #expect(content.total == expected)
        #expect(content.rows.count == 1)
        #expect(content.rows.first?.contribution == expected)
        #expect(content.rows.first?.detail.contains(PaycheckResultStrings.rateHour) == true)
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Duplicate identity and corrupted Shift ownership fail without partial content", arguments: ["duplicateJob", "missingJob", "foreignWorkType"])
    func corruptedIdentityAndShift(caseName: String) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let archived = try fixture.insertJob(index: 2, archived: true)
        let active = try fixture.insertJob(index: 1)
        let workType = try #require(archived.workTypes?.allObjects.first as? WorkTypeEntity)
        if caseName == "duplicateJob" {
            active.id = archived.id
        } else {
            try insertShift(index: 1, job: archived, workType: workType, context: fixture.stack.viewContext)
            let shift = try #require(archived.shifts?.allObjects.first as? ShiftEntity)
            if caseName == "missingJob" {
                try fixture.stack.viewContext.save()
                shift.job = nil
            }
            else { shift.workType = try #require(active.workTypes?.allObjects.first as? WorkTypeEntity) }
        }
        if caseName != "missingJob" { try fixture.stack.viewContext.save() }
        let hadChangesBeforeRead = fixture.stack.viewContext.hasChanges
        do {
            _ = try ArchivedJobHistoryAssembly.load(id: archived.id, stack: fixture.stack)
            Issue.record("Corrupted archive graph was accepted")
        } catch JobStorageError.corruptedData(.duplicateJobIdentity(let id)) {
            #expect(caseName == "duplicateJob" && id == archived.id)
        } catch ShiftStorageError.corruptedData(let reason) {
            switch reason {
            case .missingShiftJobRelationship: #expect(caseName == "missingJob")
            case .shiftWorkTypeBelongsToDifferentJob: #expect(caseName == "foreignWorkType")
            default: Issue.record("Unexpected corruption: \(reason)")
            }
        }
        #expect(fixture.stack.viewContext.hasChanges == hadChangesBeforeRead)
    }

    @Test("Launch archive navigation preserves selection and archived-only launch never opens Main", arguments: [false, true])
    func launchNavigation(archivedOnly: Bool) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let active = try fixture.insertJob(index: 1, archived: archivedOnly)
        try fixture.insertJob(index: 2, archived: archivedOnly)
        let archived = try fixture.insertJob(index: 3, archived: true)
        let otherArchived = try fixture.insertJob(index: 4, archived: true)
        let composition = AppFlowComposition(stack: fixture.stack)
        let catalog = try JobStorage(stack: fixture.stack).loadCatalog()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let coordinator = AppCoordinator(window: window, resolveLaunch: {
            AppLaunchResolution(composition: composition, destination: .jobSelection(catalog))
        }, makeNavigationController: { ArchivedHistoryTestNavigationController() })
        defer { coordinator.stop(); window.isHidden = true; window.rootViewController = nil }
        coordinator.start()
        try await waitUntil { (window.rootViewController as? UINavigationController)?.topViewController is JobSelectionViewController }
        let navigation = try #require(window.rootViewController as? UINavigationController)
        let selection = try #require(navigation.topViewController as? JobSelectionViewController)
        selection.onSelectArchivedJob?(archived.id)
        let history = try #require(navigation.topViewController as? ArchivedJobHistoryViewController)
        #expect(history.content.identity.id == archived.id)
        #expect(navigation.viewControllers.count == 2)
        _ = navigation.popViewController(animated: false)
        #expect(navigation.topViewController === selection)
        selection.onSelectArchivedJob?(otherArchived.id)
        #expect((navigation.topViewController as? ArchivedJobHistoryViewController)?.content.identity.id == otherArchived.id)
        _ = navigation.popViewController(animated: false)
        #expect(navigation.topViewController === selection)
        if !archivedOnly {
            selection.onSelectJob?(active.id)
            #expect(navigation.topViewController is OverviewViewController)
        } else {
            coordinator.start()
            #expect(navigation.topViewController === selection)
        }
        #expect(window.rootViewController === navigation)
    }

    @Test("Archived-only list filters active entries and has a truthful empty state")
    func emptyArchivedList() throws {
        let active = JobSelectionItem(
            id: try #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")),
            name: "Active", currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm", isArchived: false
        )
        let controller = ArchivedJobsViewController(items: [active])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }
        let table = try #require(controller.view as? JobSelectionView).tableView
        #expect(table.numberOfRows(inSection: 0) == 0)
        #expect(controller.tableView(table, titleForFooterInSection: 0) == ArchivedJobHistoryStrings.emptyJobs)
        #expect(table.accessibilityIdentifier == "archive.jobs.list")
    }

    @Test("Initial catalog failure and table Retry preserve navigation and truthful content", arguments: ["valid", "failed", "empty", "initialEmpty"])
    func catalogLoadAndRetry(outcome: String) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let active = try fixture.insertJob(index: 1)
        let archived = try fixture.insertJob(index: 2, archived: true)
        let composition = AppFlowComposition(stack: fixture.stack)
        let job = try JobStorage(stack: fixture.stack).load(forJobID: active.id)
        let items = try composition.loadJobSelectionItems()
        let original = composition.makeMainDependencies()
        var attempts = 0
        let dependencies = MainCoordinator.Dependencies(
            loadArchivedJobs: {
                attempts += 1
                if outcome == "initialEmpty" { return [] }
                if attempts == 1 || outcome == "failed" { throw ArchivedHistoryTestError.catalogUnavailable }
                return outcome == "empty" ? [] : items
            },
            makeArchivedJobHistory: original.makeArchivedJobHistory,
            makeOverview: original.makeOverview,
            makeAddShift: original.makeAddShift,
            makeWorkTypes: original.makeWorkTypes,
            makeAddWorkType: original.makeAddWorkType,
            makeRenameWorkType: original.makeRenameWorkType,
            makeChangePayRate: original.makeChangePayRate,
            makePayRateHistory: original.makePayRateHistory,
            makeEditShift: original.makeEditShift,
            makeActualGrossEntry: original.makeActualGrossEntry,
            preparePaycheckComparison: original.preparePaycheckComparison,
            makePaycheckResult: original.makePaycheckResult
        )
        let navigation = ArchivedHistoryTestNavigationController()
        let coordinator = MainCoordinator(navigationController: navigation, job: job, dependencies: dependencies)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        coordinator.start()
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.onArchivedJobs?()
        window.layoutIfNeeded()
        let list = try #require(navigation.topViewController as? ArchivedJobsViewController)
        let table = try #require(list.view as? JobSelectionView).tableView
        table.layoutIfNeeded()
        #expect(attempts == 1)
        #expect(navigation.viewControllers.count == 2)
        #expect(navigation.viewControllers.first === overview)
        #expect(list.presentedViewController == nil)
        if outcome != "initialEmpty" {
            let error = try #require(table.cellForRow(at: IndexPath(row: 0, section: 0)))
            let retry = try #require(table.cellForRow(at: IndexPath(row: 1, section: 0)))
            #expect(error.accessibilityLabel == String(localized: "archive.jobs.loadFailed", table: "Localizable"))
            #expect(error.accessibilityTraits == .staticText)
            #expect(retry.accessibilityLabel == JobSelectionStrings.retry)
            #expect(retry.accessibilityTraits.contains(.button))
            #expect(retry.bounds.height >= 44)
            #expect(table.delegate?.tableView?(table, willSelectRowAt: IndexPath(row: 0, section: 0)) == nil)
            #expect(table.delegate?.tableView?(table, willSelectRowAt: IndexPath(row: 1, section: 0)) == IndexPath(row: 1, section: 0))
            #expect(list.tableView(table, titleForFooterInSection: 0) == nil)
            table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 1, section: 0))
            table.layoutIfNeeded()
            #expect(attempts == 2)
        }
        #expect(navigation.topViewController === list)
        #expect(navigation.viewControllers.count == 2)
        #expect(list.presentedViewController == nil)
        if outcome == "failed" {
            #expect(table.numberOfRows(inSection: 0) == 2)
            #expect(table.cellForRow(at: IndexPath(row: 0, section: 0))?.accessibilityIdentifier == "archive.jobs.loadFailed")
            #expect(table.cellForRow(at: IndexPath(row: 1, section: 0))?.accessibilityTraits.contains(.button) == true)
            #expect(list.tableView(table, titleForFooterInSection: 0) == nil)
        } else if outcome == "valid" {
            #expect(table.numberOfRows(inSection: 0) == 1)
            #expect(table.cellForRow(at: IndexPath(row: 0, section: 0))?.accessibilityIdentifier == "jobSelection.job.\(archived.id.uuidString)")
            #expect(list.tableView(table, titleForFooterInSection: 0) == nil)
            table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 0, section: 0))
            #expect((navigation.topViewController as? ArchivedJobHistoryViewController)?.content.identity.id == archived.id)
            _ = navigation.popViewController(animated: false)
            #expect(navigation.topViewController === list)
        } else {
            #expect(table.numberOfRows(inSection: 0) == 0)
            #expect(list.tableView(table, titleForFooterInSection: 0) == ArchivedJobHistoryStrings.emptyJobs)
        }
        _ = navigation.popViewController(animated: false)
        #expect(navigation.topViewController === overview)
        overview.onAddShift?()
        #expect(navigation.topViewController is AddShiftViewController)
        #expect(!fixture.stack.viewContext.hasChanges)
        #expect(try JobStorage(stack: fixture.stack).load(forJobID: active.id) == job)
    }

    @Test("Archived catalog failure renders truthful inline error state", .serialized, arguments: ["light-large", "dark-xxl"])
    func renderedCatalogFailure(configuration: String) async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let active = try fixture.insertJob(index: 1)
        let composition = AppFlowComposition(stack: fixture.stack)
        let job = try JobStorage(stack: fixture.stack).load(forJobID: active.id)
        let original = composition.makeMainDependencies()
        var attempts = 0
        let dependencies = MainCoordinator.Dependencies(
            loadArchivedJobs: {
                attempts += 1
                throw ArchivedHistoryTestError.catalogUnavailable
            },
            makeArchivedJobHistory: original.makeArchivedJobHistory,
            makeOverview: original.makeOverview,
            makeAddShift: original.makeAddShift,
            makeWorkTypes: original.makeWorkTypes,
            makeAddWorkType: original.makeAddWorkType,
            makeRenameWorkType: original.makeRenameWorkType,
            makeChangePayRate: original.makeChangePayRate,
            makePayRateHistory: original.makePayRateHistory,
            makeEditShift: original.makeEditShift,
            makeActualGrossEntry: original.makeActualGrossEntry,
            preparePaycheckComparison: original.preparePaycheckComparison,
            makePaycheckResult: original.makePaycheckResult
        )
        let isDark = configuration == "dark-xxl"
        let contentSizeCategory: UIContentSizeCategory = isDark ? .accessibilityExtraExtraLarge : .large
        let navigation = ArchivedHistoryTestNavigationController()
        navigation.overrideUserInterfaceStyle = isDark ? .dark : .light
        navigation.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        let coordinator = MainCoordinator(navigationController: navigation, job: job, dependencies: dependencies)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.overrideUserInterfaceStyle = isDark ? .dark : .light
        window.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }

        coordinator.start()
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.onArchivedJobs?()
        window.layoutIfNeeded()

        let list = try #require(navigation.topViewController as? ArchivedJobsViewController)
        list.overrideUserInterfaceStyle = isDark ? .dark : .light
        list.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        window.layoutIfNeeded()
        let table = try #require(list.view as? JobSelectionView).tableView
        table.layoutIfNeeded()
        let error = try #require(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let retry = try #require(table.cellForRow(at: IndexPath(row: 1, section: 0)))
        #expect(attempts == 1)
        #expect(navigation.viewControllers.count == 2)
        #expect(navigation.viewControllers.first === overview)
        #expect(list.presentedViewController == nil)
        #expect(table.numberOfRows(inSection: 0) == 2)
        #expect(error.accessibilityLabel == String(localized: "archive.jobs.loadFailed", table: "Localizable"))
        #expect(retry.accessibilityLabel == JobSelectionStrings.retry)
        #expect(retry.accessibilityTraits.contains(.button))
        #expect(retry.bounds.height >= 44)
        #expect(list.tableView(table, titleForFooterInSection: 0) == nil)
        #expect(list.traitCollection.userInterfaceStyle == (isDark ? .dark : .light))
        #expect(list.traitCollection.preferredContentSizeCategory == contentSizeCategory)

        let renderer = UIGraphicsImageRenderer(bounds: navigation.view.bounds)
        var renderedImage: UIImage?
        list.traitCollection.performAsCurrent {
            renderedImage = renderer.image { context in
                UIColor.systemBackground.resolvedColor(with: list.traitCollection).setFill()
                context.fill(navigation.view.bounds)
                navigation.view.drawHierarchy(in: navigation.view.bounds, afterScreenUpdates: true)
            }
        }
        let image = try #require(renderedImage)
        let pngData = try #require(image.pngData())
        let filename = isDark ? "SL494-error-dark-xxl.png" : "SL494-error-light-large.png"
        Attachment<[UInt8]>.record(Array(pngData), named: filename)
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Unloaded construction is not a successful empty catalog")
    func unloadedArchivedList() throws {
        let controller = ArchivedJobsViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }
        let table = try #require(controller.view as? JobSelectionView).tableView
        #expect(table.numberOfRows(inSection: 0) == 0)
        #expect(controller.tableView(table, titleForFooterInSection: 0) == nil)
    }

    @Test("Stale archived selection retains the list and recovers after persisted identity is restored")
    func staleArchiveSelectionRecovers() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let active = try fixture.insertJob(index: 1)
        let archived = try fixture.insertJob(index: 2, archived: true)
        let composition = AppFlowComposition(stack: fixture.stack)
        let job = try JobStorage(stack: fixture.stack).load(forJobID: active.id)
        let navigation = ArchivedHistoryTestNavigationController()
        let coordinator = MainCoordinator(navigationController: navigation, job: job, dependencies: composition.makeMainDependencies())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        coordinator.start()
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.onArchivedJobs?()
        let list = try #require(navigation.topViewController as? ArchivedJobsViewController)
        archived.isArchived = false
        try fixture.stack.viewContext.save()
        list.onSelectJob?(archived.id)
        #expect(navigation.topViewController === list)
        #expect(navigation.viewControllers.count == 2)
        let alert = try #require(list.presentedViewController as? UIAlertController)
        #expect(alert.title == ArchivedJobHistoryStrings.errorTitle)
        #expect(!fixture.stack.viewContext.hasChanges)
        list.dismiss(animated: false)
        try await waitUntil { list.presentedViewController == nil }
        archived.isArchived = true
        try fixture.stack.viewContext.save()
        list.onReload?()
        list.onSelectJob?(archived.id)
        #expect((navigation.topViewController as? ArchivedJobHistoryViewController)?.content.identity.id == archived.id)
        #expect(navigation.viewControllers.first === overview)
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    @Test("Overview archive Back keeps original Overview and active identity")
    func overviewNavigation() async throws {
        let fixture = try await JobSelectionTestStore.make()
        defer { close(fixture) }
        let active = try fixture.insertJob(index: 1)
        let archived = try fixture.insertJob(index: 2, archived: true)
        let composition = AppFlowComposition(stack: fixture.stack)
        let job = try JobStorage(stack: fixture.stack).load(forJobID: active.id)
        let navigation = ArchivedHistoryTestNavigationController()
        let coordinator = MainCoordinator(navigationController: navigation, job: job, dependencies: composition.makeMainDependencies())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        coordinator.start()
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.onArchivedJobs?()
        let list = try #require(navigation.topViewController as? ArchivedJobsViewController)
        list.onSelectJob?(archived.id)
        #expect((navigation.topViewController as? ArchivedJobHistoryViewController)?.content.identity.id == archived.id)
        _ = navigation.popViewController(animated: false)
        #expect(navigation.topViewController === list)
        _ = navigation.popViewController(animated: false)
        #expect(navigation.topViewController === overview)
        overview.onAddShift?()
        #expect(navigation.topViewController is AddShiftViewController)
        #expect(!fixture.stack.viewContext.hasChanges)
    }

    private func insertShift(index: Int, job: JobEntity, workType: WorkTypeEntity, context: NSManagedObjectContext) throws {
        let entity = ShiftEntity(entity: try #require(NSEntityDescription.entity(forEntityName: "ShiftEntity", in: context)), insertInto: context)
        entity.id = try #require(UUID(uuidString: String(format: "%08d-0000-0000-0000-000000000003", index)))
        entity.start = Date(timeIntervalSince1970: 1_791_446_400 + Double(index == 2 ? 86_400 : 0))
        entity.end = entity.start.addingTimeInterval(3_600)
        entity.job = job
        entity.workType = workType
    }

    private func close(_ fixture: JobSelectionTestStore) {
        do { try fixture.close() } catch { Issue.record("Fixture cleanup failed: \(error)") }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        throw ArchivedHistoryTestError.timedOut
    }
}

private enum ArchivedHistoryTestError: Error { case timedOut, catalogUnavailable }

@MainActor
private final class ArchivedHistoryTestNavigationController: UINavigationController {
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: false)
    }
    override func popViewController(animated: Bool) -> UIViewController? {
        super.popViewController(animated: false)
    }
}
