import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewViewControllerTests {
    private let displayLocale = Locale(identifier: "en_US_POSIX")

    @Test("Normal rail centers real periods without partial neighboring titles")
    func normalRailHasNoDuplicatePeriod() throws {
        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [
                makeShift(id: 1, month: 9, day: 10),
                makeShift(id: 2, month: 9, day: 11),
                makeShift(id: 3, month: 9, day: 12)
            ]
        )
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        let root = try requireRootView(subject.viewController)
        let fallback: UILabel = try requireView(identifier: "overview.period.label", in: root)
        #expect(isEffectivelyHidden(fallback))

        func expectRail() throws {
            window.layoutIfNeeded()
            root.layoutIfNeeded()
            let rail: UIScrollView = try requireView(identifier: "overview.period.rail", in: root)
            #expect(!isEffectivelyHidden(rail))
            let layoutEpsilon: CGFloat = 1
            let content = try requireContent(subject.viewModel.state)
            for (index, period) in content.railPeriods.enumerated() {
                let item: UIControl = try requireView(identifier: "overview.period.item.\(index)", in: rail)
                let title: UILabel = try requireView(identifier: "overview.period.item.title", in: item)
                let visibleTitleWidth = title.convert(title.bounds, to: rail)
                    .intersection(rail.bounds).width
                if period.period == content.selectedPeriod {
                    #expect(item.accessibilityTraits.contains(.selected))
                    #expect(item.backgroundColor == .clear)
                    #expect(item.layer.cornerRadius == 0)
                    #expect(item.bounds.height >= 44)
                    #expect(abs(item.convert(item.bounds, to: rail).midX - rail.bounds.midX) < layoutEpsilon)
                    #expect(visibleTitleWidth + layoutEpsilon >= title.bounds.width)
                } else {
                    #expect(!item.accessibilityTraits.contains(.selected))
                    #expect(
                        visibleTitleWidth <= layoutEpsilon
                            || visibleTitleWidth + layoutEpsilon >= title.bounds.width
                    )
                }
            }
        }

        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        let next: UIButton = try requireView(identifier: "overview.period.next", in: root)
        try expectRail()
        previous.sendActions(for: .touchUpInside)
        try expectRail()
        previous.sendActions(for: .touchUpInside)
        try expectRail()
        next.sendActions(for: .touchUpInside)
        try expectRail()
    }

    @Test("Accessibility period uses full-width text above navigation and reverses with traits")
    func accessibilityPeriodLayoutReverses() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let period: UILabel = try requireView(identifier: "overview.period.label", in: root)
        let rail: UIScrollView = try requireView(identifier: "overview.period.rail", in: root)
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        let next: UIButton = try requireView(identifier: "overview.period.next", in: root)
        #expect(isEffectivelyHidden(period))
        #expect(isEffectivelyHidden(rail) == false)

        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.layoutIfNeeded()
        root.layoutIfNeeded()
        #expect(isEffectivelyHidden(rail))
        #expect(isEffectivelyHidden(period) == false)
        let content = try requireContent(subject.viewModel.state)
        guard case let .scheduled(selectedPeriod)? = content.selectedPeriod else {
            throw OverviewControllerTestError.contentUnavailable
        }
        #expect(period.text == OverviewFormatting.scheduledPeriod(
            selectedPeriod,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(period.numberOfLines == 0)
        #expect(period.lineBreakMode == .byWordWrapping)
        let periodFrame = period.convert(period.bounds, to: window)
        let previousFrame = previous.convert(previous.bounds, to: window)
        let nextFrame = next.convert(next.bounds, to: window)
        let sectionWidth = try #require(period.superview?.bounds.width)
        #expect(period.bounds.width >= sectionWidth - 1)
        #expect(previousFrame.minY >= periodFrame.maxY)
        #expect(nextFrame.minY >= periodFrame.maxY)
        #expect(abs(previousFrame.midY - nextFrame.midY) < 1)
        #expect(previousFrame.maxX < nextFrame.minX)
        #expect(previous.bounds.width >= 44 && previous.bounds.height >= 44)
        #expect(next.bounds.width >= 44 && next.bounds.height >= 44)

        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        root.layoutIfNeeded()
        #expect(isEffectivelyHidden(period))
        #expect(isEffectivelyHidden(rail) == false)
        #expect(previous.isEnabled)
    }

    @Test("Per-shift navigation consumes no layout or accessibility space", arguments: [false, true])
    func perShiftNavigationIsAbsent(_ accessibilitySize: Bool) throws {
        let older = try makeShift(id: 1, month: 9, day: 10)
        let latest = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: makeJob(cycle: .perShift), shifts: [latest, older])
        subject.viewController.traitOverrides.preferredContentSizeCategory = accessibilitySize
            ? .accessibilityExtraExtraLarge : .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        root.layoutIfNeeded()
        let period: UILabel = try requireView(identifier: "overview.period.label", in: root)
        let container = try #require(period.superview as? UIStackView)
        #expect(container.isHidden)
        #expect(container.accessibilityElementsHidden)
        for identifier in ["overview.period.label", "overview.period.previous", "overview.period.rail", "overview.period.next"] {
            let element: UIView = try requireView(identifier: identifier, in: root)
            #expect(isEffectivelyHidden(element))
        }
        let receipt: UIView = try requireView(identifier: "overview.receipt.paper", in: root)
        let perShiftPeriod: UILabel = try requireView(identifier: "overview.receipt.perShiftPeriod", in: root)
        #expect(isEffectivelyHidden(perShiftPeriod) == false)
        #expect(perShiftPeriod.convert(perShiftPeriod.bounds, to: receipt).minY >= 0)
        #expect(shiftCardIdentifiers(in: root) == [latest.id, older.id])
        #expect(visibleFrontCardIdentifiers(in: root) == [latest.id])
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        #expect(count.text == "2")
        let content = try requireContent(subject.viewModel.state)
        #expect(content.selectedShiftID == latest.id)
        #expect(content.expandedShiftID == nil)
        if accessibilitySize {
            let cards: [UIView] = try [latest, older].map {
                try requireView(identifier: "overview.shift.\($0.id.uuidString)", in: root)
            }
            expectAccessibleDocumentOrder(cards, in: window)
        }
        subject.viewController.traitOverrides.preferredContentSizeCategory = accessibilitySize
            ? .large : .accessibilityExtraExtraLarge
        window.layoutIfNeeded()
        root.layoutIfNeeded()
        #expect(container.isHidden)
        #expect(container.accessibilityElementsHidden)
        #expect(isEffectivelyHidden(perShiftPeriod) == false)
        #expect(perShiftPeriod.convert(perShiftPeriod.bounds, to: receipt).minY >= 0)
    }

    @Test("Hero currency context and the single Shift heading are explicit")
    func heroAndShiftHeadingHaveOneHierarchy() throws {
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: [makeShift(id: 1, month: 9, day: 10)])
        subject.viewController.loadViewIfNeeded()
        let context: UILabel = try requireView(identifier: "overview.expectedGross.label", in: try requireRootView(subject.viewController))
        let amount: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: try requireRootView(subject.viewController))
        let heading: UIStackView = try requireView(identifier: "overview.shiftHistory.title", in: try requireRootView(subject.viewController))
        #expect(context.text == OverviewStrings.expectedGrossContext(currencyCode: "EUR"))
        #expect(amount.text == OverviewFormatting.heroAmount(160, currencyCode: "EUR", locale: displayLocale))
        #expect(heading.isAccessibilityElement)
        #expect(heading.accessibilityLabel == "\(OverviewStrings.allShiftHistory) 1")
        #expect(heading.arrangedSubviews.count == 2)
    }

    @Test("Content displays the expected gross")
    func contentDisplaysExpectedGross() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 10)
        let subject = try makeSubject(job: job, shifts: [shift])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: try requireRootView(subject.viewController)
        )
        #expect(label.text?.contains("160") == true)
        #expect(label.font.pointSize == ShiftLedgerTypography.expectedGrossDisplay.pointSize)
    }

    @Test("Receipt reconciles extra precision for the selected period, not global history")
    func receiptExplainsSelectedPeriodPrecision() throws {
        let rate = try #require(Decimal(string: "1.004"))
        let job = try Job(
            id: testWorkTypeID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .fixedPerShift,
            payCalculationCycle: .scheduled(.calendarMonthly),
            payRates: [try PayRate(amount: rate, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let september = try (1...12).map { try makeShift(id: UInt8($0), month: 9, day: $0) }
        let august = try makeShift(id: 99, month: 8, day: 31)
        let subject = try makeSubject(job: job, shifts: september + [august])
        subject.viewController.loadViewIfNeeded()
        let root = try requireRootView(subject.viewController)
        let hero: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let explanation: UILabel = try requireView(identifier: "overview.receipt.precision", in: root)
        let twelveAmount = try #require(Decimal(string: "12.048"))
        let exactTwelve = try #require(OverviewFormatting.exactCurrency(
            twelveAmount, currencyCode: "EUR", locale: displayLocale
        ))
        let exactOne = try #require(OverviewFormatting.exactCurrency(
            rate, currencyCode: "EUR", locale: displayLocale
        ))
        #expect(exactTwelve.contains("12.048"))
        #expect(exactOne.contains("1.004"))
        #expect(hero.text == "12.05")
        #expect(explanation.text == OverviewStrings.roundedForDisplay)
        let exactField: UILabel = try requireView(identifier: "overview.receipt.precision.exact", in: root)
        let displayedField: UILabel = try requireView(identifier: "overview.receipt.precision.displayed", in: root)
        #expect(exactField.text == exactTwelve)
        #expect(displayedField.text == OverviewFormatting.currency(twelveAmount, currencyCode: "EUR", locale: displayLocale))
        #expect(shiftCardIdentifiers(in: root).count == 13)
        let septemberCard: UIView = try requireView(
            identifier: "overview.shift.\(september[0].id.uuidString)", in: root
        )
        #expect(septemberCard.accessibilityLabel?.contains(exactOne) == true)

        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        previous.sendActions(for: .touchUpInside)
        #expect(hero.text == "1.00")
        #expect(isEffectivelyHidden(explanation)) // One rounded row already reconciles with the displayed total.
        #expect(shiftCardIdentifiers(in: root).count == 13)
        previous.sendActions(for: .touchUpInside)
        #expect(hero.text == "0.00")
        #expect(isEffectivelyHidden(explanation))
        #expect(shiftCardIdentifiers(in: root).count == 13)
    }

    @Test("Exact receipt currency preserves cents and mixed-rate contributions in English and Russian",
          arguments: ["en_US", "ru_RU"])
    func receiptExactCurrencyAndMixedRates(_ localeIdentifier: String) throws {
        let locale = Locale(identifier: localeIdentifier)
        let firstRate = try #require(Decimal(string: "1.004"))
        let secondRate = try #require(Decimal(string: "2.006"))
        let expectedTotal = try #require(Decimal(string: "3.010"))
        #expect(OverviewFormatting.exactCurrency(20, currencyCode: "EUR", locale: locale)
            == OverviewFormatting.currency(20, currencyCode: "EUR", locale: locale))
        let expectedFirst = localeIdentifier == "ru_RU" ? "1,004 €" : "€1.004"
        let expectedSecond = localeIdentifier == "ru_RU" ? "2,006 €" : "€2.006"
        #expect(OverviewFormatting.exactCurrency(firstRate, currencyCode: "EUR", locale: locale) == expectedFirst)
        #expect(OverviewFormatting.exactCurrency(secondRate, currencyCode: "EUR", locale: locale) == expectedSecond)
        for basis in [BasePayBasis.hourly, .fixedPerShift] {
            let job = try Job(
                id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                basePayBasis: basis, payCalculationCycle: .scheduled(.calendarMonthly),
                payRates: [
                    PayRate(amount: firstRate, effectiveFrom: nil),
                    PayRate(amount: secondRate, effectiveFrom: LocalDate(year: 2026, month: 9, day: 10))
                ],
                createdAt: Date(timeIntervalSinceReferenceDate: 0)
            )
            let shifts = try [(8, 31), (9, 1), (9, 15)].enumerated().map { index, day in
                let start = try date(year: 2026, month: day.0, day: day.1, hour: 8)
                return try Shift(
                    id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index))),
                    jobID: job.id, workTypeID: testWorkTypeID,
                    start: start, end: start.addingTimeInterval(3600)
                )
            }
            let period = try PayPeriod(
                start: LocalDate(year: 2026, month: 9, day: 1),
                endExclusive: LocalDate(year: 2026, month: 10, day: 1)
            )
            let breakdown = try job.expectedGrossBreakdown(for: .scheduled(period), from: shifts)
            #expect(breakdown.expectedGross == expectedTotal)
            #expect(breakdown.shiftBreakdowns.map(\.shift.id) == Array(shifts.dropFirst()).map(\.id))
            let cards = try OverviewShiftCardMapper(
                currencyCode: "EUR", timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale
            ).map(breakdown.shiftBreakdowns, selectedShiftID: nil, expandedShiftID: nil)
            #expect(cards.map(\.exactExpectedAmount) == [expectedSecond, expectedFirst])
            #expect(cards[0].appliedRate.hasPrefix(expectedSecond))
            #expect(cards[1].appliedRate.hasPrefix(expectedFirst))
            #expect(cards.map(\.appliedRateAmount) == [expectedSecond, expectedFirst])
            #expect(OverviewFormatting.displayedCurrencyValue(firstRate, currencyCode: "EUR", locale: locale) == 1)
        }
    }

    @Test("The continuous receipt paper adapts to light and dark appearance")
    func expectedGrossSurfaceAdaptsToAppearance() throws {
        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [makeShift(id: 1, month: 9, day: 10)]
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let paper: OverviewReceiptPaperView = try requireView(
            identifier: "overview.receipt.paper",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(paper) == false)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        #expect(OverviewReceiptPaperView.surface.resolvedColor(with: light)
            != OverviewReceiptPaperView.surface.resolvedColor(with: dark))
        let path = OverviewReceiptPaperView.paperPath(in: paper.bounds)
        #expect(!path.isEmpty)
        #expect(path.bounds.width == paper.bounds.width)
    }

    @Test("Torn contours are deterministic, distinct and independent of receipt height")
    func receiptTearContoursAreStableAndIrregular() throws {
        func points(_ height: CGFloat, width: CGFloat = 362) -> [CGPoint] {
            var result: [CGPoint] = []
            OverviewReceiptPaperView.paperPath(in: CGRect(x: 0, y: 0, width: width, height: height))
                .cgPath.applyWithBlock { element in
                    if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                        result.append(element.pointee.points[0])
                    }
                }
            return result
        }
        let original = points(540)
        #expect(original == points(540))
        let top = original.filter { $0.y < 10 }
        let bottom = original.filter { $0.y > 530 }.reversed().map { CGPoint(x: $0.x, y: 540 - $0.y) }
        #expect(top != bottom)
        #expect(Set(top.map(\.y)).count >= 4)
        let intervals = zip(top.dropFirst(), top).map { $0.x - $1.x }
        #expect(Set(intervals).count > 8)
        #expect(top.allSatisfy { (0...8).contains($0.y) })
        #expect(top == points(900).filter { $0.y < 10 })
        #expect(bottom == points(900).filter { $0.y > 890 }.reversed().map { CGPoint(x: $0.x, y: 900 - $0.y) })
        #expect(points(540, width: 335) != original)
    }

    @Test("Receipt metadata stacks label and full value at accessibility sizes")
    func receiptMetadataUsesVerticalAccessibilityLayout() throws {
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        let field = OverviewReceiptFieldView()
        field.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 40),
            field.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -40),
            field.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 80)
        ])
        field.update(label: OverviewStrings.exactContribution, value: "€1.004", identifier: "exact")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        #expect(field.traitCollection.preferredContentSizeCategory == .accessibilityExtraExtraLarge)
        #expect(field.axis == .vertical)
        #expect(field.value.text == "€1.004")
        #expect(field.label.frame.maxY <= field.value.frame.minY)
        #expect(field.value.frame.height >= field.value.sizeThatFits(
            CGSize(width: field.value.frame.width, height: .greatestFiniteMagnitude)).height - 0.5)
        host.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        #expect(field.axis == .horizontal)
        #expect(field.label.bounds.height <= field.label.font.lineHeight + 1)
        #expect(field.value.bounds.height <= field.value.font.lineHeight + 1)
    }

    @Test("Receipt rate separates its exact amount from pay basis at accessibility sizes",
          arguments: ["en_US", "ru_RU"])
    func receiptRateReflowsWithoutSplittingUnit(_ localeIdentifier: String) throws {
        let exactRate = try #require(Decimal(string: "1.004"))
        let amount = try #require(OverviewFormatting.exactCurrency(
            exactRate, currencyCode: "EUR", locale: Locale(identifier: localeIdentifier)))
        let fullRate = amount + " / " + PaycheckResultStrings.rateShift
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .large
        let field = OverviewReceiptFieldView()
        field.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 56),
            field.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -56),
            field.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 80)
        ])
        field.update(label: PaycheckResultStrings.rate, value: fullRate, identifier: "rate",
                     accessibilitySizeValue: amount)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        #expect(field.value.text == fullRate)
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.layoutIfNeeded()
        #expect(field.axis == .vertical)
        #expect(field.value.text == amount)
        #expect(field.accessibilityLabel == "\(PaycheckResultStrings.rate), \(fullRate)")
        #expect(field.label.frame.maxY <= field.value.frame.minY)
        #expect(field.value.frame.height <= field.value.font.lineHeight + 1)
        host.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        #expect(field.value.text == fullRate)
    }

    @Test("Receipt keeps a whole time range when the secondary fields need vertical reflow",
          arguments: [CGFloat(375), CGFloat(402)], [8, 11])
    func receiptTimeRangeReflowsAsAWhole(_ width: CGFloat, _ hour: Int) throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let start = try date(year: 2026, month: 9, day: 10, hour: hour)
        let shift = try Shift(id: UUID(), jobID: job.id, workTypeID: testWorkTypeID,
                              start: start, end: start.addingTimeInterval(3600))
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let time: UILabel = try requireView(identifier: "overview.shift.\(shift.id.uuidString).time", in: root)
        let duration: UILabel = try requireView(identifier: "overview.shift.\(shift.id.uuidString).duration", in: root)
        #expect(time.bounds.height <= time.font.lineHeight + 1)
        #expect(time.bounds.width + 0.5 >= (time.text ?? "").size(withAttributes: [.font: time.font as Any]).width)
        let durationFrame = duration.convert(duration.bounds, to: time)
        #expect(durationFrame.minY >= time.bounds.maxY - 0.5
                || durationFrame.minX >= time.bounds.maxX - 0.5)
    }

    @Test("Accessibility history heading wraps words without a detached separator",
          arguments: [CGFloat(375), CGFloat(402)])
    func receiptHistoryHeadingKeepsItsCountBelow(_ width: CGFloat) throws {
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)),
                                      shifts: [makeShift(id: 1, month: 9, day: 10)])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let heading: UILabel = try requireView(identifier: "overview.shiftCount.label", in: root)
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        #expect(heading.text == OverviewStrings.allShiftHistory)
        #expect(heading.text?.hasSuffix("·") == false)
        #expect(heading.bounds.width <= width - 80 + 0.5)
        #expect(heading.lineBreakMode == .byWordWrapping)
        #expect(heading.bounds.height + 0.5 >= heading.sizeThatFits(
            CGSize(width: heading.bounds.width, height: .greatestFiniteMagnitude)).height)
        #expect(heading.convert(heading.bounds, to: root).maxY <= count.convert(count.bounds, to: root).minY)
    }

    @Test("Receipt edge is one resizing silhouette with actions below the paper")
    func receiptEdgeResizesWithoutAccumulatingLayers() throws {
        let paper = OverviewReceiptPaperView(frame: CGRect(x: 0, y: 0, width: 362, height: 540))
        paper.layoutIfNeeded()
        let shape = try #require(paper.layer.sublayers?.first as? CAShapeLayer)
        #expect(paper.layer.sublayers?.count == 1)
        #expect(shape.path?.boundingBoxOfPath.width == 362)
        #expect((shape.path?.boundingBoxOfPath.height ?? 0) >= 528)
        paper.frame.size = CGSize(width: 335, height: 860)
        paper.layoutIfNeeded()
        #expect(paper.layer.sublayers?.count == 1)
        #expect(shape.path?.boundingBoxOfPath.width == 335)
        #expect((shape.path?.boundingBoxOfPath.height ?? 0) >= 848)
        #expect(shape.animationKeys()?.isEmpty != false)
        #expect(paper.isAccessibilityElement == false)

        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [makeShift(id: 1, month: 9, day: 10)]
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let receipt: UIView = try requireView(identifier: "overview.receipt.paper", in: root)
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        let add: UIButton = try requireView(identifier: "overview.addShift", in: root)
        let receiptFrame = receipt.convert(receipt.bounds, to: root)
        let checkFrame = check.convert(check.bounds, to: root)
        let addFrame = add.convert(add.bounds, to: root)
        #expect(receiptFrame.maxY <= checkFrame.minY)
        #expect(checkFrame.maxY <= addFrame.minY)
    }

    @Test("Receipt keeps its paper, columns and native actions inside wide and narrow viewports",
          arguments: [CGFloat(402), CGFloat(375)])
    func receiptMarginsMatchViewport(_ width: CGFloat) throws {
        let shift = try makeShift(id: 1, month: 9, day: 10)
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: width == 375 ? 667 : 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let paper: UIView = try requireView(identifier: "overview.receipt.paper", in: root)
        let row: UIView = try requireView(identifier: "overview.shift.\(shift.id.uuidString)", in: root)
        let paperFrame = paper.convert(paper.bounds, to: root)
        let rowFrame = row.convert(row.bounds, to: root)
        #expect(abs(paperFrame.minX - 20) < 0.5)
        #expect(abs(paperFrame.width - (width - 40)) < 0.5)
        #expect(abs(rowFrame.minX - 40) < 0.5)
        #expect(abs(rowFrame.width - (width - 80)) < 0.5)
        #expect(rowFrame.height >= 92)
        for identifier in ["overview.checkPaycheck", "overview.addShift"] {
            let button: UIButton = try requireView(identifier: identifier, in: root)
            let frame = button.convert(button.bounds, to: root)
            #expect(abs(frame.minX - 20) < 0.5)
            #expect(abs(frame.width - (width - 40)) < 0.5)
            #expect(frame.height >= 50)
        }
    }

    @Test("Tapping a scheduled rail item updates payroll while retaining global count and cards")
    func scheduledRailTapUpdatesVisibleContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [august, september])
        var receivedPeriod: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { receivedPeriod = $0 }
        subject.viewController.loadViewIfNeeded()
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [september.id, august.id])
        let railItem: UIControl = try requireView(
            identifier: "overview.period.item.0",
            in: try requireRootView(subject.viewController)
        )

        railItem.sendActions(for: .touchUpInside)

        let content = try requireContent(subject.viewModel.state)
        #expect(content.selectedPeriod == .scheduled(PayPeriod(
            start: try LocalDate(year: 2026, month: 8, day: 1),
            endExclusive: try LocalDate(year: 2026, month: 9, day: 1)
        )))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [august])
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [september.id, august.id])
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: try requireRootView(subject.viewController))
        #expect(count.text == "2")
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
        let selectedRailItem: UIControl = try requireView(
            identifier: "overview.period.item.1",
            in: try requireRootView(subject.viewController)
        )
        #expect(selectedRailItem.accessibilityTraits.contains(.selected))
        let checkPaycheck: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )
        checkPaycheck.sendActions(for: .touchUpInside)
        #expect(receivedPeriod == content.selectedPeriod)
    }

    @Test("Cross-period card selection preserves payroll destination and global visible history")
    func scheduledCrossPeriodCardKeepsPayrollDestination() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let original = try makeShift(id: 1, month: 8, day: 20)
        let older = try Shift(
            id: original.id, jobID: original.jobID, workTypeID: original.workTypeID,
            start: original.start, end: original.start.addingTimeInterval(4 * 60 * 60)
        )
        let newer = try makeShift(id: 2, month: 10, day: 10)
        let now = try date(year: 2026, month: 10, day: 18, hour: 12)
        let subject = makeSubject(job: job, loadShifts: { [newer, older] }, now: now)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        let root = try requireRootView(subject.viewController)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: root) == [newer.id])
        let initial = try requireContent(subject.viewModel.state)
        #expect(initial.expectedBreakdown?.expectedGross == Decimal(160))
        let card: UIControl = try requireView(identifier: "overview.shift.\(older.id.uuidString)", in: root)
        card.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: root) == [older.id])
        #expect(try requireContent(subject.viewModel.state).selectedPeriod == initial.selectedPeriod)
        #expect(try requireContent(subject.viewModel.state).expectedBreakdown == initial.expectedBreakdown)
        let amount: UILabel = try requireView(identifier: "overview.shift.\(older.id.uuidString).expected", in: root)
        #expect(amount.text == OverviewFormatting.currency(
            Decimal(80), currencyCode: job.currencyCode, locale: displayLocale
        ))
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        #expect(count.text == "2")
        var received: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { received = $0 }
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        check.sendActions(for: .touchUpInside)
        #expect(received == initial.selectedPeriod)
        let selected: UIControl = try requireView(identifier: "overview.shift.\(older.id.uuidString)", in: root)
        selected.sendActions(for: .touchUpInside)
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        previous.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        let content = try requireContent(subject.viewModel.state)
        #expect(content.expectedBreakdown?.expectedGross == .zero)
        #expect(content.selectedShiftID == older.id)
        #expect(content.expandedShiftID == older.id)
        #expect(visibleFrontCardIdentifiers(in: root) == [older.id])
        #expect(shiftCardIdentifiers(in: root) == [newer.id, older.id])
        #expect(count.text == "2")
        check.sendActions(for: .touchUpInside)
        #expect(received == content.selectedPeriod)
    }

    @Test("Content displays the selected scheduled period")
    func contentDisplaysScheduledPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.period.label",
            in: try requireRootView(subject.viewController)
        )
        #expect(label.text?.contains("Sep") == true)
        #expect(label.text?.contains("30") == true)
    }

    @Test("Scheduled Shift count represents all persisted Shifts")
    func shiftCountUsesAllPersistedShifts() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 10)
        let subject = try makeSubject(job: job, shifts: [august, september])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.shiftCount.value",
            in: try requireRootView(subject.viewController)
        )
        #expect(label.text == "2")
        let content = try requireContent(subject.viewModel.state)
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [august, september])
    }

    @Test("Shift history renders every persisted Shift in deterministic reverse chronology")
    func shiftHistoryRendersAllPersistedCardsInReverseChronology() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, month: 8, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])

        subject.viewController.loadViewIfNeeded()

        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])
        let newestRow: UIControl = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        newestRow.sendActions(for: .touchUpInside)

        let frontDate: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).date",
            in: try requireRootView(subject.viewController)
        )
        let amount: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).expected",
            in: try requireRootView(subject.viewController)
        )
        let duration: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).duration",
            in: try requireRootView(subject.viewController)
        )
        let endpoints: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        let endpointsStart: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).endpoints.start",
            in: try requireRootView(subject.viewController)
        )
        let endpointsEnd: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).endpoints.end",
            in: try requireRootView(subject.viewController)
        )
        #expect(frontDate.text == OverviewFormatting.frontShiftDate(
            newer,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(amount.text == OverviewFormatting.currency(
            Decimal(160),
            currencyCode: job.currencyCode,
            locale: displayLocale
        ))
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(newer.paidDuration)))
        let expectedEndpoints = try #require(OverviewFormatting.shiftEndpoints(
            newer,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(endpointsStart.text == expectedEndpoints.startTime)
        #expect(endpointsEnd.text == expectedEndpoints.endTime)
        #expect(isEffectivelyHidden(endpoints) == false)
        #expect(endpoints.isAccessibilityElement == false)
        #expect(descendant(identifier: "overview.shift.\(newer.id.uuidString).dateBadge", in: try requireRootView(subject.viewController)) == nil)
    }

    @Test("Each collapsed ledger row exposes its own date, time, amount and duration")
    func collapsedLedgerRowsPreserveShiftIdentity() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let card: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        let time: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).time",
            in: try requireRootView(subject.viewController)
        )
        let amount: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).expected",
            in: try requireRootView(subject.viewController)
        )
        let duration: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).duration",
            in: try requireRootView(subject.viewController)
        )
        let rate: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).detail.rate",
            in: try requireRootView(subject.viewController)
        )
        let date: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).date",
            in: try requireRootView(subject.viewController)
        )

        #expect(card.bounds.height >= 92)
        #expect(date.text == OverviewFormatting.frontShiftDate(
            older,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(time.text == OverviewFormatting.compactShiftTimeRange(
            older,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(amount.text == OverviewFormatting.currency(
            160, currencyCode: job.currencyCode, locale: displayLocale
        ))
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(older.paidDuration)))
        #expect(isEffectivelyHidden(rate))
        let endpoints: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(endpoints))
        for label in [date, time, amount, duration] {
            #expect(label.numberOfLines == 0)
            #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height)
        }
    }

    @Test("Ledger rows use a consistent 16-point content grid without overlap")
    func ledgerRowsUseCanonicalHorizontalInset() throws {
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [older, newer]
        )
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let covered: UIView = try requireView(identifier: "overview.shift.\(older.id.uuidString)", in: root)
        let coveredDate: UILabel = try requireView(identifier: "overview.shift.\(older.id.uuidString).date", in: root)
        let coveredAmount: UILabel = try requireView(identifier: "overview.shift.\(older.id.uuidString).expected", in: root)
        let front: UIView = try requireView(identifier: "overview.shift.\(newer.id.uuidString)", in: root)
        let frontDate: UILabel = try requireView(identifier: "overview.shift.\(newer.id.uuidString).date", in: root)
        let frontAmount: UILabel = try requireView(identifier: "overview.shift.\(newer.id.uuidString).expected", in: root)

        for (card, date, amount) in [(covered, coveredDate, coveredAmount), (front, frontDate, frontAmount)] {
            let dateFrame = date.convert(date.bounds, to: card)
            let amountFrame = amount.convert(amount.bounds, to: card)
            #expect(abs(dateFrame.minX - 16) <= 0.5)
            #expect(abs((card.bounds.maxX - amountFrame.maxX) - 16) <= 0.5)
            #expect(dateFrame.maxX <= amountFrame.minX)
            #expect(dateFrame.minX >= card.bounds.minX)
            #expect(dateFrame.maxX <= card.bounds.maxX)
            #expect(amountFrame.minX >= card.bounds.minX)
            #expect(amountFrame.maxX <= card.bounds.maxX)
        }
        #expect(front.convert(front.bounds, to: root).maxY <= covered.convert(covered.bounds, to: root).minY)
    }

    @Test("Visible Shift contribution labels share a trailing column")
    func shiftContributionAmountsUseTrailingAlignment() throws {
        let ids = [80, 81, 82].map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        let amounts = ["$6.00", "$10.00", "$100.00"]
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
        host.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        renderPresentationCards(
            ids: ids,
            selectedID: ids[2],
            expectedAmounts: amounts,
            in: view
        )
        window.layoutIfNeeded()

        let labels: [(card: UIView, date: UILabel, label: UILabel, amount: String)] = try [
            (
                requireView(identifier: "overview.shift.\(ids[0].uuidString)", in: view),
                requireView(identifier: "overview.shift.\(ids[0].uuidString).date", in: view),
                requireView(identifier: "overview.shift.\(ids[0].uuidString).expected", in: view),
                amounts[0]
            ),
            (
                requireView(identifier: "overview.shift.\(ids[1].uuidString)", in: view),
                requireView(identifier: "overview.shift.\(ids[1].uuidString).date", in: view),
                requireView(identifier: "overview.shift.\(ids[1].uuidString).expected", in: view),
                amounts[1]
            ),
            (
                requireView(identifier: "overview.shift.\(ids[2].uuidString)", in: view),
                requireView(identifier: "overview.shift.\(ids[2].uuidString).date", in: view),
                requireView(identifier: "overview.shift.\(ids[2].uuidString).expected", in: view),
                amounts[2]
            )
        ]

        let headerInsets = labels.map { card, date, label, _ in
            (
                amount: label.convert(label.bounds, to: card).minY,
                date: date.convert(date.bounds, to: card).minY
            )
        }

        for (card, date, label, amount) in labels {
            let amountFrame = label.convert(label.bounds, to: card)
            let dateFrame = date.convert(date.bounds, to: card)
            #expect(label.text == amount)
            #expect(label.textAlignment == .right)
            #expect(abs((card.bounds.maxX - amountFrame.maxX) - 16) <= 0.5)
            #expect(amountFrame.minX >= card.bounds.minX)
            #expect(amountFrame.maxX <= card.bounds.maxX)
            #expect(dateFrame.maxX <= amountFrame.minX)
        }

        let reference = headerInsets[0]
        for insets in headerInsets.dropFirst() {
            #expect(abs(insets.amount - reference.amount) <= 0.5)
            #expect(abs(insets.date - reference.date) <= 0.5)
        }
    }

    @Test("Every ledger row has independent details revealed only when expanded")
    func onlyExpandedLedgerRowShowsEndpoints() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.loadViewIfNeeded()

        let newerEndpoints: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        let olderEndpoints: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(newerEndpoints))
        #expect(isEffectivelyHidden(olderEndpoints))
        let olderRow: UIControl = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        olderRow.sendActions(for: .touchUpInside)
        olderRow.sendActions(for: .touchUpInside)
        #expect(isEffectivelyHidden(olderEndpoints) == false)
        #expect(isEffectivelyHidden(newerEndpoints))
    }

    @Test("Expanded ledger record has two readable endpoints and preserves break information",
          arguments: [false, true])
    func frontShiftEndpointsAdaptToContentSize(_ accessibilitySize: Bool) throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let start = try date(year: 2026, month: 9, day: 20, hour: 8)
        let shift = try Shift(
            jobID: job.id,
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * 60 * 60),
                end: start.addingTimeInterval(4.5 * 60 * 60)
            )
        )
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory =
            accessibilitySize ? .accessibilityExtraExtraExtraLarge : .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let prefix = "overview.shift.\(shift.id.uuidString)"
        let card: UIControl = try requireView(identifier: prefix, in: try requireRootView(subject.viewController))
        card.sendActions(for: .touchUpInside)
        card.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        let endpoints: UIView = try requireView(identifier: "\(prefix).endpoints", in: try requireRootView(subject.viewController))
        let startTime: UILabel = try requireView(identifier: "\(prefix).endpoints.start", in: endpoints)
        let endTime: UILabel = try requireView(identifier: "\(prefix).endpoints.end", in: endpoints)
        let startDate: UILabel = try requireView(identifier: "\(prefix).endpoints.startDate", in: endpoints)
        let endDate: UILabel = try requireView(identifier: "\(prefix).endpoints.endDate", in: endpoints)
        let duration: UILabel = try requireView(identifier: "\(prefix).duration", in: try requireRootView(subject.viewController))
        let unpaidBreak: UILabel = try requireView(identifier: "\(prefix).detail.break", in: try requireRootView(subject.viewController))

        #expect(descendant(identifier: "\(prefix).timeline", in: card) == nil)
        #expect(endpoints.isAccessibilityElement == false)
        #expect(isEffectivelyHidden(startDate))
        #expect(isEffectivelyHidden(endDate))
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(shift.paidDuration)))
        #expect(isEffectivelyHidden(duration) == false)
        #expect(unpaidBreak.text?.contains(OverviewFormatting.duration(30 * 60)) == true)
        #expect(card.accessibilityLabel?.contains(AddShiftStrings.unpaidBreak) == true)
        #expect(card.accessibilityLabel?.contains(OverviewFormatting.duration(shift.paidDuration)) == true)

        let startFrame = startTime.convert(startTime.bounds, to: endpoints)
        let endFrame = endTime.convert(endTime.bounds, to: endpoints)
        if accessibilitySize {
            #expect(startFrame.maxY < endFrame.minY)
        } else {
            #expect(startFrame.maxX < endFrame.minX)
            #expect(abs(startFrame.minY - endFrame.minY) < 0.5)
        }
        for label in [startTime, endTime, duration, unpaidBreak] {
            #expect(label.adjustsFontForContentSizeCategory)
            #expect(label.bounds.width > 0)
            #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height)
        }
        #expect(startTime.isAccessibilityElement == false)
        #expect(endTime.isAccessibilityElement == false)
    }

    @Test("Expanded ledger endpoints preserve local start and end times")
    func frontShiftEndpointsPreservesLocalDateTimeContext() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let start = try date(year: 2026, month: 9, day: 10, hour: 22)
        let overnight = try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            jobID: job.id,
            workTypeID: testWorkTypeID,
            start: start,
            end: try date(year: 2026, month: 9, day: 11, hour: 6)
        )
        let subject = try makeSubject(job: job, shifts: [overnight])
        subject.viewController.loadViewIfNeeded()
        let card: UIControl = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        card.sendActions(for: .touchUpInside)
        card.sendActions(for: .touchUpInside)

        let startTime: UILabel = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString).endpoints.start",
            in: try requireRootView(subject.viewController)
        )
        let endTime: UILabel = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString).endpoints.end",
            in: try requireRootView(subject.viewController)
        )
        let expectedEndpoints = try #require(OverviewFormatting.shiftEndpoints(
            overnight,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(startTime.text == expectedEndpoints.startTime)
        #expect(endTime.text == expectedEndpoints.endTime)
        let startDate: UILabel = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString).endpoints.startDate",
            in: try requireRootView(subject.viewController)
        )
        let endDate: UILabel = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString).endpoints.endDate",
            in: try requireRootView(subject.viewController)
        )
        #expect(startDate.text == expectedEndpoints.startDate)
        #expect(endDate.text == expectedEndpoints.endDate)
        #expect(isEffectivelyHidden(startDate) == false)
        #expect(isEffectivelyHidden(endDate) == false)
        let fullDate = try #require(OverviewFormatting.shiftDate(
            overnight,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        let fullTimeRange = try #require(OverviewFormatting.shiftTimeRange(
            overnight,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(card.accessibilityLabel?.contains(fullDate) == true)
        #expect(card.accessibilityLabel?.contains(fullTimeRange) == true)
    }

    @Test("Large ledger contribution grows without clipping or colliding with its date")
    func largeLedgerContributionCanGrowVertically() throws {
        let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        renderPresentationCards(
            ids: [id],
            selectedID: nil,
            expectedAmount: "€12,345,678.90",
            in: view
        )
        window.layoutIfNeeded()

        let amount: UILabel = try requireView(identifier: "overview.shift.\(id.uuidString).expected", in: view)
        let date: UILabel = try requireView(identifier: "overview.shift.\(id.uuidString).date", in: view)
        #expect(amount.numberOfLines == 0)
        #expect(amount.bounds.height + 0.5 >= amount.sizeThatFits(
            CGSize(width: amount.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        ).height)
        #expect(amount.convert(amount.bounds, to: view).minY >= date.convert(date.bounds, to: view).maxY)
    }

    @Test("Per-shift card selection drives payroll while retaining every persisted card")
    func perShiftPeriodSelectionKeepsAllPersistedCards() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.loadViewIfNeeded()

        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])
        let olderCard: UIControl = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        olderCard.sendActions(for: .touchUpInside)

        let content = try requireContent(subject.viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: older.id))
        #expect(content.selectedShiftID == older.id)
        #expect(content.expandedShiftID == nil)
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [older])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, newer])
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])
        let count: UILabel = try requireView(
            identifier: "overview.shiftCount.value",
            in: try requireRootView(subject.viewController)
        )
        #expect(count.text == "2")
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [older.id])
        var receivedPeriod: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { receivedPeriod = $0 }
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: try requireRootView(subject.viewController))
        check.sendActions(for: .touchUpInside)
        #expect(receivedPeriod == .perShift(shiftID: older.id))
        for expectedExpandedID in [older.id, nil] as [UUID?] {
            olderCard.sendActions(for: .touchUpInside)
            let updated = try requireContent(subject.viewModel.state)
            #expect(updated.expandedShiftID == expectedExpandedID)
            #expect(updated.selectedShiftID == older.id)
            #expect(updated.selectedPeriod == .perShift(shiftID: older.id))
            #expect(updated.expectedBreakdown == content.expectedBreakdown)
            check.sendActions(for: .touchUpInside)
            #expect(receivedPeriod == updated.selectedPeriod)
        }
    }

    @Test("Shift history renders an unpaid-break indicator only when the Shift contains one")
    func shiftHistoryRendersUnpaidBreakOnlyWhenPresent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let withoutBreak = try makeShift(id: 1, month: 9, day: 10)
        let start = try date(year: 2026, month: 9, day: 20, hour: 8)
        let withBreak = try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            jobID: job.id,
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(4 * 60 * 60),
                end: start.addingTimeInterval(4.5 * 60 * 60)
            )
        )
        let subject = try makeSubject(job: job, shifts: [withoutBreak, withBreak])

        subject.viewController.loadViewIfNeeded()
        let row: UIControl = try requireView(
            identifier: "overview.shift.\(withBreak.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        row.sendActions(for: .touchUpInside)
        row.sendActions(for: .touchUpInside)

        let breakLabel: UILabel = try requireView(
            identifier: "overview.shift.\(withBreak.id.uuidString).detail.break",
            in: try requireRootView(subject.viewController)
        )
        let absentBreakLabel: UILabel = try requireView(
            identifier: "overview.shift.\(withoutBreak.id.uuidString).detail.break",
            in: try requireRootView(subject.viewController)
        )
        #expect(breakLabel.isHidden == false)
        #expect(breakLabel.text?.contains(OverviewFormatting.duration(30 * 60)) == true)
        let withoutBreakRow: UIControl = try requireView(
            identifier: "overview.shift.\(withoutBreak.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        withoutBreakRow.sendActions(for: .touchUpInside)
        withoutBreakRow.sendActions(for: .touchUpInside)
        #expect(withoutBreakRow.accessibilityValue == OverviewStrings.expanded)
        #expect(isEffectivelyHidden(absentBreakLabel))
    }

    @Test("Post-save selected Shift card keeps its persisted identity and accessibility selection")
    func selectedShiftCardUsesPersistedIdentityAndAccessibilitySelection() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.loadViewIfNeeded()

        subject.viewController.reload(selectingShiftID: shift.id)

        let card: UIView = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        #expect(card.accessibilityTraits.contains(.selected))
        #expect(hasFixedHeight(card) == false)
    }

    @Test("Tapping a ledger row selects and expands only that persisted Shift")
    func ledgerRowTapControlsSingleExpandedDetail() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let middle = try makeShift(id: 2, month: 9, day: 15)
        let newer = try makeShift(id: 3, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, middle, newer])
        subject.viewController.loadViewIfNeeded()

        let newerRow: UIControl = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(newerRow) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id])

        let middleCard: UIControl = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        middleCard.sendActions(for: .touchUpInside)

        let middleDetail: UIView = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString).detail.paidTime",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(middleCard) == false)
        #expect(isEffectivelyHidden(newerRow) == false)
        #expect(isEffectivelyHidden(middleDetail))
        #expect(middleCard.accessibilityHint == OverviewStrings.expandShift)
        middleCard.sendActions(for: .touchUpInside)
        #expect(isEffectivelyHidden(middleDetail) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [middle.id])

        let olderCard: UIControl = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        olderCard.sendActions(for: .touchUpInside)

        let newerCard: UIControl = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(olderCard) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [older.id])
        #expect(olderCard.accessibilityTraits.contains(.selected))
        #expect(newerCard.accessibilityTraits.contains(.selected) == false)
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, middle.id, older.id])

        let olderDetail: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).detail.paidTime",
            in: try requireRootView(subject.viewController)
        )

        #expect(isEffectivelyHidden(olderDetail))
        #expect(isEffectivelyHidden(middleDetail))
        olderCard.sendActions(for: .touchUpInside)
        #expect(isEffectivelyHidden(olderDetail) == false)

        olderCard.sendActions(for: .touchUpInside)

        #expect(isEffectivelyHidden(olderDetail))
        #expect(olderCard.accessibilityTraits.contains(.selected))
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [older.id])
    }

    @Test("Expanded Shift exposes one Edit action without changing card tap behavior")
    func expandedShiftEditActionPreservesCardInteraction() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let card: UIControl = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        let editButton: UIButton = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString).edit",
            in: try requireRootView(subject.viewController)
        )
        #expect(editButton.isHidden)
        #expect(card.accessibilityCustomActions?.isEmpty != false)
        #expect(card.accessibilityTraits.contains(.button))
        #expect(card.accessibilityTraits.contains(.selected) == false)
        #expect(card.accessibilityHint == OverviewStrings.selectShift)

        card.sendActions(for: .touchUpInside)
        #expect(editButton.isHidden)
        #expect(card.accessibilityCustomActions?.isEmpty != false)
        #expect(card.accessibilityTraits.contains(.selected))
        #expect(card.accessibilityHint == OverviewStrings.expandShift)
        #expect(card.accessibilityValue == OverviewStrings.collapsed)
        card.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(card.accessibilityHint == OverviewStrings.collapseShift)
        #expect(card.accessibilityValue == OverviewStrings.expanded)
        #expect(editButton.isHidden == false)
        #expect(editButton.configuration?.title == OverviewStrings.editShift)
        #expect(editButton.bounds.height >= 44)
        #expect(card.accessibilityCustomActions?.map(\.name) == [OverviewStrings.editShift])

        let frontDate: UILabel = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString).date",
            in: try requireRootView(subject.viewController)
        )
        let headerFrame = frontDate.convert(frontDate.bounds, to: card)
        let editFrame = editButton.convert(editButton.bounds, to: card)
        #expect(abs(headerFrame.minY - 16) <= 0.5)
        #expect(abs((card.bounds.maxY - editFrame.maxY) - 16) <= 0.5)
        #expect(headerFrame.minY >= card.bounds.minY)
        #expect(editFrame.maxY <= card.bounds.maxY)

        var receivedShift: Shift?
        subject.viewController.onEditShift = { receivedShift = $0 }
        let editAction = try #require(card.accessibilityCustomActions?.first)
        let editActionTarget = try #require(editAction.target as? NSObject)
        _ = editActionTarget.perform(editAction.selector)
        #expect(receivedShift == shift)
        #expect(editButton.isHidden == false)

        receivedShift = nil
        editButton.sendActions(for: .touchUpInside)
        #expect(receivedShift == shift)
        #expect(isEffectivelyHidden(editButton) == false)

        let buttonCenter = editButton.convert(
            CGPoint(x: editButton.bounds.midX, y: editButton.bounds.midY),
            to: card
        )
        #expect(card.hitTest(buttonCenter, with: nil) === editButton)
        let ordinaryPoint = CGPoint(x: card.bounds.midX, y: 12)
        #expect(card.hitTest(ordinaryPoint, with: nil) === card)

        #expect(editButton.configuration?.image != nil)
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.layoutIfNeeded()
        #expect(editButton.configuration?.image == nil)
        #expect(editButton.configuration?.title == OverviewStrings.editShift)
        #expect(editButton.bounds.height >= 44)
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        #expect(editButton.configuration?.image != nil)

        card.sendActions(for: .touchUpInside)
        #expect(editButton.isHidden)
        #expect(card.accessibilityTraits.contains(.selected))
        #expect(card.accessibilityHint == OverviewStrings.expandShift)
        #expect(card.accessibilityValue == OverviewStrings.collapsed)
        #expect(card.accessibilityCustomActions?.isEmpty != false)
    }

    @Test("Each ledger record receives taps throughout its own nonoverlapping row")
    func ledgerRowsReceiveTouches() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let oldest = try makeShift(id: 1, month: 9, day: 10)
        let middle = try makeShift(id: 2, month: 9, day: 15)
        let newest = try makeShift(id: 3, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [oldest, middle, newest])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let deck: UIView = try requireView(identifier: "overview.shiftStack", in: try requireRootView(subject.viewController))
        let middleCard: UIControl = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        let oldestCard: UIControl = try requireView(
            identifier: "overview.shift.\(oldest.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )

        let middleHits = visibleSlicePoints(for: middleCard, in: deck).map {
            deck.hitTest($0, with: nil)
        }

        #expect(middleHits.allSatisfy { $0 === middleCard })
        middleCard.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [middle.id])

        let oldestHits = visibleSlicePoints(for: oldestCard, in: deck).map {
            deck.hitTest($0, with: nil)
        }

        #expect(oldestHits.allSatisfy { $0 === oldestCard })
        oldestCard.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [oldest.id])
    }

    @Test("Ledger rows remain separate at normal and accessibility content sizes")
    func ledgerRowsAdaptForAccessibilityContentSize() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shifts = try [
            makeShift(id: 1, month: 9, day: 10),
            makeShift(id: 2, month: 9, day: 15),
            makeShift(id: 3, month: 9, day: 20),
            makeShift(id: 4, month: 9, day: 21)
        ]
        let subject = try makeSubject(job: job, shifts: shifts)
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let cards: [UIView] = try shifts.reversed().map {
            try requireView(identifier: "overview.shift.\($0.id.uuidString)", in: try requireRootView(subject.viewController))
        }
        let deck: UIView = try requireView(identifier: "overview.shiftStack", in: try requireRootView(subject.viewController))
        expectLedgerRowsInOrder(cards, in: deck)

        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.layoutIfNeeded()
        try requireRootView(subject.viewController).layoutIfNeeded()
        expectAccessibleDocumentOrder(cards, in: window)
        expectLedgerRowsInOrder(cards, in: deck)
    }

    @Test("Receipt rows keep accessible identities and touch regions through expansion and scrolling", arguments: [false, true])
    func shiftAccessibilityRegionsFollowVisibleHierarchy(accessibleList: Bool) throws {
        let shifts = try [
            makeShift(id: 1, month: 9, day: 10),
            makeShift(id: 2, month: 9, day: 15),
            makeShift(id: 3, month: 9, day: 20)
        ]
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: shifts)
        subject.viewController.traitOverrides.preferredContentSizeCategory = accessibleList
            ? .accessibilityExtraExtraLarge : .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let deck: UIView = try requireView(identifier: "overview.shiftStack", in: root)
        let scroll: UIScrollView = try requireView(identifier: "overview.pageScroll", in: root)
        let cards: [UIControl] = try shifts.map {
            try requireView(identifier: "overview.shift.\($0.id.uuidString)", in: root)
        }

        func expectAccessibleRows() {
            #expect((deck.accessibilityElements ?? []).count == cards.count)
            for (index, card) in cards.enumerated() {
                #expect(card.isAccessibilityElement)
                #expect(card.accessibilityIdentifier == "overview.shift.\(shifts[index].id.uuidString)")
                #expect(card.accessibilityLabel?.contains(OverviewStrings.exactContribution) == false)
                #expect(card.accessibilityLabel?.contains(PaycheckResultStrings.shiftExpected) == true)
                #expect(card.bounds.width > 0)
                #expect(card.bounds.height >= 92)
                #expect(card.accessibilityTraits.contains(.button))
            }
            let ordered = cards.sorted { $0.frame.minY < $1.frame.minY }
            expectAccessibleDocumentOrder(ordered, in: window)
        }

        expectAccessibleRows()
        // Select another row, then expand and collapse it, retaining identity and order.
        for _ in 0..<3 {
            cards[1].sendActions(for: .touchUpInside)
            window.layoutIfNeeded()
            expectAccessibleRows()
        }

        let before = cards.map { $0.convert($0.bounds, to: window) }
        let offsetBefore = scroll.contentOffset
        scroll.setContentOffset(CGPoint(x: offsetBefore.x, y: offsetBefore.y + 40), animated: false)
        let delta = scroll.contentOffset.y - offsetBefore.y
        #expect(delta != 0)
        for (index, card) in cards.enumerated() {
            #expect(abs(card.convert(card.bounds, to: window).minY - (before[index].minY - delta)) < 0.5)
        }
        expectAccessibleRows()

        root.transform = CGAffineTransform(translationX: 13, y: 17)
        expectAccessibleRows()
    }

    @Test("Accessibility ledger rows place date and amount vertically without clipping")
    func accessibilityLedgerHeadingsUseFullWidth() throws {
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [older, newer]
        )
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let olderCard: UIView = try requireView(identifier: "overview.shift.\(older.id.uuidString)", in: root)
        let newerCard: UIView = try requireView(identifier: "overview.shift.\(newer.id.uuidString)", in: root)
        expectAccessibleDocumentOrder([newerCard, olderCard], in: window)
        let coveredDate: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).date", in: root
        )
        let frontDate: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).date", in: root
        )
        let coveredAmount: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).expected", in: root
        )
        let frontAmount: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).expected", in: root
        )
        for (date, amount) in [(coveredDate, coveredAmount), (frontDate, frontAmount)] {
            #expect(date.numberOfLines == 0)
            #expect(date.bounds.width > 0)
            #expect(date.bounds.height + 0.5 >= date.sizeThatFits(
                CGSize(width: date.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height)
            let dateFrame = date.convert(date.bounds, to: window)
            let amountFrame = amount.convert(amount.bounds, to: window)
            #expect(dateFrame.maxY <= amountFrame.minY)
        }
    }

    @Test("Accessibility Overview actions wrap and expanded Edit remains usable")
    func accessibilityActionsAndEditRemainReachable() throws {
        let shift = try makeShift(id: 1, month: 9, day: 20)
        let subject = try makeSubject(
            job: makeJob(cycle: .scheduled(.calendarMonthly)),
            shifts: [shift]
        )
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        let add: UIButton = try requireView(identifier: "overview.addShift", in: root)
        let card: UIControl = try requireView(identifier: "overview.shift.\(shift.id.uuidString)", in: root)
        let edit: UIButton = try requireView(identifier: "overview.shift.\(shift.id.uuidString).edit", in: root)

        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.layoutIfNeeded()
        root.layoutIfNeeded()
        for (button, title) in [(check, OverviewStrings.checkPaycheck), (add, OverviewStrings.addShift)] {
            let titleLabel = try #require(button.titleLabel)
            #expect(button.configuration?.title == title)
            #expect(titleLabel.numberOfLines == 0)
            #expect(titleLabel.lineBreakMode == .byWordWrapping)
            #expect(button.bounds.height >= 50)
            #expect(button.bounds.contains(titleLabel.convert(titleLabel.bounds, to: button)))
        }

        card.sendActions(for: .touchUpInside)
        #expect(isEffectivelyHidden(edit))
        card.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(isEffectivelyHidden(edit) == false)
        #expect(edit.configuration?.title == OverviewStrings.editShift)
        #expect(edit.titleLabel?.numberOfLines == 0)
        #expect(edit.titleLabel?.lineBreakMode == .byWordWrapping)
        #expect(edit.bounds.height >= 44)
        let editTitleLabel = try #require(edit.titleLabel)
        #expect(edit.bounds.contains(editTitleLabel.convert(editTitleLabel.bounds, to: edit)))
        #expect(card.accessibilityCustomActions?.map(\.name) == [OverviewStrings.editShift])
        let editFrame = edit.convert(edit.bounds, to: card)
        #expect(card.bounds.contains(editFrame))
        var receivedShift: Shift?
        subject.viewController.onEditShift = { receivedShift = $0 }
        edit.sendActions(for: .touchUpInside)
        #expect(receivedShift == shift)
    }

    @Test("One, two and three ledger records have full-width nonoverlapping rows")
    func ledgerUsesContentDrivenRowsForEachHistorySize() throws {
        for count in 1...3 {
            let ids = (1...count).map {
                UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
            }
            let view = OverviewView(frame: .zero)
            let host = UIViewController()
            host.view = view
            host.traitOverrides.preferredContentSizeCategory = .large
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.isHidden = false
            defer { window.isHidden = true }

            renderPresentationCards(ids: ids, selectedID: nil, in: view)
            window.layoutIfNeeded()

            let deck: UIView = try requireView(identifier: "overview.shiftStack", in: view)
            let cards: [UIView] = try ids.map {
                try requireView(identifier: "overview.shift.\($0.uuidString)", in: view)
            }

            expectLedgerRowsInOrder(cards, in: deck)
            #expect(cards.allSatisfy { $0.bounds.height >= 92 })
        }
    }

    @Test("Twelve ledger records scroll without overlap and keep both actions reachable")
    func twelveLedgerRowsScrollWithReachableActions() throws {
        let ids = (1...12).map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
        host.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        renderPresentationCards(ids: ids, selectedID: nil, in: view)
        window.layoutIfNeeded()
        let ledger: UIView = try requireView(identifier: "overview.shiftStack", in: view)
        let rows: [UIView] = try ids.map {
            try requireView(identifier: "overview.shift.\($0.uuidString)", in: view)
        }
        expectLedgerRowsInOrder(rows, in: ledger)
        #expect(shiftCardIdentifiers(in: view) == ids)

        let scroll: UIScrollView = try requireView(identifier: "overview.pageScroll", in: view)
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: view)
        let add: UIButton = try requireView(identifier: "overview.addShift", in: view)
        #expect(scroll.contentSize.height > scroll.bounds.height)
        #expect(isEffectivelyHidden(check) == false)
        #expect(check.bounds.height >= 50)
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
        window.layoutIfNeeded()
        let lastFrame = rows[11].convert(rows[11].bounds, to: window)
        let addFrame = add.convert(add.bounds, to: window)
        #expect(lastFrame.maxY <= addFrame.minY)
        #expect(addFrame.maxY <= window.bounds.maxY)
        #expect(add.bounds.height >= 50)

        renderPresentationCards(ids: ids, selectedID: ids[7], isExpanded: true, in: view)
        window.layoutIfNeeded()
        let edit: UIButton = try requireView(identifier: "overview.shift.\(ids[7].uuidString).edit", in: view)
        #expect(isEffectivelyHidden(edit) == false)
        #expect(edit.bounds.height >= 44)
        expectLedgerRowsInOrder(rows, in: ledger)
    }

    @Test("Selection highlights one ledger row without changing reverse-chronological order")
    func ledgerSelectionPreservesChronologicalOrder() throws {
        let ids = (1...4).map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
        host.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        renderPresentationCards(ids: ids, selectedID: nil, in: view)
        window.layoutIfNeeded()
        let cards: [UIView] = try ids.map {
            try requireView(identifier: "overview.shift.\($0.uuidString)", in: view)
        }
        let deck: UIView = try requireView(identifier: "overview.shiftStack", in: view)
        #expect(visibleFrontCardIdentifiers(in: view) == [ids[0]])
        expectLedgerRowsInOrder(cards, in: deck)

        renderPresentationCards(ids: ids, selectedID: ids[2], in: view)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: view) == [ids[2]])
        expectLedgerRowsInOrder(cards, in: deck)
        #expect(cards[2].accessibilityTraits.contains(.selected))
        #expect(cards[0].accessibilityTraits.contains(.selected) == false)

        renderPresentationCards(ids: ids, selectedID: UUID(), in: view)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: view) == [ids[0]])
        expectLedgerRowsInOrder(cards, in: deck)
    }

    @Test("All six Wada Shift surfaces have exact identical Light and Dark sRGB fills")
    func shiftSurfaceRolesHaveExactFills() throws {
        let expected: [(role: ShiftSurfaceRole, red: Int, green: Int, blue: Int)] = [
            (.ivoryBuff, 235, 211, 162),
            (.pistachioGreen, 100, 143, 123),
            (.salviaBlue, 151, 172, 200),
            (.seashellPink, 253, 212, 189),
            (.glaucousGreen, 180, 205, 194),
            (.cinnamonBuff, 253, 197, 126)
        ]
        #expect(ShiftSurfaceRole.allCases == expected.map { $0.role })
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let epsilon: CGFloat = 0.000001

        for entry in expected {
            let lightComponents = try colorComponents(ShiftLedgerColors.shiftSurface(for: entry.role), traits: light)
            let darkComponents = try colorComponents(ShiftLedgerColors.shiftSurface(for: entry.role), traits: dark)
            for components in [lightComponents, darkComponents] {
                #expect(abs(components.red - CGFloat(entry.red) / 255.0) < epsilon)
                #expect(abs(components.green - CGFloat(entry.green) / 255.0) < epsilon)
                #expect(abs(components.blue - CGFloat(entry.blue) / 255.0) < epsilon)
                #expect(abs(components.alpha - 1) < epsilon)
            }
            #expect(abs(lightComponents.red - darkComponents.red) < epsilon)
            #expect(abs(lightComponents.green - darkComponents.green) < epsilon)
            #expect(abs(lightComponents.blue - darkComponents.blue) < epsilon)
        }
    }

    @Test("Opaque Wada Shift foreground clears 4.5 to 1 contrast in both appearances")
    func shiftSurfaceForegroundContrast() throws {
        let epsilon: CGFloat = 0.000001
        for traits in [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(userInterfaceStyle: .dark)
        ] {
            for role in ShiftSurfaceRole.allCases {
                let surface = try colorComponents(ShiftLedgerColors.shiftSurface(for: role), traits: traits)
                let foreground = try colorComponents(ShiftLedgerColors.shiftForeground(for: role), traits: traits)
                #expect(abs(foreground.red - CGFloat(16) / 255.0) < epsilon)
                #expect(abs(foreground.green - CGFloat(19) / 255.0) < epsilon)
                #expect(abs(foreground.blue - CGFloat(21) / 255.0) < epsilon)
                #expect(abs(foreground.alpha - 1) < epsilon)
                let brighter = max(relativeLuminance(surface), relativeLuminance(foreground))
                let darker = min(relativeLuminance(surface), relativeLuminance(foreground))
                #expect((brighter + 0.05) / (darker + 0.05) >= 4.5)
            }
        }
    }

    @Test("Selected ledger row uses neutral surface and semantic text colors")
    func selectedLedgerRowUsesSemanticColors() throws {
        let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        renderPresentationCards(ids: [id], selectedID: id, isExpanded: true, in: view)
        window.layoutIfNeeded()

        let prefix = "overview.shift.\(id.uuidString)"
        let card: UIView = try requireView(identifier: prefix, in: view)
        let foreground = try colorComponents(ShiftLedgerColors.textPrimary, traits: window.traitCollection)
        let surface = try colorComponents(OverviewReceiptPaperView.selectedSurface, traits: window.traitCollection)
        let cardSurface = try colorComponents(try #require(card.backgroundColor), traits: window.traitCollection)
        #expect(abs(cardSurface.red - surface.red) < 0.000001)
        #expect(abs(cardSurface.green - surface.green) < 0.000001)
        #expect(abs(cardSurface.blue - surface.blue) < 0.000001)
        for identifier in [
            "\(prefix).date",
            "\(prefix).expected",
            "\(prefix).detail.rate",
            "\(prefix).endpoints.start"
        ] {
            let label: UILabel = try requireView(identifier: identifier, in: card)
            let color = try colorComponents(label.textColor, traits: window.traitCollection)
            #expect(abs(color.red - foreground.red) < 0.000001)
            #expect(abs(color.green - foreground.green) < 0.000001)
            #expect(abs(color.blue - foreground.blue) < 0.000001)
            #expect(abs(color.alpha - 1) < 0.000001)
        }
        let edit: UIButton = try requireView(identifier: "\(prefix).edit", in: card)
        #expect(edit.isHidden == false)
        let editColor = try colorComponents(
            try #require(edit.configuration?.baseForegroundColor),
            traits: window.traitCollection
        )
        let accent = try colorComponents(ShiftLedgerColors.accentPrimary, traits: window.traitCollection)
        #expect(abs(editColor.red - accent.red) < 0.000001)
        #expect(abs(editColor.green - accent.green) < 0.000001)
        #expect(abs(editColor.blue - accent.blue) < 0.000001)
        #expect(abs(editColor.alpha - 1) < 0.000001)
    }

    @Test("Adjacent Shift cards resolve deterministic nonrepeating decorative surfaces")
    func adjacentShiftSurfaceAssignmentIsStable() {
        let ids = [1, 7].map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }

        let firstAssignment = ShiftLedgerColors.shiftSurfaceRoles(for: ids)
        let secondAssignment = ShiftLedgerColors.shiftSurfaceRoles(for: ids)

        #expect(Set(ids.map(ShiftLedgerColors.stableSurfaceIndex(for:))).count == 1)
        #expect(firstAssignment == secondAssignment)
        #expect(ids.allSatisfy { (0...5).contains(ShiftLedgerColors.stableSurfaceIndex(for: $0)) })
        for (previousRole, currentRole) in zip(firstAssignment, firstAssignment.dropFirst()) {
            #expect(previousRole != currentRole)
        }
    }

    @Test("Prepending a Shift preserves existing decorative surface assignments")
    func prependingShiftPreservesExistingSurfaceAssignments() {
        let existingIDs = [1, 7].map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        let newNewestID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 37))
        let allIDs = [newNewestID] + existingIDs
        
        #expect(Set(allIDs.map(ShiftLedgerColors.stableSurfaceIndex(for:))).count == 1)

        let before = ShiftLedgerColors.shiftSurfaceRoles(for: existingIDs)
        let after = ShiftLedgerColors.shiftSurfaceRoles(for: allIDs)
        let beforeRolesByID = Dictionary(uniqueKeysWithValues: zip(existingIDs, before))
        let afterRolesByID = Dictionary(uniqueKeysWithValues: zip(allIDs, after))

        for id in existingIDs {
            #expect(afterRolesByID[id] == beforeRolesByID[id])
        }
        for (previousRole, currentRole) in zip(after, after.dropFirst()) {
            #expect(previousRole != currentRole)
        }
    }

    @Test("Scheduled zero-gross period retains persisted Shift history")
    func scheduledZeroGrossPeriodRetainsShiftHistory() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 8, day: 10)
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }

        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        #expect(root.traitCollection.preferredContentSizeCategory == .large)

        let label: UILabel = try requireView(
            identifier: "overview.shiftHistory.empty",
            in: root
        )
        #expect(isEffectivelyHidden(label))
        #expect(label.text == OverviewStrings.noSavedShifts)
        #expect(shiftCardIdentifiers(in: root) == [shift.id])
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        #expect(count.text == "1")
        let amount: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        #expect(amount.text == OverviewFormatting.heroAmount(.zero, currencyCode: job.currencyCode, locale: displayLocale))
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        #expect(check.isEnabled)
        #expect(!isEffectivelyHidden(check))
        let rail: UIScrollView = try requireView(identifier: "overview.period.rail", in: root)
        #expect(!isEffectivelyHidden(rail))
    }

    @Test("Per-shift post-save reload selects the persisted card and its paycheck period")
    func perShiftPostSaveReloadUpdatesCardAndPaycheck() throws {
        let existing = try makeShift(id: 1, month: 9, day: 10)
        let saved = try makeShift(id: 2, month: 9, day: 20)
        var calls = 0
        let subject = makeSubject(job: try makeJob(cycle: .perShift), loadShifts: {
            calls += 1
            return calls == 2 ? [existing, saved] : [existing]
        })
        subject.viewController.loadViewIfNeeded()
        subject.viewController.reload(selectingShiftID: saved.id)
        #expect(calls == 2)
        let content = try requireContent(subject.viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: saved.id))
        #expect(content.selectedShiftID == saved.id)
        #expect(content.expandedShiftID == nil)
        let root = try requireRootView(subject.viewController)
        #expect(visibleFrontCardIdentifiers(in: root) == [saved.id])
        var receivedPeriod: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { receivedPeriod = $0 }
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        check.sendActions(for: .touchUpInside)
        #expect(receivedPeriod == .perShift(shiftID: saved.id))
        subject.viewController.reload()
        let fallback = try requireContent(subject.viewModel.state)
        #expect(fallback.selectedShiftID == existing.id)
        #expect(fallback.expandedShiftID == nil)
        #expect(visibleFrontCardIdentifiers(in: root) == [existing.id])
        #expect(shiftCardIdentifiers(in: root) == [existing.id])
    }

    @Test("Previous button follows ViewModel navigation state")
    func previousButtonUsesViewModelState() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: try requireRootView(subject.viewController)
        )
        #expect(button.isEnabled)
    }

    @Test("Next button follows ViewModel navigation state")
    func nextButtonUsesViewModelState() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.period.next",
            in: try requireRootView(subject.viewController)
        )
        #expect(button.isEnabled == false)
    }

    @Test("Previous tap navigates and rerenders")
    func previousTapNavigatesAndRerenders() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.loadViewIfNeeded()
        let label: UILabel = try requireView(
            identifier: "overview.period.label",
            in: try requireRootView(subject.viewController)
        )
        let initialText = label.text
        let button: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: try requireRootView(subject.viewController)
        )

        button.sendActions(for: .touchUpInside)

        #expect(label.text != initialText)
        #expect(label.text?.contains("Aug") == true)
        let nextButton: UIButton = try requireView(
            identifier: "overview.period.next",
            in: try requireRootView(subject.viewController)
        )
        #expect(nextButton.isEnabled)
    }

    @Test("Next tap navigates toward current period and rerenders")
    func nextTapNavigatesAndRerenders() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.loadViewIfNeeded()
        let label: UILabel = try requireView(
            identifier: "overview.period.label",
            in: try requireRootView(subject.viewController)
        )
        let initialText = label.text
        let previousButton: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: try requireRootView(subject.viewController)
        )
        let nextButton: UIButton = try requireView(
            identifier: "overview.period.next",
            in: try requireRootView(subject.viewController)
        )
        previousButton.sendActions(for: .touchUpInside)

        nextButton.sendActions(for: .touchUpInside)

        #expect(label.text == initialText)
        #expect(nextButton.isEnabled == false)
    }

    @Test("Add Shift action is forwarded exactly once")
    func addShiftActionIsForwarded() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        var callCount = 0
        subject.viewController.onAddShift = { callCount += 1 }
        subject.viewController.loadViewIfNeeded()
        let button: UIButton = try requireView(
            identifier: "overview.addShift",
            in: try requireRootView(subject.viewController)
        )

        button.sendActions(for: .touchUpInside)

        #expect(callCount == 1)
    }

    @Test("Overview устанавливает меню Work types в navigation bar")
    func installsWorkTypesMenu() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let item = try #require(subject.viewController.navigationItem.rightBarButtonItem)
        #expect(item.accessibilityIdentifier == "overview.more")
        #expect(item.image == UIImage(systemName: "ellipsis.circle"))
        let menu = try #require(item.menu)
        #expect(menu.children.count == 2)
        #expect(menu.children.first?.title == OverviewStrings.workTypes)
        #expect(menu.children.map(\.title).contains(OverviewStrings.workTypes))
        #expect(menu.children.map(\.title).contains(OverviewStrings.archivedJobs))
    }

    @Test("Check Paycheck forwards the selected Domain period")
    func checkPaycheckForwardsSelectedPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        var receivedPeriod: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { receivedPeriod = $0 }
        subject.viewController.loadViewIfNeeded()
        let expectedPeriod = try requireContent(subject.viewModel.state).selectedPeriod
        let button: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )

        button.sendActions(for: .touchUpInside)

        #expect(receivedPeriod == expectedPeriod)
    }

    @Test("Scheduled zero-shift period keeps Check Paycheck available")
    func zeroShiftScheduledPeriodCanCheckPaycheck() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(button) == false)
        #expect(button.isEnabled)
    }

    @Test("Per-shift no-data content renders the empty state")
    func perShiftNoDataRendersEmptyState() throws {
        let job = try makeJob(cycle: .perShift)
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        let container: UIView = try requireView(
            identifier: "overview.empty.container",
            in: try requireRootView(subject.viewController)
        )
        let title: UILabel = try requireView(
            identifier: "overview.empty.title",
            in: try requireRootView(subject.viewController)
        )
        let addButton: UIButton = try requireView(
            identifier: "overview.addShift",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(container) == false)
        #expect(title.text == OverviewStrings.emptyTitle)
        #expect(isEffectivelyHidden(addButton) == false)
        let root = try requireRootView(subject.viewController)
        let paper: OverviewReceiptPaperView = try requireView(identifier: "overview.receipt.paper", in: root)
        let gross: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        #expect(isEffectivelyHidden(paper) == false)
        #expect(paper.bounds.height > 12)
        #expect(paper.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.count == 1)
        #expect(isEffectivelyHidden(gross)) // No fictional payroll amount without a PerShift selection.
        #expect(paper.convert(paper.bounds, to: root).maxY < addButton.convert(addButton.bounds, to: root).minY)
    }

    @Test("Per-shift empty state gives Add Shift primary emphasis")
    func perShiftEmptyStateUsesPrimaryAddShiftButton() throws {
        let job = try makeJob(cycle: .perShift)
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.addShift",
            in: try requireRootView(subject.viewController)
        )
        #expect(button.configuration?.baseBackgroundColor == ShiftLedgerColors.accentPrimary)
        #expect(button.configuration?.cornerStyle == .large)
    }

    @Test("Content state keeps Check Paycheck primary and Add Shift secondary")
    func contentStateUsesDistinctActionEmphasis() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let checkPaycheck: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )
        let addShift: UIButton = try requireView(
            identifier: "overview.addShift",
            in: try requireRootView(subject.viewController)
        )
        #expect(checkPaycheck.configuration?.baseBackgroundColor == ShiftLedgerColors.accentPrimary)
        #expect(addShift.configuration?.background.backgroundColor == ShiftLedgerColors.backgroundSecondary)
        #expect(addShift.configuration?.baseForegroundColor == ShiftLedgerColors.accentPrimary)
    }

    @Test("Check Paycheck is unavailable in per-shift empty state")
    func perShiftEmptyStateCannotCheckPaycheck() throws {
        let job = try makeJob(cycle: .perShift)
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(button))
    }

    @Test("Loading failure renders presentation-safe copy")
    func loadingFailureRendersCopy() throws {
        let job = try makeJob(cycle: .perShift)
        let subject = makeSubject(
            job: job,
            loadShifts: { throw OverviewControllerTestError.loading }
        )

        subject.viewController.loadViewIfNeeded()

        let title: UILabel = try requireView(
            identifier: "overview.error.title",
            in: try requireRootView(subject.viewController)
        )
        let message: UILabel = try requireView(
            identifier: "overview.error.message",
            in: try requireRootView(subject.viewController)
        )
        #expect(title.text == OverviewStrings.loadingErrorTitle)
        #expect(message.text == OverviewStrings.loadingErrorMessage)
    }

    @Test("Calculation failure renders presentation-safe copy")
    func calculationFailureRendersCopy() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(
            job: job,
            shifts: [],
            presentationTimeZoneIdentifier: "Invalid/TimeZone"
        )

        subject.viewController.loadViewIfNeeded()

        let title: UILabel = try requireView(
            identifier: "overview.error.title",
            in: try requireRootView(subject.viewController)
        )
        let message: UILabel = try requireView(
            identifier: "overview.error.message",
            in: try requireRootView(subject.viewController)
        )
        #expect(title.text == OverviewStrings.calculationErrorTitle)
        #expect(message.text == OverviewStrings.calculationErrorMessage)
    }

    @Test("Retry reloads after failure and recovers to content")
    func retryRecoversToContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        var loadCalls = 0
        let subject = makeSubject(
            job: job,
            loadShifts: {
                loadCalls += 1
                if loadCalls == 1 {
                    throw OverviewControllerTestError.loading
                }
                return []
            }
        )
        subject.viewController.loadViewIfNeeded()
        let retryButton: UIButton = try requireView(
            identifier: "overview.error.retry",
            in: try requireRootView(subject.viewController)
        )

        retryButton.sendActions(for: .touchUpInside)

        let errorContainer: UIView = try requireView(
            identifier: "overview.error.container",
            in: try requireRootView(subject.viewController)
        )
        let amount: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: try requireRootView(subject.viewController)
        )
        #expect(loadCalls == 2)
        #expect(isEffectivelyHidden(errorContainer))
        #expect(isEffectivelyHidden(amount) == false)
    }

    @Test("reload invokes ViewModel reload and rerenders")
    func reloadRefreshesRenderedContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 10)
        var loadCalls = 0
        let subject = makeSubject(
            job: job,
            loadShifts: {
                loadCalls += 1
                return loadCalls == 1 ? [] : [shift]
            }
        )
        subject.viewController.loadViewIfNeeded()
        let countLabel: UILabel = try requireView(
            identifier: "overview.shiftCount.value",
            in: try requireRootView(subject.viewController)
        )
        #expect(countLabel.text == "0")

        subject.viewController.reload()

        #expect(loadCalls == 2)
        #expect(countLabel.text == "1")
    }

    @Test("Accessibility amount and period receive enough height for their text")
    func labelsSupportAccessibilityContentSizes() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        try requireRootView(subject.viewController).setNeedsLayout()
        window.layoutIfNeeded()
        try requireRootView(subject.viewController).layoutIfNeeded()
        let amount: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: try requireRootView(subject.viewController)
        )
        let period: UILabel = try requireView(
            identifier: "overview.period.label",
            in: try requireRootView(subject.viewController)
        )

        #expect(amount.adjustsFontForContentSizeCategory)
        #expect(period.adjustsFontForContentSizeCategory)
        #expect(amount.numberOfLines == 0)
        #expect(period.numberOfLines == 0)
        let rail: UIScrollView = try requireView(identifier: "overview.period.rail", in: try requireRootView(subject.viewController))
        #expect(isEffectivelyHidden(rail))
        for label in [amount, period] {
            #expect(label.traitCollection.preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge)
            #expect(isEffectivelyHidden(label) == false)
            try #require(label.text?.isEmpty == false)
            try #require(label.bounds.width > 0)
            let requiredHeight = label.sizeThatFits(
                CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height
            try #require(requiredHeight > 0)
            #expect(label.bounds.height + 0.5 >= requiredHeight)
        }
    }

    @Test("Core buttons have stable accessibility labels, identifiers, and sizes")
    func buttonsExposeAccessibilityContract() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.loadViewIfNeeded()
        let previous: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: try requireRootView(subject.viewController)
        )
        let next: UIButton = try requireView(
            identifier: "overview.period.next",
            in: try requireRootView(subject.viewController)
        )
        let check: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: try requireRootView(subject.viewController)
        )
        let add: UIButton = try requireView(
            identifier: "overview.addShift",
            in: try requireRootView(subject.viewController)
        )

        #expect(previous.accessibilityLabel == OverviewStrings.previousPeriod)
        #expect(next.accessibilityLabel == OverviewStrings.nextPeriod)
        #expect(check.accessibilityLabel == OverviewStrings.checkPaycheck)
        #expect(add.accessibilityLabel == OverviewStrings.addShift)
        #expect(hasMinimumSize(previous, 44))
        #expect(hasMinimumSize(next, 44))
        #expect(hasMinimumHeight(check, 50))
        #expect(hasMinimumHeight(add, 50))
    }

    private func makeSubject(
        job: Job,
        shifts: [Shift],
        presentationTimeZoneIdentifier: String? = nil
    ) throws -> Subject {
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        return makeSubject(
            job: job,
            loadShifts: { shifts },
            now: now,
            presentationTimeZoneIdentifier: presentationTimeZoneIdentifier
        )
    }

    private func makeSubject(
        job: Job,
        loadShifts: @escaping @MainActor () throws -> [Shift],
        now: Date? = nil,
        presentationTimeZoneIdentifier: String? = nil
    ) -> Subject {
        let currentDate = now ?? Date(timeIntervalSince1970: 1_789_730_400)
        let viewModel = OverviewViewModel(
            job: job,
            loadShifts: loadShifts,
            currentDate: { currentDate }
        )
        let viewController = OverviewViewController(
            viewModel: viewModel,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: presentationTimeZoneIdentifier ?? job.timeZoneIdentifier,
            displayLocale: displayLocale
        )
        return Subject(viewController: viewController, viewModel: viewModel)
    }

    private func makeJob(cycle: PayCalculationCycle) throws -> Job {
        try Job(
            id: testWorkTypeID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: cycle,
            payRates: [try PayRate(amount: 20, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift(id: UInt8, month: Int, day: Int) throws -> Shift {
        let start = try date(year: 2026, month: month, day: day, hour: 8)
        return try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
            jobID: testWorkTypeID,
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60)
        )
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        return try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }

    private func requireContent(
        _ state: OverviewViewModel.State
    ) throws -> OverviewViewModel.Content {
        guard case let .content(content) = state else {
            throw OverviewControllerTestError.contentUnavailable
        }
        return content
    }

    private func requireView<View: UIView>(
        identifier: String,
        in rootView: UIView
    ) throws -> View {
        try #require(descendant(identifier: identifier, in: rootView) as? View)
    }

    private func requireRootView(
        _ viewController: UIViewController
    ) throws -> UIView {
        viewController.loadViewIfNeeded()
        return try #require(viewController.view)
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

    private func shiftCardIdentifiers(in view: UIView) -> [UUID] {
        let identifierPrefix = "overview.shift."
        guard let deck = descendant(identifier: "overview.shiftStack", in: view) else {
            return []
        }

        return (deck.accessibilityElements ?? []).compactMap { element in
            guard let card = element as? UIView,
                  let identifier = card.accessibilityIdentifier,
                  identifier.hasPrefix(identifierPrefix) else {
                return nil
            }
            return UUID(uuidString: String(identifier.dropFirst(identifierPrefix.count)))
        }
    }

    private func visibleFrontCardIdentifiers(in view: UIView) -> [UUID] {
        let ids = shiftCardIdentifiers(in: view)
        let selected = ids.first { id in
            descendant(identifier: "overview.shift.\(id.uuidString)", in: view)?
                .accessibilityTraits.contains(.selected) == true
        }
        return [selected ?? ids.first].compactMap { $0 }
    }

    private func visibleSlicePoints(for card: UIView, in deck: UIView) -> [CGPoint] {
        let cardFrame = card.convert(card.bounds, to: deck)
        let nextCardTop = deck.subviews
            .filter { $0 !== card }
            .map { $0.convert($0.bounds, to: deck).minY }
            .filter { $0 > cardFrame.minY }
            .min() ?? cardFrame.maxY
        let visibleHeight = nextCardTop - cardFrame.minY
        return [0.15, 0.5, 0.85].map {
            CGPoint(x: cardFrame.midX, y: cardFrame.minY + visibleHeight * $0)
        }
    }

    private func expectLedgerRowsInOrder(_ cards: [UIView], in ledger: UIView) {
        guard let first = cards.first else { return }
        let firstFrame = first.convert(first.bounds, to: ledger)
        #expect(abs(firstFrame.minY - ledger.bounds.minY) < 0.5)
        for card in cards {
            let frame = card.convert(card.bounds, to: ledger)
            #expect(abs(frame.minX - ledger.bounds.minX) < 0.5)
            #expect(abs(frame.maxX - ledger.bounds.maxX) < 0.5)
            // Coordinate conversion subtracts large origins and can lose subpixel precision.
            #expect(card.bounds.height >= 92)
        }
        for (current, next) in zip(cards, cards.dropFirst()) {
            let currentFrame = current.convert(current.bounds, to: ledger)
            let nextFrame = next.convert(next.bounds, to: ledger)
            #expect(abs(currentFrame.maxY - nextFrame.minY) < 0.5)
        }
        let last = cards[cards.count - 1]
        let lastFrame = last.convert(last.bounds, to: ledger)
        #expect(abs(lastFrame.maxY - ledger.bounds.maxY) < 0.5)
    }

    private func expectAccessibleDocumentOrder(_ cards: [UIView], in window: UIWindow) {
        for (first, second) in zip(cards, cards.dropFirst()) {
            let firstFrame = first.convert(first.bounds, to: window)
            let secondFrame = second.convert(second.bounds, to: window)
            #expect(firstFrame.maxY <= secondFrame.minY + 0.5)
        }
    }

    private func renderPresentationCards(
        ids: [UUID],
        selectedID: UUID?,
        expectedAmount: String = "€160",
        expectedAmounts: [String] = [],
        isExpanded: Bool = false,
        in view: OverviewView
    ) {
        let cards = ids.enumerated().map { index, id in
            OverviewView.ShiftCard(
                id: id,
                frontDate: "Sep 14",
                timeRange: "8:00 AM–4:00 PM",
                endpoints: OverviewFormatting.ShiftEndpoints(
                    startTime: "8:00 AM",
                    endTime: "4:00 PM",
                    startDate: nil,
                    endDate: nil
                ),
                expectedAmount: expectedAmounts.indices.contains(index) ? expectedAmounts[index] : expectedAmount,
                exactExpectedAmount: nil,
                paidDuration: "8h",
                unpaidBreak: nil,
                unpaidBreakTimeRange: nil,
                appliedRate: "€20 / h",
                appliedRateAmount: "€20",
                payBasis: "Hourly",
                isSelected: id == selectedID,
                isExpanded: isExpanded && id == selectedID,
                accessibilityLabel: "Shift"
            )
        }
        view.renderContent(
            expectedGross: "€640",
            expectedGrossContext: "Expected gross · EUR",
            period: "September 2026",
            periodItems: [],
            showPeriodNavigation: false,
            shiftCount: cards.count,
            shiftCards: cards,
            canNavigatePrevious: true,
            canNavigateNext: false,
            canCheckPaycheck: true
        )
    }

    private func isEffectivelyHidden(_ view: UIView) -> Bool {
        var candidate: UIView? = view
        while let current = candidate {
            if current.isHidden {
                return true
            }
            candidate = current.superview
        }
        return false
    }

    private func colorComponents(
        _ color: UIColor,
        traits: UITraitCollection
    ) throws -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.resolvedColor(with: traits).getRed(
            &red, green: &green, blue: &blue, alpha: &alpha
        ) else {
            throw OverviewControllerTestError.colorComponentsUnavailable
        }
        return (red, green, blue, alpha)
    }

    private func relativeLuminance(
        _ color: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)
    ) -> Double {
        func linearized(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }

    private func hasFixedHeight(_ view: UIView) -> Bool {
        view.constraints.contains {
            $0.firstAttribute == .height && $0.relation == .equal
        }
    }

    private func hasMinimumSize(_ view: UIView, _ minimum: CGFloat) -> Bool {
        hasMinimumHeight(view, minimum) && view.constraints.contains {
            $0.firstAttribute == .width
                && $0.relation == .greaterThanOrEqual
                && $0.constant >= minimum
        }
    }

    private func hasMinimumHeight(_ view: UIView, _ minimum: CGFloat) -> Bool {
        view.constraints.contains {
            $0.firstAttribute == .height
                && $0.relation == .greaterThanOrEqual
                && $0.constant >= minimum
        }
    }
}

private struct Subject {
    let viewController: OverviewViewController
    let viewModel: OverviewViewModel
}

private enum OverviewControllerTestError: Error {
    case loading
    case contentUnavailable
    case colorComponentsUnavailable
}
