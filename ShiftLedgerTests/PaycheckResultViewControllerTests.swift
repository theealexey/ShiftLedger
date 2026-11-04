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
            workTypes: [try workType()],
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
        let comparison = try realDomainComparison()
        let viewController = try makeViewController(comparison)
        viewController.loadViewIfNeeded()
        let model = PaycheckResultFormatting.renderModel(
            comparison: comparison,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType()],
            locale: locale
        )

        let label: UILabel = try requireView(
            identifier: "paycheckResult.actual.value",
            in: viewController.view
        )
        #expect(label.text == model.actual)
    }

    @Test("Difference renders from PaycheckComparison difference")
    func differenceRenders() throws {
        let comparison = try realDomainComparison()
        let viewController = try makeViewController(comparison)
        viewController.loadViewIfNeeded()
        let model = PaycheckResultFormatting.renderModel(
            comparison: comparison,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType()],
            locale: locale
        )

        let label: UILabel = try requireView(
            identifier: "paycheckResult.difference.value",
            in: viewController.view
        )
        #expect(label.text == model.difference)
    }

    @Test("Negative difference renders lower explanation")
    func negativeExplanationRenders() throws {
        let viewController = try makeViewController(try makeComparison(expected: 160, actual: 150))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.lower)
    }

    @Test("Exact equality renders matching explanation")
    func equalityExplanationRenders() throws {
        let viewController = try makeViewController(try makeComparison(expected: 160, actual: 160))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.equal)
    }

    @Test("Positive difference renders higher explanation")
    func positiveExplanationRenders() throws {
        let viewController = try makeViewController(try makeComparison(expected: 150, actual: 160))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.explanation",
            in: viewController.view
        )
        #expect(label.text == PaycheckResultStrings.higher)
    }

    @Test("Difference and explanation do not use sign-based status colors")
    func signDoesNotChangeColors() throws {
        let negativeController = try makeViewController(try makeComparison(expected: 160, actual: 150))
        let positiveController = try makeViewController(try makeComparison(expected: 150, actual: 160))
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
        let viewController = try makeViewController(comparison)
        viewController.loadViewIfNeeded()

        #expect(renderedRowCount(in: viewController.view) == comparison.expected.shiftBreakdowns.count)
    }

    @Test("Rendered breakdown preserves Domain order")
    func breakdownOrderIsPreserved() throws {
        let later = try hourlyBreakdown(day: 21, rate: 25, basePay: 200)
        let earlier = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(
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

    @Test("Breakdown shows the WorkType name above the existing Shift details")
    func breakdownShowsWorkTypeIdentity() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = try makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let workType: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.workType",
            in: viewController.view
        )
        #expect(workType.text == "Lectures")
        for identifier in ["date", "duration", "rate", "amount"] {
            #expect(descendant(
                identifier: "paycheckResult.breakdown.row.0.\(identifier)",
                in: viewController.view
            ) != nil)
        }
    }

    @Test("Long WorkType name remains flexible in accessibility layout")
    func workTypeNameSupportsAccessibilityLayout() throws {
        let name = "Lectures and supervised examination preparation"
        let fixture = try makeHostedResultViewController(
            contentSizeCategory: .accessibilityExtraExtraLarge,
            workTypeName: name
        )
        let workType: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.workType",
            in: fixture.result.view
        )
        let date: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.date",
            in: fixture.result.view
        )
        let card: UIView = try requireView(
            identifier: "paycheckResult.breakdown.row.0",
            in: fixture.result.view
        )
        let scrollView = try #require(firstDescendant(of: UIScrollView.self, in: fixture.result.view))

        #expect(workType.text == name)
        #expect(workType.adjustsFontForContentSizeCategory)
        #expect(workType.numberOfLines == 0)
        let layoutEpsilon: CGFloat = 0.001
        #expect(workType.frame.maxY <= date.frame.minY + layoutEpsilon)
        #expect(workType.bounds.width <= card.bounds.width)
        #expect(scrollView.contentSize.width <= scrollView.bounds.width + 1)
    }

    @Test("Hourly row renders canonical paid duration")
    func hourlyRowRendersPaidDuration() throws {
        let breakdown = try hourlyBreakdown(
            day: 20,
            rate: 20,
            paidDuration: 7.5 * 3_600,
            basePay: 150
        )
        let viewController = try makeViewController(try makeComparison(
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

    @Test("Fractional paid duration renders without raw floating-point text")
    func fractionalDurationRendersHumanReadableText() throws {
        let breakdown = try hourlyBreakdown(
            day: 20,
            rate: 20,
            paidDuration: 54.974985003471375,
            basePay: 1
        )
        let viewController = try makeViewController(try makeComparison(
            expected: 1,
            actual: 1,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.duration",
            in: viewController.view
        )
        #expect(label.text == "55 \(PaycheckResultStrings.durationSecond)")
        #expect(label.text?.contains("54.974985") == false)
    }

    @Test("One-minute breakdown renders a carried minute")
    func oneMinuteBreakdownRendersMinute() throws {
        let breakdown = try hourlyBreakdown(
            day: 20,
            rate: 20,
            paidDuration: 60,
            basePay: 1
        )
        let viewController = try makeViewController(try makeComparison(
            expected: 1,
            actual: 1,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.duration",
            in: viewController.view
        )
        #expect(label.text == "1 \(PaycheckResultStrings.durationMinute)")
    }

    @Test("Breakdown metrics use horizontal label and value rows at normal content size")
    func breakdownMetricsUseHorizontalLayoutAtNormalContentSize() throws {
        let fixture = try makeHostedResultViewController(contentSizeCategory: .large)

        for identifier in ["duration", "rate", "amount"] {
            let metricRow = try requireMetricRow(identifier: identifier, in: fixture.result.view)
            let value: UILabel = try requireView(
                identifier: "paycheckResult.breakdown.row.0.\(identifier)",
                in: fixture.result.view
            )

            #expect(metricRow.axis == .horizontal)
            #expect(metricRow.alignment == .firstBaseline)
            #expect(metricRow.spacing == 12)
            #expect(value.textAlignment == .right)
        }
    }

    @Test("Breakdown metrics use vertical label and value rows at accessibility content size")
    func breakdownMetricsUseVerticalLayoutAtAccessibilityContentSize() throws {
        let fixture = try makeHostedResultViewController(contentSizeCategory: .accessibilityExtraExtraLarge)

        for identifier in ["duration", "rate", "amount"] {
            let metricRow = try requireMetricRow(identifier: identifier, in: fixture.result.view)
            let value: UILabel = try requireView(
                identifier: "paycheckResult.breakdown.row.0.\(identifier)",
                in: fixture.result.view
            )

            #expect(metricRow.axis == .vertical)
            #expect(metricRow.alignment == .fill)
            #expect(metricRow.spacing == 4)
            #expect(value.textAlignment == .natural)
        }
    }

    @Test("Accessibility metric layout gives duration value readable width below its label")
    func accessibilityMetricLayoutAvoidsPathologicalDurationWrapping() throws {
        let fixture = try makeHostedResultViewController(contentSizeCategory: .accessibilityExtraExtraLarge)
        let durationRow = try requireMetricRow(identifier: "duration", in: fixture.result.view)
        let duration: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.duration",
            in: fixture.result.view
        )
        let durationTitle = try #require(durationRow.arrangedSubviews.first as? UILabel)
        let rateRow = try requireMetricRow(identifier: "rate", in: fixture.result.view)

        let layoutEpsilon: CGFloat = 0.001
        #expect(duration.frame.minY + layoutEpsilon >= durationTitle.frame.maxY)
        #expect(duration.bounds.width > duration.font.lineHeight)
        #expect(duration.bounds.height <= duration.font.lineHeight * 1.5)
        #expect(duration.frame.maxY < rateRow.frame.minY)
    }

    @Test("Hourly row renders applied rate")
    func hourlyRowRendersAppliedRate() throws {
        let breakdown = try hourlyBreakdown(day: 20, rate: 20, basePay: 160)
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(expected: .zero, actual: 50))
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
        let viewController = try makeViewController(try makeComparison(expected: .zero, actual: 50))
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
        let viewController = try makeViewController(try makeComparison(expected: 160, actual: 150))
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
        let viewController = try makeViewController(try makeComparison(
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
        let viewController = try makeViewController(try makeComparison(
            expected: 160,
            actual: 150,
            breakdowns: [breakdown]
        ))
        viewController.loadViewIfNeeded()

        for identifier in [
            "paycheckResult.expected.label",
            "paycheckResult.actual.label",
            "paycheckResult.difference.label",
            "paycheckResult.breakdown.title",
            "paycheckResult.breakdown.row.0.workType",
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
        let viewController = try makeViewController(try makeComparison(
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
            "paycheckResult.breakdown.row.0.workType",
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
        let viewController = try makeViewController(try makeComparison(expected: 160, actual: 150))
        viewController.loadViewIfNeeded()

        let scrollView = try #require(firstDescendant(of: UIScrollView.self, in: viewController.view))

        #expect(scrollView.alwaysBounceVertical)
    }

    @Test("Summary preserves complete monetary strings across widths and traits", arguments: [320.0, 375.0, 402.0])
    func summaryMoneyFits(_ width: Double) throws {
        for language in ["ru_RU", "en_US"] {
            for appearance in [UIUserInterfaceStyle.light, .dark] {
                for raw in ["0", "4699.99", "4700", "4700.00000001", "123456.78", "1234567.89", "999999999999.99"] {
                    let actual = try #require(Decimal(string: raw, locale: locale))
                    let comparison = try makeComparison(expected: 4700, actual: actual)
                    let displayLocale = Locale(identifier: language)
                    let controller = PaycheckResultViewController(comparison: comparison,
                        currencyCode: "SEK", timeZoneIdentifier: "Europe/Stockholm", workTypes: [], displayLocale: displayLocale)
                    controller.overrideUserInterfaceStyle = appearance
                    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
                    window.rootViewController = controller
                    window.isHidden = false
                    defer { window.isHidden = true }
                    controller.loadViewIfNeeded()
                    let model = PaycheckResultFormatting.renderModel(comparison: comparison, currencyCode: "SEK",
                        timeZoneIdentifier: "Europe/Stockholm", workTypes: [], locale: displayLocale)
                    let labels: [UILabel] = try ["expected", "actual", "difference"].map {
                        try requireView(identifier: "paycheckResult.\($0).value", in: controller.view)
                    }
                    var normalFonts: [UIFont]?
                    for category in [UIContentSizeCategory.large, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge, .large] {
                        controller.traitOverrides.preferredContentSizeCategory = category
                        controller.view.setNeedsLayout()
                        window.layoutIfNeeded()
                        controller.view.layoutIfNeeded()
                        for (label, text) in zip(labels, [model.expected, model.actual, model.difference]) {
                            #expect(label.text == text)
                            #expect(label.accessibilityLabel == text)
                            let probe = UILabel()
                            probe.text = text
                            probe.font = label.font
                            let size = probe.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                               height: CGFloat.greatestFiniteMagnitude))
                            #expect(size.width <= label.bounds.width)
                            #expect(size.height <= label.bounds.height + 1)
                            #expect(label.font.pointSize >= 17)
                            let frame = label.convert(label.bounds, to: controller.view)
                            #expect(frame.minX >= 0 && frame.maxX <= width)
                        }
                        for pair in zip(labels, labels.dropFirst()) {
                            #expect(pair.0.convert(pair.0.bounds, to: controller.view).maxY <
                                    pair.1.convert(pair.1.bounds, to: controller.view).minY)
                        }
                        let fonts = try labels.map { try #require($0.font) }
                        if category == .large {
                            if let normalFonts { #expect(fonts == normalFonts) }
                            normalFonts = fonts
                        }
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        let repeatedFonts = try labels.map { try #require($0.font) }
                        #expect(repeatedFonts == fonts)
                        #expect(comparison.difference == actual - 4700)
                    }
                }
            }
        }
    }

    @Test("Supporting text preserves words and layout", arguments: [320.0, 375.0, 402.0])
    func explanationWrapsWords(_ width: Double) throws {
        let controller = try makeViewController(try makeComparison(expected: 4700, actual: 4700))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let label: UILabel = try requireView(identifier: "paycheckResult.explanation", in: controller.view)
        for language in ["ru", "en"] {
            let path = try #require(Bundle(for: ActualGrossEntryView.self).path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            for key in ["paycheckResult.equal", "paycheckResult.lower", "paycheckResult.higher"] {
                let text = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
                #expect(text != key)
                let root = try #require(controller.view as? PaycheckResultView)
                let expected: UILabel = try requireView(identifier: "paycheckResult.expected.value", in: root)
                let actual: UILabel = try requireView(identifier: "paycheckResult.actual.value", in: root)
                let difference: UILabel = try requireView(identifier: "paycheckResult.difference.value", in: root)
                root.render(.init(expected: expected.text ?? "", actual: actual.text ?? "",
                    difference: difference.text ?? "", explanation: text, breakdownRows: [], emptyBreakdownMessage: nil))
                for appearance in [UIUserInterfaceStyle.light, .dark] {
                    controller.overrideUserInterfaceStyle = appearance
                    var normalFont: UIFont?
                    for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
                        controller.traitOverrides.preferredContentSizeCategory = category
                        window.layoutIfNeeded()
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        #expect(label.text == text)
                        #expect(label.font.pointSize >= 17)
                        if category == .large {
                            #expect(label.font.fontName == UIFont.preferredFont(forTextStyle: .body,
                                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).fontName)
                            #expect(label.font.pointSize == 17)
                        }
                        let probe = UILabel()
                        probe.font = label.font
                        for word in text.split(whereSeparator: { $0.isWhitespace }) {
                            probe.text = String(word)
                            #expect(probe.sizeThatFits(CGSize(width: 10000, height: 10000)).width <= label.bounds.width)
                        }
                        #expect(label.sizeThatFits(CGSize(width: label.bounds.width, height: 10000)).height <= label.bounds.height + 1)
                        let attributed = try #require(label.attributedText)
                        let style = try #require(attributed.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
                        let storage = NSTextStorage(attributedString: attributed)
                        let manager = NSLayoutManager()
                        storage.addLayoutManager(manager)
                        let container = NSTextContainer(size: CGSize(width: label.bounds.width, height: 10000))
                        container.lineFragmentPadding = 0
                        manager.addTextContainer(container)
                        manager.ensureLayout(for: container)
                        let string = text as NSString
                        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, glyphs, _ in
                            let end = NSMaxRange(manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil))
                            if end > 0 && end < string.length {
                                let before = string.substring(with: NSRange(location: end - 1, length: 1))
                                let after = string.substring(with: NSRange(location: end, length: 1))
                                #expect(before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                        after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        if let stack = label.superview as? UIStackView,
                           let index = stack.arrangedSubviews.firstIndex(of: label),
                           index + 1 < stack.arrangedSubviews.count {
                            #expect(label.frame.maxY <= stack.arrangedSubviews[index + 1].frame.minY)
                        }
                        #expect(style.usesDefaultHyphenation == false)
                        #expect(label.numberOfLines == 0)
                        if category == .large {
                            if let normalFont { #expect(label.font == normalFont) }
                            normalFont = label.font
                        }
                        let bounds = label.bounds
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        #expect(label.bounds == bounds)
                    }
                }
            }
        }
    }


    @Test("Done geometry is recorded across repeated Dynamic Type cycles")
    func doneGeometryTransitions() throws {
        let controller = try makeViewController(try makeComparison(expected: 4700, actual: 4700))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let button: UIButton = try requireView(identifier: "paycheckResult.done", in: controller.view)
        var initial: CGFloat?
        for cycle in 0..<2 {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
                controller.traitOverrides.preferredContentSizeCategory = category
                for _ in 0..<5 {
                    window.layoutIfNeeded()
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                }
                let scroll = try #require(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
                print("SL529 DONE", cycle, category.rawValue, button.frame, button.bounds,
                      button.intrinsicContentSize, button.configuration?.contentInsets as Any,
                      button.layoutMargins, button.constraints, scroll.contentSize, scroll.contentOffset)
                if initial == nil { initial = button.bounds.height }
                if category == .large { #expect(button.bounds.height == initial) }
                #expect(button.bounds.height >= 50)
                #expect(button.bounds.width > 0)
            }
        }
    }

    private func makeViewController(
        _ comparison: PaycheckComparison,
        workTypeName: String? = "Lectures"
    ) throws -> PaycheckResultViewController {
        PaycheckResultViewController(
            comparison: comparison,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(name: workTypeName)],
            displayLocale: locale
        )
    }

    private func makeHostedResultViewController(
        contentSizeCategory: UIContentSizeCategory,
        workTypeName: String? = "Lectures"
    ) throws -> (host: UIViewController, result: PaycheckResultViewController) {
        let result = try makeViewController(try makeComparison(
            expected: 1,
            actual: 1,
            breakdowns: [try hourlyBreakdown(day: 20, rate: 20, paidDuration: 60, basePay: 1)]
        ), workTypeName: workTypeName)
        let host = UIViewController()
        host.loadViewIfNeeded()
        host.addChild(result)
        result.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        host.view.addSubview(result.view)
        result.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            result.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            result.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            result.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            result.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        result.didMove(toParent: host)
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return (host, result)
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
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
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

    private func workType(name: String? = "Lectures") throws -> WorkType {
        WorkType(
            id: testWorkTypeID,
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [PayRate(amount: 20, effectiveFrom: nil)])
        )
    }

    private func realDomainComparison() throws -> PaycheckComparison {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        let job = try Job(
            id: testWorkTypeID,
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
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
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

    private func requireMetricRow(identifier: String, in root: UIView) throws -> UIStackView {
        let value: UILabel = try requireView(
            identifier: "paycheckResult.breakdown.row.0.\(identifier)",
            in: root
        )
        return try #require(value.superview as? UIStackView)
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
