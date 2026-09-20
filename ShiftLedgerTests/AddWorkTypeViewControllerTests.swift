import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct AddWorkTypeViewControllerTests {
    @Test("Экран показывает навигацию, валюту и начально выключенный Save")
    func initialRendering() throws {
        let subject = makeSubject()
        subject.viewController.loadViewIfNeeded()

        #expect(subject.viewController.title == AddWorkTypeStrings.title)
        #expect(subject.viewController.navigationItem.rightBarButtonItem?.title == AddWorkTypeStrings.save)
        #expect(subject.viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier == "addWorkType.save")
        #expect(subject.viewController.navigationItem.rightBarButtonItem?.isEnabled == false)
        let currency: UIView = try requireView("addWorkType.currency", in: subject.viewController.view)
        #expect(currency.accessibilityValue == "EUR")
        #expect(currency.accessibilityTraits.contains(.button) == false)
    }

    @Test("Выбор базы показывает правильную сумму и валидный ввод включает Save")
    func validInputEnablesSave() throws {
        let subject = makeSubject()
        subject.viewController.loadViewIfNeeded()
        let name: UITextField = try requireView("addWorkType.name", in: subject.viewController.view)
        let fixed: UIControl = try requireView("addWorkType.basis.fixedPerShift", in: subject.viewController.view)
        let amount: UITextField = try requireView("addWorkType.amount", in: subject.viewController.view)
        let amountTitle: UILabel = try requireView("addWorkType.amount.title", in: subject.viewController.view)

        name.text = "Exams"
        name.sendActions(for: .editingChanged)
        fixed.sendActions(for: .touchUpInside)
        #expect(amountTitle.text == AddWorkTypeStrings.fixedPerShiftAmountTitle)
        amount.text = "500"
        amount.sendActions(for: .editingChanged)

        #expect(subject.viewController.navigationItem.rightBarButtonItem?.isEnabled == true)
    }

    @Test("Успешный Save передаёт обновлённый Job ровно один раз")
    func successEmitsUpdatedJobOnce() throws {
        let updatedJob = try makeJob()
        let subject = makeSubject(save: { _ in .success(updatedJob) })
        var receivedJobs: [Job] = []
        subject.viewController.onSaved = { receivedJobs.append($0) }
        subject.viewController.loadViewIfNeeded()
        try enterValidInput(in: subject.viewController)

        try tapSave(on: subject.viewController)
        try tapSave(on: subject.viewController)

        #expect(receivedJobs == [updatedJob])
    }

    @Test("Ошибка показывает локализованный alert и сохраняет введённые значения")
    func failurePreservesInputAndPresentsAlert() throws {
        let subject = makeSubject(save: { _ in .failure(.persistence) })
        let navigation = UINavigationController(rootViewController: subject.viewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        try enterValidInput(in: subject.viewController)

        try tapSave(on: subject.viewController)

        let alert = try #require(subject.viewController.presentedViewController as? UIAlertController)
        #expect(alert.title == AddWorkTypeStrings.errorTitle)
        #expect(alert.message == AddWorkTypeStrings.errorMessage)
        #expect(alert.actions.first?.title == AddWorkTypeStrings.ok)
        let name: UITextField = try requireView("addWorkType.name", in: subject.viewController.view)
        let amount: UITextField = try requireView("addWorkType.amount", in: subject.viewController.view)
        #expect(name.text == "Exams")
        #expect(amount.text == "500")
        #expect(subject.viewController.navigationItem.rightBarButtonItem?.isEnabled == true)
    }

    @Test("Форма доступна при крупном Dynamic Type и остаётся прокручиваемой")
    func accessibilityLayoutRemainsScrollable() throws {
        let subject = makeSubject()
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }

        subject.viewController.loadViewIfNeeded()

        let screen: UIView = try requireView(
            "addWorkType.screen",
            in: subject.viewController.view
        )
        let scrollView = try #require(
            firstDescendant(of: UIScrollView.self, in: screen)
        )
        let hourly: UIControl = try requireView(
            "addWorkType.basis.hourly",
            in: screen
        )

        hourly.sendActions(for: .touchUpInside)

        window.layoutIfNeeded()
        subject.viewController.view.layoutIfNeeded()

        let name: UITextField = try requireView("addWorkType.name", in: screen)
        let fixed: UIControl = try requireView(
            "addWorkType.basis.fixedPerShift",
            in: screen
        )
        let amount: UITextField = try requireView(
            "addWorkType.amount",
            in: screen
        )
        let currency: UIView = try requireView(
            "addWorkType.currency",
            in: screen
        )

        #expect(name.adjustsFontForContentSizeCategory)
        #expect(hourly.bounds.height >= 44)
        #expect(fixed.bounds.height >= 44)
        #expect(amount.bounds.height >= 44)
        #expect(currency.bounds.height >= 52)

        #expect(scrollView.contentSize.height > scrollView.bounds.height)

        let fixedFrame = fixed.convert(fixed.bounds, to: scrollView)
        let amountFrame = amount.convert(amount.bounds, to: scrollView)
        let currencyFrame = currency.convert(currency.bounds, to: scrollView)

        #expect(fixedFrame.maxY <= amountFrame.minY)
        #expect(amountFrame.maxY <= currencyFrame.minY)

        scrollView.scrollRectToVisible(currencyFrame, animated: false)

        #expect(scrollView.bounds.intersects(currencyFrame))
    }

    private func makeSubject(
        save: @escaping (WorkType) -> Result<Job, AddWorkTypeSaveFailure> = { _ in .failure(.persistence) }
    ) -> Subject {
        let viewModel = AddWorkTypeViewModel(
            currencyCode: "EUR",
            decimalInputLocale: Locale(identifier: "en_US"),
            saveWorkType: save,
            makeWorkTypeID: { UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)) },
            makePayRateID: { UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)) }
        )
        return Subject(
            viewController: AddWorkTypeViewController(viewModel: viewModel),
            viewModel: viewModel
        )
    }

    private func enterValidInput(in viewController: AddWorkTypeViewController) throws {
        let name: UITextField = try requireView("addWorkType.name", in: viewController.view)
        let fixed: UIControl = try requireView("addWorkType.basis.fixedPerShift", in: viewController.view)
        let amount: UITextField = try requireView("addWorkType.amount", in: viewController.view)
        name.text = "Exams"
        name.sendActions(for: .editingChanged)
        fixed.sendActions(for: .touchUpInside)
        amount.text = "500"
        amount.sendActions(for: .editingChanged)
    }

    private func tapSave(on viewController: AddWorkTypeViewController) throws {
        let item = try #require(viewController.navigationItem.rightBarButtonItem)
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action)
    }

    private func makeJob() throws -> Job {
        try Job(
            id: UUID(uuid: (0x71, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            workTypeName: "Lectures",
            payCalculationCycle: .perShift,
            payRates: [try PayRate(amount: 20, effectiveFrom: nil)]
        )
    }

    private func requireView<View: UIView>(_ identifier: String, in root: UIView) throws -> View {
        if let match = firstDescendant(of: View.self, in: root, identifier: identifier) {
            return match
        }
        throw TestError.missingView(identifier)
    }

    private func firstDescendant<View: UIView>(
        of type: View.Type,
        in root: UIView,
        identifier: String? = nil
    ) -> View? {
        if let match = root as? View,
           identifier == nil || root.accessibilityIdentifier == identifier {
            return match
        }
        for child in root.subviews {
            if let match = firstDescendant(of: type, in: child, identifier: identifier) {
                return match
            }
        }
        return nil
    }
}

@MainActor
private struct Subject {
    let viewController: AddWorkTypeViewController
    let viewModel: AddWorkTypeViewModel
}

private enum TestError: Error {
    case missingView(String)
}
