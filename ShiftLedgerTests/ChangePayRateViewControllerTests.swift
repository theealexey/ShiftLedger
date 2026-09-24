import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct ChangePayRateViewControllerTests {
    private let rateID = UUID(uuid: (0x82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

    @Test("Form renders exact WorkType, basis, currency and job-timezone date picker")
    func rendersContextAndControls() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let date = try LocalDate(year: 2026, month: 5, day: 2).startOfDay(in: zone)
        let controller = makeController(workType: try makeWorkType(basis: .hourly), date: date)
        controller.loadViewIfNeeded()
        #expect(controller.title == ChangePayRateStrings.title)
        #expect(controller.view.accessibilityIdentifier == "changePayRate.screen")
        let item = try #require(controller.navigationItem.rightBarButtonItem)
        #expect(item.title == ChangePayRateStrings.save)
        #expect(item.accessibilityIdentifier == "changePayRate.save")
        #expect(item.isEnabled == false)
        let context: UIStackView = try requireView("changePayRate.workType", in: controller.view)
        #expect(context.accessibilityLabel == "Lectures")
        #expect(context.accessibilityValue == ChangePayRateStrings.hourly)
        let amount: UITextField = try requireView("changePayRate.amount", in: controller.view)
        #expect(amount.text == "")
        #expect(amount.keyboardType == .decimalPad)
        #expect(amount.accessibilityLabel == ChangePayRateStrings.newHourlyRate)
        let currency: UIView = try requireView("changePayRate.currency", in: controller.view)
        let timeZone: UIView = try requireView("changePayRate.timeZone", in: controller.view)
        #expect(currency.accessibilityValue == "EUR")
        #expect(timeZone.accessibilityValue == zone.identifier)
        #expect(currency.accessibilityTraits.contains(.button) == false)
        let picker: UIDatePicker = try requireView("changePayRate.effectiveDate", in: controller.view)
        #expect(picker.datePickerMode == .date)
        #expect(picker.preferredDatePickerStyle == .compact)
        #expect(picker.calendar.identifier == .gregorian)
        #expect(picker.timeZone == zone)
        #expect(picker.date == date)

        let fixed = makeController(workType: try makeWorkType(basis: .fixedPerShift), date: date)
        fixed.loadViewIfNeeded()
        let fixedAmount: UITextField = try requireView("changePayRate.amount", in: fixed.view)
        #expect(fixedAmount.accessibilityLabel == ChangePayRateStrings.newPerShiftAmount)
        let fixedContext: UIStackView = try requireView("changePayRate.workType", in: fixed.view)
        #expect(fixedContext.accessibilityValue == ChangePayRateStrings.fixedPerShift)
    }

    @Test("Editing and date conflict update Save; successful Save emits once")
    func validatesAndSaves() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let conflict = try LocalDate(year: 2026, month: 5, day: 2)
        let unique = try LocalDate(year: 2026, month: 5, day: 3)
        let workType = try makeWorkType(basis: .hourly, dated: conflict)
        let expectedRate = try PayRate(id: rateID, amount: 25, effectiveFrom: unique)
        let updated = try makeJob(workType: workType.addingPayRate(expectedRate))
        var saved: [Job] = []
        var received: PayRate?
        let controller = ChangePayRateViewController(viewModel: ChangePayRateViewModel(
            workType: workType,
            currencyCode: "EUR",
            timeZoneIdentifier: zone.identifier,
            initialEffectiveDate: try conflict.startOfDay(in: zone),
            makePayRateID: { rateID },
            savePayRate: { id, rate in
                #expect(id == workType.id)
                received = rate
                return .success(updated)
            }
        ))
        controller.onSaved = { saved.append($0) }
        controller.loadViewIfNeeded()
        let amount: UITextField = try requireView("changePayRate.amount", in: controller.view)
        let picker: UIDatePicker = try requireView("changePayRate.effectiveDate", in: controller.view)
        let error: UILabel = try requireView("changePayRate.effectiveDate.error", in: controller.view)
        let save = try #require(controller.navigationItem.rightBarButtonItem)
        amount.text = "25"
        amount.sendActions(for: .editingChanged)
        #expect(error.isHidden == false)
        #expect(error.text == ChangePayRateStrings.duplicateDate)
        #expect(save.isEnabled == false)
        picker.date = try unique.startOfDay(in: zone)
        picker.sendActions(for: .valueChanged)
        #expect(error.isHidden)
        #expect(save.isEnabled)
        try tap(save)
        #expect(received == expectedRate)
        #expect(saved == [updated])
        #expect(save.isEnabled == false)
        #expect(controller.presentedViewController == nil)
        try tap(save)
        #expect(saved.count == 1)
    }

    @Test("Persistence failure shows one alert and preserves editable values for retry")
    func failureAndRetry() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let date = try LocalDate(year: 2026, month: 5, day: 3).startOfDay(in: zone)
        var calls = 0
        let controller = ChangePayRateViewController(viewModel: ChangePayRateViewModel(
            workType: try makeWorkType(basis: .hourly),
            currencyCode: "EUR",
            timeZoneIdentifier: zone.identifier,
            initialEffectiveDate: date,
            savePayRate: { _, _ in
                calls += 1
                return .failure(.persistence)
            }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let amount: UITextField = try requireView("changePayRate.amount", in: controller.view)
        let picker: UIDatePicker = try requireView("changePayRate.effectiveDate", in: controller.view)
        amount.text = "55"
        amount.sendActions(for: .editingChanged)
        let save = try #require(controller.navigationItem.rightBarButtonItem)
        try tap(save)
        let alert = try #require(controller.presentedViewController as? UIAlertController)
        #expect(alert.title == ChangePayRateStrings.errorTitle)
        #expect(alert.message == ChangePayRateStrings.errorMessage)
        #expect(alert.actions.map(\.title) == [ChangePayRateStrings.ok])
        #expect(amount.text == "55")
        #expect(picker.date == date)
        #expect(save.isEnabled)
        try tap(save)
        #expect(controller.presentedViewController === alert)
        #expect(calls == 2)
    }

    @Test("Accessibility-sized form remains scrollable with reachable controls")
    func accessibilityLayout() throws {
        let controller = makeController(
            workType: try makeWorkType(basis: .fixedPerShift),
            date: Date(timeIntervalSinceReferenceDate: 0)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let scroll = try #require(controller.view.subviews.first as? UIScrollView)
        let amount: UITextField = try requireView("changePayRate.amount", in: controller.view)
        let picker: UIDatePicker = try requireView("changePayRate.effectiveDate", in: controller.view)
        let zone: UIView = try requireView("changePayRate.timeZone", in: controller.view)
        #expect(scroll.alwaysBounceVertical)
        #expect(scroll.keyboardDismissMode == .interactive)
        #expect(amount.bounds.height >= 44)
        #expect(picker.bounds.height >= 44)
        #expect(zone.bounds.height >= 52)
        #expect(amount.bounds.width > 0)
        #expect(zone.bounds.width > 0)
    }

    private func makeController(workType: WorkType, date: Date) -> ChangePayRateViewController {
        ChangePayRateViewController(viewModel: ChangePayRateViewModel(
            workType: workType,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            initialEffectiveDate: date,
            savePayRate: { _, _ in .failure(.persistence) }
        ))
    }

    private func makeWorkType(basis: BasePayBasis, dated: LocalDate? = nil) throws -> WorkType {
        var rates = [try PayRate(amount: 10, effectiveFrom: nil)]
        if let dated { rates.append(try PayRate(amount: 15, effectiveFrom: dated)) }
        return WorkType(
            id: UUID(uuid: (0x82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            name: "Lectures",
            basePayBasis: basis,
            payRateHistory: try PayRateHistory(payRates: rates)
        )
    }

    private func makeJob(workType: WorkType) throws -> Job {
        try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType]
        )
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
                if let found: View = find(in: child) { return found }
            }
            return nil
        }
        return try #require(find(in: root))
    }
}
