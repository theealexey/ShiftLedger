import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftDateTimePickerViewControllerTests {
    @Test("Initial picker date strips hidden seconds while preserving the selected minute")
    func initialDateUsesMinuteBoundary() throws {
        let initialDate = try date(hour: 3, minute: 19, second: 54, nanosecond: 974_985_000)
        let viewController = try makeViewController(initialDate: initialDate) { _ in }
        viewController.loadViewIfNeeded()

        let picker = try #require(firstDescendant(of: UIDatePicker.self, in: viewController.view))

        try expectMinuteBoundary(picker.date, hour: 3, minute: 19)
    }

    @Test("Done action emits a minute boundary even when the picker date has fractional seconds")
    func doneNormalizesPickerDate() throws {
        var selectedDate: Date?
        let viewController = try makeViewController(initialDate: try date(hour: 3, minute: 19)) {
            selectedDate = $0
        }
        viewController.loadViewIfNeeded()
        let picker = try #require(firstDescendant(of: UIDatePicker.self, in: viewController.view))
        picker.date = try date(hour: 3, minute: 20, second: 5, nanosecond: 25_000_000)

        try tapDone(on: viewController)

        try expectMinuteBoundary(try #require(selectedDate), hour: 3, minute: 20)
    }

    @Test("Adjacent picker minutes construct a Shift with exactly sixty seconds")
    func adjacentMinutesProduceExactMinuteDuration() throws {
        var start: Date?
        let startPicker = try makeViewController(
            initialDate: try date(hour: 3, minute: 19, second: 54, nanosecond: 974_985_000)
        ) {
            start = $0
        }
        startPicker.loadViewIfNeeded()
        try tapDone(on: startPicker)

        var end: Date?
        let endPicker = try makeViewController(
            initialDate: try date(hour: 3, minute: 20, second: 5, nanosecond: 25_000_000)
        ) {
            end = $0
        }
        endPicker.loadViewIfNeeded()
        try tapDone(on: endPicker)

        let shift = try Shift(
            workTypeID: testWorkTypeID,
            start: try #require(start),
            end: try #require(end)
        )

        #expect(shift.paidDuration == 60)
    }

    private func makeViewController(
        initialDate: Date,
        onDateSelected: @escaping (Date) -> Void
    ) throws -> ShiftDateTimePickerViewController {
        ShiftDateTimePickerViewController(
            title: "Date",
            initialDate: initialDate,
            timeZone: try timeZone(),
            onDateSelected: onDateSelected
        )
    }

    private func tapDone(on viewController: ShiftDateTimePickerViewController) throws {
        let item = try #require(viewController.navigationItem.rightBarButtonItem)
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action)
    }

    private func expectMinuteBoundary(_ value: Date, hour: Int, minute: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try timeZone()
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: value)

        #expect(components.hour == hour)
        #expect(components.minute == minute)
        #expect(components.second == 0)
        #expect(components.nanosecond == 0)
    }

    private func date(
        hour: Int,
        minute: Int,
        second: Int = 0,
        nanosecond: Int = 0
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try timeZone()
        return try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 8,
            hour: hour,
            minute: minute,
            second: second,
            nanosecond: nanosecond
        )))
    }

    private func timeZone() throws -> TimeZone {
        try #require(TimeZone(identifier: "Europe/Moscow"))
    }

    private func firstDescendant<View: UIView>(of type: View.Type, in view: UIView) -> View? {
        if let match = view as? View {
            return match
        }
        for subview in view.subviews {
            if let match = firstDescendant(of: type, in: subview) {
                return match
            }
        }
        return nil
    }
}
