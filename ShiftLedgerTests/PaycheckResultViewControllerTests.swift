import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct PaycheckResultViewControllerTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test("Expected gross renders from a real Domain comparison")
    func expectedGrossRendersFromRealComparison() throws {
        let comparison = try realDomainComparison()
        let viewController = PaycheckResultAssembly.make(
            comparison: comparison,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            displayLocale: locale
        )
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.expected.value",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.currency(
            comparison.expected.expectedGross,
            currencyCode: "EUR",
            locale: locale
        ))
    }

    @Test("Reported gross renders from ActualGross")
    func actualGrossRenders() throws {
        let comparison = try makeComparison(expected: 160, actual: 150)
        let viewController = makeViewController(comparison)
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.actual.value",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.currency(150, currencyCode: "EUR", locale: locale))
    }

    @Test("Difference renders from PaycheckComparison difference")
    func differenceRenders() throws {
        let comparison = try makeComparison(expected: 160, actual: 150)
        let viewController = makeViewController(comparison)
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.difference.value",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.difference(
            comparison.difference,
            currencyCode: "EUR",
            locale: locale
        ))
    }

    @Test("Negative difference renders lower explanation")
    func negativeExplanationRenders() throws {
        let viewController = makeViewController(try makeComparison(expected: 160, actual: 150))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.lower)
    }

    @Test("Exact equality renders matching explanation")
    func equalityExplanationRenders() throws {
        let viewController = makeViewController(try makeComparison(expected: 160, actual: 160))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.equal)
    }

    @Test("Positive difference renders higher explanation")
    func positiveExplanationRenders() throws {
        let viewController = makeViewController(try makeComparison(expected: 150, actual: 160))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.higher)
    }

    @Test("Difference and explanation do not use sign-based status colors")
    func signDoesNotChangeColors() throws {
        let negativeController = makeViewController(try makeComparison(expected: 160, actual: 150))
        let positiveController = makeViewController(try makeComparison(expected: 150, actual: 160))
        negativeController.loadViewIfNeeded()
        positiveController.loadViewIfNeeded()

        let negativeDifference: UILabel = try requireView(
            identifier: "paycheckResult.difference.value",
            in: negativeController.view
        )
        let positiveDifference: UILabel = try requireView(
            identifier: "paycheckResult.difference.value",
            in: positiveController.view
        )
        let negativeExplanation: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: negativeController.view
        )
        let positiveExplanation: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: positiveController.view
        )

        #expect(negativeDifference.textColor == ShiftLedgerColors.textPrimary)
        #expect(positiveDifference.textColor == ShiftLedgerColors.textPrimary)
        #expect(negativeExplanation.textColor == ShiftLedgerColors.textSecondary)
        #expect(positiveExplanation.textColor == ShiftLedgerColors.textSecondary)
    }

    @Test("Rendered breakdown row count matches Domain breakdown count")
    func breakdownCountMatchesDomain() throws {
        let breakdowns = try [
            hourlyBreakdown(day: 20, rate: 20, basePay: 160),
            hourlyBreakdown(day: 21, rate: 25, basePay: 200)
        ]
        let comparison = try makeComparison(expected: 360, actual: 350, breakdowns: breakdowns)
        let viewController = makeViewController(comparison)
        viewController.loadViewIfNeeded()

        #expect(renderedRowCount(in: viewController.view) == comparison.expected.shiftBreakdowns.count)
    }

    @Test("Rendered breakdown preserves Domain order")
    func breakdownOrderIsPreserved() throws {
        let later = try hourlyBreakdown(day: 21, rate: 25, basePay: 200)
        let earlier = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 360,
            actual: 350,
            breakdowns: [later, earlier]
        ))
        viewController.loadViewIfNeeded()

        let first: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.date",
            in: viewController.view
        )
        let second: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.1.date",
            in: viewController.view
        )
        #expect(first.text?.contains("21") == true)
        #expect(second.text?.contains("20") == true)
    }

    @Test("Hourly row renders local shift date and time")
    func hourlyRowRendersDateTime() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.date",
            in: viewController.view
        )
        #expect(label.text?.contains("Sep") == true)
        #expect(label.text?.contains("20") == true)
        #expect(label.text?.contains("8:00") == true)
    }

    @Test("Hourly row renders canonical paid duration")
    func hourlyRowRendersPaidDuration() throws {
        let breakdown = try hourlyBreakdown(
            day: 20,
            rate: 20,
            paidDuration: 7.5 * 3_600,
            basePay: 150
        )
        let viewController = makeViewController(try makeComparison(
            expected: 150,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.duration",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.paidDuration(breakdown.paidDuration))
    }

    @Test("Hourly row renders applied rate")
    func hourlyRowRendersAppliedRate() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.rate",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.rate(
            amount: breakdown.appliedPayRate.amount,
            basis: .hourly,
            currencyCode: "EUR",
            locale: locale
        ))
    }

    @Test("Hourly row renders canonical base pay")
    func hourlyRowRendersBasePay() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.amount",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.currency(
            breakdown.basePay,
            currencyCode: "EUR",
            locale: locale
        ))
    }

    @Test("Fixed-per-shift row labels rate per shift")
    func fixedRowUsesShiftRateUnit() throws {
        let breakdown = try fixedBreakdown()
        let viewController = makeViewController(try makeComparison(
            expected: 175,
            actual: 170,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.rate",
            in: viewController.view
        )
        #expect(label.text?.contains("/ \(PaycheckResultStrings.rateShift)") == true)
    }

    @Test("Fixed-per-shift row uses canonical breakdown base pay")
    func fixedRowUsesCanonicalBasePay() throws {
        let breakdown = try fixedBreakdown()
        let viewController = makeViewController(try makeComparison(
            expected: 175,
            actual: 170,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.amount",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultFormatting.currency(
            breakdown.basePay,
            currencyCode: "EUR",
            locale: locale
        ))
        #expect(label.text?.contains("175") == true)
    }

    @Test("Zero-shift comparison renders empty breakdown message")
    func zeroShiftComparisonRendersEmptyBreakdown() throws {
        let viewController = makeViewController(try makeComparison(expected: .zero, actual: 50))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.empty",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.breakdownEmpty)
        #expect(label.isHidden == false)
        #expect(renderedRowCount(in: viewController.view) == 0)
    }

    @Test("Zero-shift comparison still renders the summary")
    func zeroShiftComparisonRendersSummary() throws {
        let viewController = makeViewController(try makeComparison(expected: .zero, actual: 50))
        viewController.loadViewIfNeeded()

        let expected: UILabel = try requireView(
            identifier: "paycheckResult.expected.value",
            in: viewController.view
        )
        let actual: UILabel = try requireView(
            identifier: "paycheckResult.actual.value",
            in: viewController.view
        )
        let difference: UILabel = try requireView(
            identifier: "paycheckResult.difference.value",
            in: viewController.view
        )
        #expect(expected.text?.contains("0") == true)
        #expect(actual.text?.contains("50") == true)
        #expect(difference.text?.contains("50") == true)
    }

    @Test("Done action invokes callback exactly once")
    func doneInvokesCallbackOnce() throws {
        let viewController = makeViewController(try makeComparison(expected: 160, actual: 150))
        var callCount = 0
        viewController.onDone = { callCount += 1 }
        viewController.loadViewIfNeeded()
        let button: UIButton = try requireView(
            identifier: "paycheckResult.done",
            in: viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(callCount == 1)
    }

    @Test("Required accessibility identifiers exist")
    func accessibilityIdentifiersExist() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        for identifier in [
            "paycheckResult.screen",
            "paycheckResult.expected.label",
            "paycheckResult.expected.value",
            "paycheckResult.actual.label",
            "paycheckResult.actual.value",
            "paycheckResult.difference.label",
            "paycheckResult.difference.value",
            "paycheckResult.explanation",
            "paycheckResult.breakdown.title",
            "paycheckResult.done",
            "paycheckResult.breakdown.row.0",
            "paycheckResult.breakdown.row.0.date",
            "paycheckResult.breakdown.row.0.duration",
            "paycheckResult.breakdown.row.0.rate",
            "paycheckResult.breakdown.row.0.amount"
        ] {
            #expect(descendant(identifier: identifier, in: viewController.view) != nil)
        }
        #expect((try requireView(
            identifier: "paycheckResult.done",
            in: viewController.view
        ) as UIButton).accessibilityLabel == PaycheckResultStrings.done)
    }

    @Test("All result labels and Done support Dynamic Type")
    func contentSupportsDynamicType() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        for identifier in [
            "paycheckResult.expected.label",
            "paycheckResult.expected.value",
            "paycheckResult.actual.label",
            "paycheckResult.actual.value",
            "paycheckResult.difference.label",
            "paycheckResult.difference.value",
            "paycheckResult.explanation",
            "paycheckResult.breakdown.title",
            "paycheckResult.breakdown.row.0.date",
            "paycheckResult.breakdown.row.0.duration",
            "paycheckResult.breakdown.row.0.rate",
            "paycheckResult.breakdown.row.0.amount"
        ] {
            let label: UILabel = try requireView(identifier: identifier, in: viewController.view)
            #expect(label.adjustsFontForContentSizeCategory)
        }
        let done: UIButton = try requireView(identifier: "paycheckResult.done", in: viewController.view)
        #expect(done.titleLabel?.adjustsFontForContentSizeCategory == true)
    }

    @Test("Flexible labels do not use fixed heights")
    func labelsHaveFlexibleHeight() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        for identifier in [
            "paycheckResult.expected.value",
            "paycheckResult.actual.value",
            "paycheckResult.difference.value",
            "paycheckResult.explanation",
            "paycheckResult.breakdown.row.0.date",
            "paycheckResult.breakdown.row.0.duration",
            "paycheckResult.breakdown.row.0.rate",
            "paycheckResult.breakdown.row.0.amount"
        ] {
            let label: UILabel = try requireView(identifier: identifier, in: viewController.view)
            #expect(label.numberOfLines == 0)
            #expect(hasFixedHeight(label) == false)
        }
    }

    @Test("Scroll view keeps large result content reachable")
    func scrollViewSupportsLargeContent() throws {
        let viewController = makeViewController(try makeComparison(expected: 160, actual: 150))
        viewController.loadViewIfNeeded()

        let scrollView = try #require(firstDescendant(of: UIScrollView.self, in: viewController.view))

        #expect(scrollView.alwaysBounceVertical)
    }

    private func makeViewController(_ comparison: PaycheckComparison) -> PaycheckResultViewController {
        PaycheckResultViewController(
            comparison: comparison,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            displayLocale: locale
        )
    }

    private func makeComparison(
        expected: Decimal,
        actual: Decimal,
        breakdowns: [ShiftPayBreakdown] = []
    ) throws -> PaycheckComparison {
        let period = PayCalculationPeriod.scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 9, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
        ))

        return PaycheckComparison(
            expected: ExpectedGrossBreakdown(
                period: period,
                shiftBreakdowns: breakdowns,
                expectedGross: expected
            ),
            actualGross: try ActualGross(amount: actual)
        )
    }

    private func hourlyBreakdown(
        day: Int,
        rate: Decimal,
        paidDuration: TimeInterval = 8 * 3_600,
        basePay: Decimal
    ) throws -> ShiftPayBreakdown {
        let shift = try makeShift(day: day, hour: 8, duration: 8 * 3_600)
        return ShiftPayBreakdown(
            shift: shift,
            basePayBasis: .hourly,
            appliedPayRate: try PayRate(amount: rate, effectiveFrom: nil),
            paidDuration: paidDuration,
            basePay: basePay
        )
    }

    private func fixedBreakdown() throws -> ShiftPayBreakdown {
        let start = try date(day: 20, hour: 8)
        let shift = try Shift(
            id: try uuid(20),
            start: start,
            end: start.addingTimeInterval(8 * 3_600),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(2 * 3_600),
                end: start.addingTimeInterval(5 * 3_600)
            )
        )
        return ShiftPayBreakdown(
            shift: shift,
            basePayBasis: .fixedPerShift,
            appliedPayRate: try PayRate(amount: 175, effectiveFrom: nil),
            paidDuration: shift.paidDuration,
            basePay: 175
        )
    }

    private func realDomainComparison() throws -> PaycheckComparison {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [rate],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let shift = try makeShift(day: 20, hour: 8, duration: 8 * 3_600)
        let period = try job.payCalculationPeriod(for: shift)
        return try job.paycheckComparison(
            for: period,
            actualGross: try ActualGross(amount: 150),
            from: [shift]
        )
    }

    private func makeShift(day: Int, hour: Int, duration: TimeInterval) throws -> Shift {
        let start = try date(day: day, hour: hour)
        return try Shift(
            id: try uuid(day),
            start: start,
            end: start.addingTimeInterval(duration)
        )
    }

    private func date(day: Int, hour: Int) throws -> Date {
        let timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: day,
            hour: hour
        )))
    }

    private func uuid(_ value: Int) throws -> UUID {
        try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)))
    }

    private func requireView<View: UIView>(identifier: String, in root: UIView) throws -> View {
        try #require(descendant(identifier: identifier, in: root) as? View)
    }

    private func descendant(identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier {
            return view
        }
        for subview in view.subviews {
            if let match = descendant(identifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }

    private func renderedRowCount(in root: UIView) -> Int {
        var count = 0
        while descendant(identifier: "paycheckResult.breakdown.row.\(count)", in: root) != nil {
            count += 1
        }
        return count
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

    private func hasFixedHeight(_ view: UIView) -> Bool {
        view.constraints.contains {
            $0.firstAttribute == .height && $0.relation == .equal
        }
    }
}
