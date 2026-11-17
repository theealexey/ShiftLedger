import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct MainCoordinatorTests {
    @Test("Selected payroll context is displayed through comparison, correction and return",
          arguments: ["ru_RU", "en_US"], ["sameDay", "overnight", "monthly", "weekly", "biweekly"])
    func selectedPeriodContext(_ localeID: String, _ kind: String) throws {
        let locale = Locale(identifier: localeID)
        let anchor = try LocalDate(year: 2001, month: 1, day: 1)
        let cycle: PayCalculationCycle = switch kind {
        case "monthly": .scheduled(.calendarMonthly)
        case "weekly": .scheduled(.weekly(anchorDate: anchor))
        case "biweekly": .scheduled(.biweekly(anchorDate: anchor))
        default: .perShift
        }
        let harness = try makeHarness(cycle: cycle, displayLocale: locale)
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let shift = try Shift(jobID: testWorkTypeID, workTypeID: testWorkTypeID,
            start: start, end: start.addingTimeInterval(kind == "overnight" ? 72_000 : 3_600))
        if kind == "sameDay" || kind == "overnight" { harness.metrics.overviewShifts = [shift] }
        harness.coordinator.start()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        window.rootViewController = harness.coordinator.tabBarController
        window.isHidden = false
        defer { window.isHidden = true }
        harness.overview.loadViewIfNeeded()
        var period: PayCalculationPeriod?
        let original = harness.overview.onCheckPaycheck
        harness.overview.onCheckPaycheck = { selected in period = selected; original?(selected) }
        let check: UIButton = try requireView("overview.checkPaycheck", in: harness.overview.view)
        check.sendActions(for: .touchUpInside)
        let selected = try #require(period)
        let heading = try #require(harness.overview.paycheckPeriodHeading(for: selected))
        let text = [heading.date, heading.time].compactMap { $0 }.joined(separator: "\n")
        #expect(text.contains(kind == "sameDay" || kind == "overnight" ? "2026" : "2001"))
        let entry = try #require(harness.navigationController.topViewController as? ActualGrossEntryViewController)
        entry.loadViewIfNeeded()
        let entryLabel: UILabel = try requireView("actualGrossEntry.period", in: entry.view)
        #expect(entryLabel.text == text && !entryLabel.isHidden)
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
            entry.traitOverrides.preferredContentSizeCategory = category
            window.layoutIfNeeded()
            entry.view.layoutIfNeeded()
            #expect(entryLabel.sizeThatFits(CGSize(width: entryLabel.bounds.width, height: .greatestFiniteMagnitude)).height <= entryLabel.bounds.height + 1)
            let amount: UIView = try requireView("actualGrossEntry.amount.container", in: entry.view)
            #expect(entryLabel.convert(entryLabel.bounds, to: entry.view).maxY <= amount.convert(amount.bounds, to: entry.view).minY)
        }
        let field: UITextField = try requireView("actualGrossEntry.amount.input", in: entry.view)
        for amount in ["100", "101"] {
            field.text = amount
            field.sendActions(for: .editingChanged)
            let compare: UIButton = try requireView("actualGrossEntry.compare", in: entry.view)
            compare.sendActions(for: .touchUpInside)
            let result = try #require(harness.navigationController.topViewController as? PaycheckResultViewController)
            result.loadViewIfNeeded()
            let resultLabel: UILabel = try requireView("paycheckResult.period", in: result.view)
            #expect(resultLabel.text == text)
            #expect(harness.metrics.preparedPeriods.last == selected)
            for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
                result.traitOverrides.preferredContentSizeCategory = category
                window.layoutIfNeeded()
                result.view.layoutIfNeeded()
                #expect(resultLabel.sizeThatFits(CGSize(width: resultLabel.bounds.width, height: .greatestFiniteMagnitude)).height <= resultLabel.bounds.height + 1)
            }
            if amount == "100" {
                _ = harness.navigationController.popViewController(animated: false)
                #expect(entryLabel.text == text && field.text == amount)
            } else { result.onDone?() }
        }
        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.overview.paycheckPeriodHeading(for: selected)?.date == heading.date)
    }

    @Test("Main flow installs one stable Overview root")
    func startsWithOneOverviewRoot() throws {
        let harness = try makeHarness()

        harness.coordinator.start()

        #expect(harness.navigationController.viewControllers.count == 1)
        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.isNavigationBarHidden == false)
    }

    @Test("Tabs retain distinct roots, Home actions and all saved shifts")
    func tabRootsAndShiftNavigation() throws {
        let harness = try makeHarness(cycle: .perShift)
        let first = try makeShift()
        let second = try Shift(id: UUID(), jobID: first.jobID, workTypeID: first.workTypeID,
                               start: first.start.addingTimeInterval(86_400),
                               end: first.end.addingTimeInterval(86_400))
        harness.metrics.overviewShifts = [first, second]
        harness.coordinator.start()
        let tabs = harness.coordinator.tabBarController
        let stacks = try #require(tabs.viewControllers as? [UINavigationController])
        #expect(stacks.map { $0.tabBarItem.accessibilityIdentifier } == ["tabs.home", "tabs.shifts", "tabs.archive", "tabs.settings"])
        #expect(Set(stacks.map(ObjectIdentifier.init)).count == 4)
        #expect(tabs.selectedViewController === harness.navigationController)
        #expect(stacks.map { $0.viewControllers.count } == [1, 1, 1, 1])
        #expect(stacks[2].topViewController is ArchivedJobsViewController)
        #expect(stacks[3].topViewController is SettingsViewController)
        let home = harness.overview
        home.loadViewIfNeeded()
        #expect(home.navigationItem.rightBarButtonItem == nil)
        for id in ["overview.checkPaycheck", "overview.addShift"] {
            let button: UIButton = try requireView(id, in: home.view)
            #expect(!button.isHidden && button.isEnabled)
        }
        tabs.selectedIndex = 1
        let shifts = try #require(stacks[1].topViewController as? OverviewViewController)
        shifts.loadViewIfNeeded()
        for shift in [first, second] {
            let _: UIView = try requireView("overview.shift.\(shift.id.uuidString)", in: shifts.view)
        }
        shifts.onEditShift?(second)
        let editor = try #require(stacks[1].topViewController as? EditShiftViewController)
        #expect(harness.metrics.editedShifts.last?.id == second.id)
        tabs.selectedIndex = 0
        tabs.selectedIndex = 1
        harness.coordinator.start()
        #expect(stacks[1].topViewController === editor)
        _ = stacks[1].popViewController(animated: false)
        #expect(stacks[1].topViewController === shifts)
        #expect(stacks[0].topViewController === home)
    }

    @Test("Add Shift completion reloads the persisted saved ID and returns to the same Overview")
    func addShiftCompletionReturnsToSameOverview() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()

        harness.overview.onAddShift?()
        let addShift = try #require(
            harness.navigationController.topViewController as? AddShiftViewController
        )
        let callbackShift = try makeShift()
        harness.metrics.overviewShifts = [callbackShift]
        addShift.onSaved?(callbackShift)

        #expect(harness.metrics.overviewLoadCount == 2)
        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.viewControllers.count == 1)
        let card: UIView = try requireView(
            "overview.shift.\(callbackShift.id.uuidString)",
            in: harness.overview.view
        )
        #expect(card.accessibilityTraits.contains(.selected))
    }

    @Test("Actual Gross uses the comparison dependency and opens Result")
    func actualGrossPushesResultUsingPreparedComparison() throws {
        let harness = try makeHarness()
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        let actualGross = try ActualGross(amount: 75)
        entry.onContinue?(actualGross)

        #expect(harness.metrics.preparedPeriods == [period])
        #expect(harness.metrics.preparedActualGrosses == [actualGross])
        #expect(harness.navigationController.topViewController is PaycheckResultViewController)
    }

    @Test("Paycheck Result Done returns to the stable Overview root")
    func resultDoneReturnsToSameOverview() throws {
        let harness = try makeHarness()
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        entry.onContinue?(try ActualGross(amount: 75))
        let result = try #require(
            harness.navigationController.topViewController as? PaycheckResultViewController
        )
        result.onDone?()

        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.viewControllers.count == 1)
    }

    @Test("Native Back pops child screens without route-history repair")
    func nativeBackUsesTheNavigationControllerStack() throws {
        let harness = try makeHarness()
        harness.coordinator.start()

        harness.overview.onAddShift?()
        #expect(harness.navigationController.topViewController is AddShiftViewController)
        _ = harness.navigationController.popViewController(animated: false)
        #expect(harness.navigationController.topViewController === harness.overview)

        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(
            settingsStack.topViewController as? WorkTypesViewController
        )
        workTypes.onAddWorkType?()
        #expect(settingsStack.topViewController is AddWorkTypeViewController)
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === workTypes)
        let selected = try #require(harness.job.workTypes.first)
        workTypes.onRenameWorkType?(selected)
        #expect(settingsStack.topViewController is RenameWorkTypeViewController)
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === workTypes)
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === settings)

        let period = try harness.job.payCalculationPeriod(for: makeShift())
        harness.overview.onCheckPaycheck?(period)
        #expect(harness.navigationController.topViewController is ActualGrossEntryViewController)
        _ = harness.navigationController.popViewController(animated: false)
        #expect(harness.navigationController.topViewController === harness.overview)
    }

    @Test("Rename Work Type returns to the same list and passes updated Job to subsequent flows")
    func renameWorkTypeUpdatesCurrentJob() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(settingsStack.topViewController as? WorkTypesViewController)
        workTypes.loadViewIfNeeded()
        let selected = try #require(harness.job.workTypes.first)
        workTypes.onRenameWorkType?(selected)
        let rename = try #require(settingsStack.topViewController as? RenameWorkTypeViewController)
        #expect(harness.metrics.renameInputs == [selected])
        #expect(harness.metrics.renameJobs == [harness.job])
        let updatedJob = try harness.job.renamingWorkType(id: selected.id, to: "Senior Lectures")
        rename.onSaved?(updatedJob)

        #expect(settingsStack.topViewController === workTypes)
        #expect(settingsStack.viewControllers.count == 2)
        #expect(settingsStack.viewControllers[0] === settings)
        let renamedCell = workTypes.tableView(workTypes.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        #expect((renamedCell.contentConfiguration as? UIListContentConfiguration)?.text == "Senior Lectures")
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === settings)
        harness.overview.onAddShift?()
        #expect(harness.metrics.addShiftJobs.last == updatedJob)
        _ = harness.navigationController.popViewController(animated: false)
        harness.overview.onEditShift?(try makeShift())
        #expect(harness.metrics.editShiftJobs.last == updatedJob)
        _ = harness.navigationController.popViewController(animated: false)
        settings.onManageWorkTypes?()
        #expect(harness.metrics.workTypesInputs.last == updatedJob.workTypes)
        #expect(harness.metrics.workTypesJobs.last == updatedJob)
    }

    @Test("Archiving WorkType keeps Work Types open and updates the Job for subsequent Add Shift")
    func archiveWorkTypeUpdatesCurrentJobWithoutNavigation() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(settingsStack.topViewController as? WorkTypesViewController)
        workTypes.loadViewIfNeeded()
        let selected = try #require(harness.job.workTypes.first)

        workTypes.archive(selected)

        #expect(settingsStack.topViewController === workTypes)
        #expect(settingsStack.viewControllers.first === settings)
        #expect(workTypes.tableView(workTypes.tableView, titleForHeaderInSection: 0) == WorkTypesStrings.archivedSection)
        #expect(harness.metrics.overviewLoadCount == 2)
        _ = settingsStack.popViewController(animated: false)
        harness.overview.onAddShift?()
        #expect(harness.metrics.addShiftJobs.last?.workTypes.first?.isArchived == true)
        let addShift = try #require(harness.navigationController.topViewController as? AddShiftViewController)
        let row: UIControl = try requireView("addShift.workType", in: addShift.view)
        #expect(row.accessibilityValue == AddShiftStrings.noActiveWorkTypes)
    }

    @Test("Change Pay Rate uses current Job and returns to the same Work Types and Overview")
    func changePayRateUpdatesCurrentJob() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(
            settingsStack.topViewController as? WorkTypesViewController
        )
        let selected = try #require(harness.job.workTypes.first)
        workTypes.onChangePayRate?(selected)
        _ = try #require(
            settingsStack.topViewController as? ChangePayRateViewController
        )
        #expect(harness.metrics.changePayRateInputs == [selected])
        #expect(harness.metrics.changePayRateJobs == [harness.job])
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === workTypes)

        workTypes.onChangePayRate?(selected)
        let saving = try #require(
            settingsStack.topViewController as? ChangePayRateViewController
        )
        let added = try PayRate(
            id: UUID(uuid: (0x78, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            amount: 175,
            effectiveFrom: LocalDate(year: 2026, month: 9, day: 1)
        )
        let updated = try harness.job.addingPayRate(
            added, toWorkTypeID: selected.id,
            preservingHistoricalPayrollFor: [], asOf: Date(timeIntervalSinceReferenceDate: 0)
        )
        saving.onSaved?(updated)
        #expect(settingsStack.topViewController === workTypes)
        #expect(settingsStack.viewControllers.count == 2)
        #expect(settingsStack.viewControllers[0] === settings)
        _ = settingsStack.popViewController(animated: false)
        harness.overview.onAddShift?()
        #expect(harness.metrics.addShiftJobs.last == updated)
        _ = harness.navigationController.popViewController(animated: false)
        harness.overview.onEditShift?(try makeShift())
        #expect(harness.metrics.editShiftJobs.last == updated)
        _ = harness.navigationController.popViewController(animated: false)
        settings.onManageWorkTypes?()
        #expect(harness.metrics.workTypesInputs.last == updated.workTypes)
        let reopened = try #require(
            settingsStack.topViewController as? WorkTypesViewController
        )
        reopened.onChangePayRate?(try #require(updated.workType(id: selected.id)))
        #expect(harness.metrics.changePayRateJobs.last == updated)
        _ = settingsStack.popViewController(animated: false)
        let currentWorkType = try #require(updated.workType(id: selected.id))
        reopened.onPayRateHistory?(currentWorkType)
        #expect(harness.metrics.payRateHistoryJobs.last == updated)
        #expect(harness.metrics.payRateHistoryInputs.last == currentWorkType)
    }

    @Test("Pay Rate History uses the selected current WorkType and native Back returns to Work Types")
    func payRateHistoryUsesCurrentWorkType() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(
            settingsStack.topViewController as? WorkTypesViewController
        )
        let selected = try #require(harness.job.workTypes.first)

        workTypes.onPayRateHistory?(selected)

        let history = try #require(
            settingsStack.topViewController as? PayRateHistoryViewController
        )
        #expect(harness.metrics.payRateHistoryJobs == [harness.job])
        #expect(harness.metrics.payRateHistoryInputs == [selected])
        #expect(settingsStack.viewControllers.count == 3)
        #expect(settingsStack.viewControllers[1] === workTypes)
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === workTypes)
        #expect(history.presentedViewController == nil)
    }

    @Test("Add Work Type обновляет Job и тот же Work Types, затем передаёт aggregate в Add и Edit Shift")
    func addWorkTypeCompletionUpdatesCurrentJob() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()

        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        settings.onManageWorkTypes?()
        let workTypes = try #require(
            settingsStack.topViewController as? WorkTypesViewController
        )
        #expect(workTypes.tableView(workTypes.tableView, numberOfRowsInSection: 0) == 1)
        workTypes.onAddWorkType?()
        let addWorkType = try #require(
            settingsStack.topViewController as? AddWorkTypeViewController
        )
        let updatedJob = try makeUpdatedJob(from: harness.job)
        addWorkType.onSaved?(updatedJob)

        #expect(settingsStack.topViewController === workTypes)
        #expect(settingsStack.viewControllers.count == 2)
        #expect(settingsStack.viewControllers[0] === settings)
        #expect(workTypes.tableView(workTypes.tableView, numberOfRowsInSection: 0) == 2)
        #expect(harness.metrics.workTypesInputs == [harness.job.workTypes])
        _ = settingsStack.popViewController(animated: false)
        #expect(settingsStack.topViewController === settings)
        harness.overview.onAddShift?()
        let suppliedJob = try #require(harness.metrics.addShiftJobs.last)
        #expect(suppliedJob == updatedJob)
        #expect(suppliedJob.workTypes.count == 2)

        let existingShift = try makeShift()
        harness.overview.onEditShift?(existingShift)
        #expect(harness.metrics.editShiftJobs.last == updatedJob)
        #expect(harness.metrics.editedShifts.last == existingShift)
    }

    @Test("Edit Shift push, native Back и successful completion сохраняют Overview root")
    func editShiftNavigationUsesStableOverview() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let shift = try makeShift()
        harness.metrics.overviewShifts = [shift]
        harness.overview.reload(selectingShiftID: shift.id)

        harness.overview.onEditShift?(shift)
        let edit = try #require(
            harness.navigationController.topViewController as? EditShiftViewController
        )
        _ = harness.navigationController.popViewController(animated: false)
        #expect(harness.navigationController.topViewController === harness.overview)

        harness.overview.onEditShift?(shift)
        let pushedAgain = try #require(
            harness.navigationController.topViewController as? EditShiftViewController
        )
        #expect(pushedAgain !== edit)
        pushedAgain.onSaved?(shift)

        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.viewControllers.count == 1)
        #expect(harness.metrics.overviewLoadCount == 3)
    }

    @Test("Delete Shift reloads persistence and returns to the same Overview root")
    func deleteShiftReturnsToSameOverviewWithoutDeletedCard() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let deletedShift = try makeShift()
        let remainingStart = deletedShift.end.addingTimeInterval(3_600)
        let remainingShift = try Shift(
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
            start: remainingStart,
            end: remainingStart.addingTimeInterval(3_600)
        )
        harness.metrics.overviewShifts = [deletedShift, remainingShift]
        harness.overview.reload(selectingShiftID: deletedShift.id)
        let originalOverview = harness.overview

        harness.overview.onEditShift?(deletedShift)
        let edit = try #require(
            harness.navigationController.topViewController as? EditShiftViewController
        )
        harness.metrics.overviewShifts = [remainingShift]
        edit.onDeleted?(deletedShift.id)

        #expect(harness.navigationController.topViewController === originalOverview)
        #expect(harness.navigationController.viewControllers.count == 1)
        #expect(harness.navigationController.viewControllers.first === originalOverview)
        #expect(harness.metrics.overviewLoadCount == 3)
        #expect(findView(
            "overview.shift.\(deletedShift.id.uuidString)",
            in: originalOverview.view
        ) == nil)
        #expect(findView(
            "overview.shift.\(remainingShift.id.uuidString)",
            in: originalOverview.view
        ) != nil)
    }

    @Test("Deleting the sole Shift keeps the canonical Overview and renders its empty state")
    func deleteSoleShiftReturnsToOverviewEmptyState() throws {
        let harness = try makeHarness(cycle: .perShift)
        harness.coordinator.start()
        harness.overview.loadViewIfNeeded()
        let shift = try makeShift()
        harness.metrics.overviewShifts = [shift]
        harness.overview.reload(selectingShiftID: shift.id)
        let originalOverview = harness.overview

        harness.overview.onEditShift?(shift)
        let edit = try #require(
            harness.navigationController.topViewController as? EditShiftViewController
        )
        harness.metrics.overviewShifts = []
        edit.onDeleted?(shift.id)

        #expect(harness.navigationController.topViewController === originalOverview)
        #expect(harness.navigationController.viewControllers.count == 1)
        #expect(findView("overview.empty.container", in: originalOverview.view) != nil)
        #expect(findView(
            "overview.shift.\(shift.id.uuidString)",
            in: originalOverview.view
        ) == nil)
    }

    @Test("Comparison failure remains on Actual Gross with a neutral localized alert")
    func comparisonFailureStaysOnEntry() throws {
        let harness = try makeHarness(prepareComparison: { _, _, _ in
            throw MainCoordinatorTestError.comparisonFailed
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = harness.coordinator.tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        entry.onContinue?(try ActualGross(amount: 75))

        let alert = try #require(entry.presentedViewController as? UIAlertController)
        #expect(harness.navigationController.topViewController === entry)
        #expect(alert.title == String(
            localized: "application.paycheckComparisonError.title",
            table: "Localizable"
        ))
        #expect(alert.message == String(
            localized: "application.paycheckComparisonError.message",
            table: "Localizable"
        ))
    }

    @Test("Settings updates rate routing after a work type is archived")
    func settingsUpdatesRateRouting() throws {
        let harness = try makeHarness(cycle: .perShift)
        let twoTypes = try makeUpdatedJob(from: harness.job)
        harness.coordinator.start()
        let settingsStack = try #require(harness.coordinator.tabBarController.viewControllers?.last as? UINavigationController)
        let settings = try #require(settingsStack.topViewController as? SettingsViewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = harness.coordinator.tabBarController
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        harness.coordinator.tabBarController.selectedIndex = 3
        window.layoutIfNeeded()
        settings.onManageWorkTypes?()
        let initialTypes = try #require(settingsStack.topViewController as? WorkTypesViewController)
        initialTypes.onAddWorkType?()
        let add = try #require(settingsStack.topViewController as? AddWorkTypeViewController)
        add.onSaved?(twoTypes)
        _ = settingsStack.popViewController(animated: false)

        let button: UIButton = try requireView("settings.rates", in: settings.view)
        let ratesSection: UIView = try requireView("settings.rates.section", in: settings.view)
        let workTypesButton: UIButton = try requireView("settings.workTypes", in: settings.view)
        #expect(ratesSection.isHidden == true)
        #expect(!workTypesButton.isHidden)
        workTypesButton.sendActions(for: .primaryActionTriggered)
        let types = try #require(settingsStack.topViewController as? WorkTypesViewController)
        let chosen = try #require(twoTypes.workTypes.first)
        types.onPayRateHistory?(chosen)
        #expect(settingsStack.topViewController is PayRateHistoryViewController)
        #expect(harness.metrics.payRateHistoryInputs.last == chosen)
        _ = settingsStack.popViewController(animated: false)

        let archived = try twoTypes.archivingWorkType(id: chosen.id)
        types.onArchived?(archived)
        _ = settingsStack.popViewController(animated: false)
        #expect(ratesSection.isHidden == false)
        #expect(button.configuration?.title == PayRateHistoryStrings.title)
        button.sendActions(for: .primaryActionTriggered)
        let remaining = try #require(archived.workTypes.first { !$0.isArchived })
        #expect(settingsStack.topViewController is PayRateHistoryViewController)
        #expect(harness.metrics.payRateHistoryInputs.last == remaining)
        _ = settingsStack.popViewController(animated: false)
        workTypesButton.sendActions(for: .primaryActionTriggered)
        let remainingTypes = try #require(settingsStack.topViewController as? WorkTypesViewController)
        let zero = try archived.archivingWorkType(id: remaining.id)
        remainingTypes.onArchived?(zero)
        _ = settingsStack.popViewController(animated: false)
        #expect(ratesSection.isHidden == true)
        workTypesButton.sendActions(for: .primaryActionTriggered)
        #expect(settingsStack.topViewController is WorkTypesViewController)
    }

    private func makeHarness(
        cycle: PayCalculationCycle = .scheduled(.calendarMonthly),
        displayLocale: Locale = Locale(identifier: "en_US"),
        prepareComparison: @escaping @MainActor (Job, PayCalculationPeriod, ActualGross) throws -> PaycheckComparison = { job, period, actualGross in
            try job.paycheckComparison(for: period, actualGross: actualGross, from: [])
        }
    ) throws -> Harness {
        let job = try makeJob(cycle: cycle)
        let metrics = Metrics()
        func makeOverview(_ job: Job, countsOverviewLoads: Bool) -> OverviewViewController {
            OverviewViewController(
            viewModel: OverviewViewModel(
                job: job,
                loadShifts: {
                    if countsOverviewLoads { metrics.overviewLoadCount += 1 }
                    return metrics.overviewShifts
                },
                currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
            ),
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier,
            displayLocale: displayLocale
            )
        }
        let overview = makeOverview(job, countsOverviewLoads: true)
        var madeHome = false
        let navigationController = NonAnimatingNavigationController()
        let dependencies = MainCoordinator.Dependencies(
            loadArchivedJobs: { [] },
            makeArchivedJobHistory: { id in throw ArchivedJobHistoryError.jobNotFound(jobID: id) },
            makeOverview: { job in
                if madeHome { return makeOverview(job, countsOverviewLoads: false) }
                madeHome = true
                return overview
            },
            makeAddShift: { job in
                metrics.addShiftJobs.append(job)
                return AddShiftViewController(
                    viewModel: AddShiftViewModel(
                        jobID: job.id,
                        timeZoneIdentifier: job.timeZoneIdentifier,
                        workTypes: job.workTypes,
                        saveShift: { _ in .success(()) }
                    )
                )
            },
            makeWorkTypes: { job in
                metrics.workTypesJobs.append(job)
                metrics.workTypesInputs.append(job.workTypes)
                return WorkTypesViewController(viewModel: WorkTypesViewModel(workTypes: job.workTypes) { id in
                    do {
                        return .success(try job.archivingWorkType(id: id))
                    } catch {
                        return .failure(.generic)
                    }
                })
            },
            makeAddWorkType: { job in
                AddWorkTypeViewController(
                    viewModel: AddWorkTypeViewModel(
                        currencyCode: job.currencyCode,
                        saveWorkType: { _ in .failure(.persistence) }
                    )
                )
            },
            makeRenameWorkType: { job, workType in
                metrics.renameJobs.append(job)
                metrics.renameInputs.append(workType)
                return RenameWorkTypeViewController(
                    viewModel: RenameWorkTypeViewModel(workType: workType) { _, _ in
                        .failure(.persistence)
                    }
                )
            },
            makeChangePayRate: { job, workType in
                metrics.changePayRateJobs.append(job)
                metrics.changePayRateInputs.append(workType)
                return ChangePayRateViewController(
                    viewModel: ChangePayRateViewModel(
                        workType: workType,
                        currencyCode: job.currencyCode,
                        timeZoneIdentifier: job.timeZoneIdentifier,
                        savePayRate: { _, _ in .failure(.persistence) }
                    )
                )
            },
            makePayRateHistory: { job, workType in
                metrics.payRateHistoryJobs.append(job)
                metrics.payRateHistoryInputs.append(workType)
                return PayRateHistoryAssembly.make(job: job, workType: workType)
            },
            makeEditShift: { job, shift in
                metrics.editShiftJobs.append(job)
                metrics.editedShifts.append(shift)
                return EditShiftViewController(
                    viewModel: EditShiftViewModel(
                        timeZoneIdentifier: job.timeZoneIdentifier,
                        workTypes: job.workTypes,
                        shift: shift,
                        saveShift: { _ in .success(()) },
                        deleteShift: { _ in .success(()) }
                    )
                )
            },
            makeActualGrossEntry: { currencyCode in
                ActualGrossEntryViewController(
                    viewModel: ActualGrossEntryViewModel(decimalInputLocale: Locale(identifier: "en_US")),
                    currencyCode: currencyCode
                )
            },
            preparePaycheckComparison: { job, period, actualGross in
                metrics.preparedPeriods.append(period)
                metrics.preparedActualGrosses.append(actualGross)
                return try prepareComparison(job, period, actualGross)
            },
            makePaycheckResult: { comparison, job in
                PaycheckResultAssembly.make(
                    comparison: comparison,
                    currencyCode: job.currencyCode,
                    timeZoneIdentifier: job.timeZoneIdentifier,
                    workTypes: job.workTypes
                )
            }
        )
        let coordinator = MainCoordinator(
            navigationController: navigationController,
            job: job,
            dependencies: dependencies,
            makeNavigationController: { NonAnimatingNavigationController() }
        )

        return Harness(
            coordinator: coordinator,
            navigationController: navigationController,
            overview: overview,
            job: job,
            metrics: metrics
        )
    }

    private func makeJob(cycle: PayCalculationCycle = .scheduled(.calendarMonthly)) throws -> Job {
        try Job(
            id: testWorkTypeID,
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: cycle,
            payRates: [try PayRate(amount: 100, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift() throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        return try Shift(
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(3_600)
        )
    }

    private func makeUpdatedJob(from job: Job) throws -> Job {
        let exams = WorkType(
            id: UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(
                    id: UUID(uuid: (0x72, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                    amount: 500,
                    effectiveFrom: nil
                )
            ])
        )
        return try Job(
            id: job.id,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier,
            payCalculationCycle: job.payCalculationCycle,
            workTypes: job.workTypes + [exams],
            createdAt: job.createdAt
        )
    }

    private func requireView<View: UIView>(
        _ identifier: String,
        in root: UIView
    ) throws -> View {
        func find(in view: UIView) -> View? {
            if view.accessibilityIdentifier == identifier {
                return view as? View
            }
            for subview in view.subviews {
                if let match = find(in: subview) {
                    return match
                }
            }
            return nil
        }

        return try #require(find(in: root))
    }

    private func findView(_ identifier: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == identifier {
            return root
        }
        for subview in root.subviews {
            if let match = findView(identifier, in: subview) {
                return match
            }
        }
        return nil
    }
}

@MainActor
private final class Harness {
    let coordinator: MainCoordinator
    let navigationController: UINavigationController
    let overview: OverviewViewController
    let job: Job
    let metrics: Metrics

    init(
        coordinator: MainCoordinator,
        navigationController: UINavigationController,
        overview: OverviewViewController,
        job: Job,
        metrics: Metrics
    ) {
        self.coordinator = coordinator
        self.navigationController = navigationController
        self.overview = overview
        self.job = job
        self.metrics = metrics
    }
}

@MainActor
private final class Metrics {
    var overviewLoadCount = 0
    var overviewShifts: [Shift] = []
    var addShiftJobs: [Job] = []
    var workTypesInputs: [[WorkType]] = []
    var workTypesJobs: [Job] = []
    var renameInputs: [WorkType] = []
    var renameJobs: [Job] = []
    var changePayRateJobs: [Job] = []
    var changePayRateInputs: [WorkType] = []
    var payRateHistoryJobs: [Job] = []
    var payRateHistoryInputs: [WorkType] = []
    var editShiftJobs: [Job] = []
    var editedShifts: [Shift] = []
    var preparedPeriods: [PayCalculationPeriod] = []
    var preparedActualGrosses: [ActualGross] = []
}

private enum MainCoordinatorTestError: Error {
    case comparisonFailed
}

private final class NonAnimatingNavigationController: UINavigationController {
    override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        super.pushViewController(viewController, animated: false)
    }

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        super.popToViewController(viewController, animated: false)
    }
}
