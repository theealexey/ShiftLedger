import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct RenameWorkTypeViewControllerTests {
    @Test("Named and historical WorkTypes prefill the sole editable field")
    func prefill() throws {
        let named = RenameWorkTypeViewController(viewModel: RenameWorkTypeViewModel(
            workType: try makeWorkType(name: "Lectures"),
            saveName: { _, _ in .failure(.persistence) }
        ))
        named.loadViewIfNeeded()
        let name: UITextField = try requireView("renameWorkType.name", in: named.view)
        #expect(name.text == "Lectures")
        #expect(name.accessibilityLabel == RenameWorkTypeStrings.nameTitle)
        #expect(name.accessibilityHint == RenameWorkTypeStrings.nameAccessibilityHint)
        #expect(name.adjustsFontForContentSizeCategory)
        #expect(named.view.accessibilityIdentifier == "renameWorkType.screen")

        let unnamed = RenameWorkTypeViewController(viewModel: RenameWorkTypeViewModel(
            workType: try makeWorkType(name: nil),
            saveName: { _, _ in .failure(.persistence) }
        ))
        unnamed.loadViewIfNeeded()
        let emptyName: UITextField = try requireView("renameWorkType.name", in: unnamed.view)
        #expect(emptyName.text == "")
    }

    @Test("EditingChanged updates Save validity and successful Save emits once")
    func saveFromBoundForm() throws {
        let original = try makeWorkType(name: "Lectures")
        let updatedJob = try makeJob(workType: try original.renamed(to: "Exams"))
        var rawName: String?
        var savedJobs: [Job] = []
        let controller = RenameWorkTypeViewController(viewModel: RenameWorkTypeViewModel(
            workType: original,
            saveName: { id, raw in
                #expect(id == original.id)
                rawName = raw
                return .success(updatedJob)
            }
        ))
        controller.onSaved = { savedJobs.append($0) }
        controller.loadViewIfNeeded()
        let item = try #require(controller.navigationItem.rightBarButtonItem)
        #expect(controller.title == RenameWorkTypeStrings.title)
        #expect(item.title == RenameWorkTypeStrings.save)
        #expect(item.accessibilityIdentifier == "renameWorkType.save")
        #expect(item.isEnabled == false)
        let field: UITextField = try requireView("renameWorkType.name", in: controller.view)
        field.text = " "
        field.sendActions(for: .editingChanged)
        #expect(item.isEnabled == false)
        field.text = "  Exams  "
        field.sendActions(for: .editingChanged)
        #expect(item.isEnabled)
        try tap(item)
        #expect(rawName == "  Exams  ")
        #expect(savedJobs == [updatedJob])
        #expect(item.isEnabled == false)
        #expect(controller.presentedViewController == nil)
        try tap(item)
        #expect(savedJobs.count == 1)
    }

    @Test("Failure shows one localized alert, retains input and allows retry")
    func failureAlert() throws {
        let controller = RenameWorkTypeViewController(viewModel: RenameWorkTypeViewModel(
            workType: try makeWorkType(name: "Lectures"),
            saveName: { _, _ in .failure(.persistence) }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let field: UITextField = try requireView("renameWorkType.name", in: controller.view)
        field.text = "  Exams  "
        field.sendActions(for: .editingChanged)
        let item = try #require(controller.navigationItem.rightBarButtonItem)
        try tap(item)
        let alert = try #require(controller.presentedViewController as? UIAlertController)
        #expect(alert.title == RenameWorkTypeStrings.errorTitle)
        #expect(alert.message == RenameWorkTypeStrings.errorMessage)
        #expect(alert.actions.count == 1)
        #expect(alert.actions.first?.title == RenameWorkTypeStrings.ok)
        #expect(field.text == "  Exams  ")
        #expect(item.isEnabled)
        try tap(item)
        #expect(controller.presentedViewController === alert)
    }

    @Test("Name field has a scalable minimum height inside a scrollable form")
    func dynamicTypeLayout() throws {
        let controller = RenameWorkTypeViewController(viewModel: RenameWorkTypeViewModel(
            workType: try makeWorkType(name: "Lectures"),
            saveName: { _, _ in .failure(.persistence) }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let field: UITextField = try requireView("renameWorkType.name", in: controller.view)
        let scroll = try #require(controller.view.subviews.first as? UIScrollView)
        #expect(scroll.alwaysBounceVertical)
        #expect(scroll.keyboardDismissMode == .interactive)
        #expect(field.bounds.height >= 44)
        #expect(field.adjustsFontForContentSizeCategory)
        #expect(field.frame.width > 0)
    }

    private func tap(_ item: UIBarButtonItem) throws {
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action)
    }

    private func requireView<View: UIView>(_ identifier: String, in root: UIView) throws -> View {
        func find(in view: UIView) -> View? {
            if view.accessibilityIdentifier == identifier { return view as? View }
            for child in view.subviews {
                if let found = find(in: child) { return found }
            }
            return nil
        }
        return try #require(find(in: root))
    }

    private func makeWorkType(name: String?) throws -> WorkType {
        WorkType(
            id: UUID(uuid: (0x74, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [try PayRate(amount: 100, effectiveFrom: nil)])
        )
    }

    private func makeJob(workType: WorkType) throws -> Job {
        try Job(
            id: UUID(uuid: (0x74, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
