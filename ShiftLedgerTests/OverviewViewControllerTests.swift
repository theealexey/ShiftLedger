import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewViewControllerTests {
    private let displayLocale = Locale(identifier: "en_US_POSIX")

    @Test("Normal rail centers real periods without partial neighboring titles")
    func normalRailHasNoDuplicatePeriod() throws {
        let subject = try makeSubject(
            job: makeJob(cycle: .perShift),
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

        func expectRail(selectedIndex: Int) throws {
            window.layoutIfNeeded()
            root.layoutIfNeeded()
            let rail: UIScrollView = try requireView(identifier: "overview.period.rail", in: root)
            #expect(!isEffectivelyHidden(rail))
            let layoutEpsilon: CGFloat = 1
            for index in 0..<3 {
                let item: UIControl = try requireView(identifier: "overview.period.item.\(index)", in: rail)
                let title: UILabel = try requireView(identifier: "overview.period.item.title", in: item)
                let visibleTitleWidth = title.convert(title.bounds, to: rail)
                    .intersection(rail.bounds).width
                if index == selectedIndex {
                    #expect(item.accessibilityTraits.contains(.selected))
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
        previous.sendActions(for: .touchUpInside)
        previous.sendActions(for: .touchUpInside)
        try expectRail(selectedIndex: 0)
        next.sendActions(for: .touchUpInside)
        try expectRail(selectedIndex: 1)
        next.sendActions(for: .touchUpInside)
        try expectRail(selectedIndex: 2)
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
        #expect(heading.accessibilityLabel == "\(OverviewStrings.shiftSectionPrefix) 1")
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

    @Test("Expected Gross uses the light surface while preserving the dark surface")
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

        let hero: UIView = try requireView(
            identifier: "overview.expectedGross.hero",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(hero) == false)
        let background = try #require(hero.backgroundColor)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        #expect(background.resolvedColor(with: light) == ShiftLedgerColors.surfacePrimary.resolvedColor(with: light))
        #expect(background.resolvedColor(with: light) != ShiftLedgerColors.backgroundPrimary.resolvedColor(with: light))
        #expect(background.resolvedColor(with: dark) == ShiftLedgerColors.backgroundSecondary.resolvedColor(with: dark))
    }

    @Test("Tapping a scheduled rail item changes only the selected calculation, not Shift history")
    func scheduledRailTapUpdatesVisibleContent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [august, september])
        var receivedPeriod: PayCalculationPeriod?
        subject.viewController.onCheckPaycheck = { receivedPeriod = $0 }
        subject.viewController.loadViewIfNeeded()
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

    @Test("Shift count represents every persisted Shift in history")
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
        #expect(content.totalStoredShiftCount == 2)
        #expect(content.shiftHistoryBreakdowns.count == 2)
    }

    @Test("Shift history renders every persisted Shift in deterministic reverse chronology")
    func shiftHistoryRendersAllPersistedCardsInReverseChronology() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 8, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])

        subject.viewController.loadViewIfNeeded()

        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])

        let frontDate: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).frontDate",
            in: try requireRootView(subject.viewController)
        )
        let amount: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).frontExpected",
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
        #expect(endpoints.isAccessibilityElement == false)
        #expect(descendant(identifier: "overview.shift.\(newer.id.uuidString).dateBadge", in: try requireRootView(subject.viewController)) == nil)
    }

    @Test("A covered Shift exposes its date, time, and expected contribution in the dedicated header")
    func coveredShiftHeaderContainsIdentityWithoutDuration() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let header: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).header",
            in: try requireRootView(subject.viewController)
        )
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

        let headerFrame = header.convert(header.bounds, to: card)
        #expect(headerFrame.maxY <= 72.5)
        #expect(time.isDescendant(of: header))
        #expect(amount.isDescendant(of: header))
        #expect(date.isDescendant(of: header))
        #expect(date.text == OverviewFormatting.frontShiftDate(
            older,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        ))
        #expect(duration.isDescendant(of: header) == false)
        #expect(rate.isDescendant(of: header) == false)
        #expect(descendant(identifier: "overview.shift.\(older.id.uuidString).dateBadge", in: try requireRootView(subject.viewController)) == nil)
        let coveredEndpoints = descendant(
            identifier: "overview.shift.\(older.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        #expect(coveredEndpoints == nil)
        #expect(date.numberOfLines == 1)
        for label in [time, amount] {
            #expect(label.numberOfLines == 0)
        }
        for label in [date, time, amount] {
            #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height)
        }
    }

    @Test("Covered and front Shift headers share the 20-point card grid")
    func shiftHeadersUseCanonicalHorizontalInset() throws {
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
        let frontDate: UILabel = try requireView(identifier: "overview.shift.\(newer.id.uuidString).frontDate", in: root)
        let frontAmount: UILabel = try requireView(identifier: "overview.shift.\(newer.id.uuidString).frontExpected", in: root)

        for (card, date, amount) in [(covered, coveredDate, coveredAmount), (front, frontDate, frontAmount)] {
            let dateFrame = date.convert(date.bounds, to: card)
            let amountFrame = amount.convert(amount.bounds, to: card)
            #expect(abs(dateFrame.minX - 20) <= 0.5)
            #expect(abs((card.bounds.maxX - amountFrame.maxX) - 20) <= 0.5)
            #expect(dateFrame.maxX <= amountFrame.minX)
            #expect(dateFrame.minX >= card.bounds.minX)
            #expect(dateFrame.maxX <= card.bounds.maxX)
            #expect(amountFrame.minX >= card.bounds.minX)
            #expect(amountFrame.maxX <= card.bounds.maxX)
        }
    }

    @Test("Only the fully visible front Shift renders the endpoints")
    func onlyFrontShiftRendersEndpoints() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.loadViewIfNeeded()

        let frontEndpoints: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        let coveredEndpoints = descendant(
            identifier: "overview.shift.\(older.id.uuidString).endpoints",
            in: try requireRootView(subject.viewController)
        )
        let frontHeader: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).frontContent",
            in: try requireRootView(subject.viewController)
        )
        let coveredHeader: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).header",
            in: try requireRootView(subject.viewController)
        )

        #expect(isEffectivelyHidden(frontEndpoints) == false)
        #expect(coveredEndpoints == nil)
        #expect(isEffectivelyHidden(frontHeader) == false)
        #expect(isEffectivelyHidden(coveredHeader) == false)
    }

    @Test("Front ticket has two readable endpoints and preserves textual break information",
          arguments: [false, true])
    func frontShiftEndpointsAdaptToContentSize(_ accessibilitySize: Bool) throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let start = try date(year: 2026, month: 9, day: 20, hour: 8)
        let shift = try Shift(
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
        let endpoints: UIView = try requireView(identifier: "\(prefix).endpoints", in: try requireRootView(subject.viewController))
        let startTime: UILabel = try requireView(identifier: "\(prefix).endpoints.start", in: endpoints)
        let endTime: UILabel = try requireView(identifier: "\(prefix).endpoints.end", in: endpoints)
        let startDate: UILabel = try requireView(identifier: "\(prefix).endpoints.startDate", in: endpoints)
        let endDate: UILabel = try requireView(identifier: "\(prefix).endpoints.endDate", in: endpoints)
        let duration: UILabel = try requireView(identifier: "\(prefix).duration", in: try requireRootView(subject.viewController))
        let unpaidBreak: UILabel = try requireView(identifier: "\(prefix).break", in: try requireRootView(subject.viewController))
        let card: UIControl = try requireView(identifier: prefix, in: try requireRootView(subject.viewController))

        #expect(descendant(identifier: "\(prefix).timeline", in: card) == nil)
        #expect(endpoints.accessibilityElementsHidden)
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

    @Test("Front Shift endpoints preserves the formatted local start and end times")
    func frontShiftEndpointsPreservesLocalDateTimeContext() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let start = try date(year: 2026, month: 9, day: 10, hour: 22)
        let overnight = try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            workTypeID: testWorkTypeID,
            start: start,
            end: try date(year: 2026, month: 9, day: 11, hour: 6)
        )
        let subject = try makeSubject(job: job, shifts: [overnight])
        subject.viewController.loadViewIfNeeded()

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
        let card: UIControl = try requireView(
            identifier: "overview.shift.\(overnight.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
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

    @Test("Large front-card contribution grows without a fixed-height clip")
    func largeFrontCardContributionCanGrowVertically() throws {
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

        let amount: UILabel = try requireView(identifier: "overview.shift.\(id.uuidString).frontExpected", in: view)
        let date: UILabel = try requireView(identifier: "overview.shift.\(id.uuidString).frontDate", in: view)
        #expect(amount.numberOfLines == 0)
        #expect(amount.bounds.height + 0.5 >= amount.sizeThatFits(
            CGSize(width: amount.bounds.width, height: CGFloat.greatestFiniteMagnitude)
        ).height)
        #expect(amount.frame.intersects(date.frame) == false)
    }

    @Test("Per-shift period selection leaves every persisted card in the history stack")
    func perShiftPeriodSelectionKeepsAllPersistedCards() throws {
        let job = try makeJob(cycle: .perShift)
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.loadViewIfNeeded()

        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])
        let firstPeriod: UIControl = try requireView(
            identifier: "overview.period.item.0",
            in: try requireRootView(subject.viewController)
        )
        firstPeriod.sendActions(for: .touchUpInside)

        let content = try requireContent(subject.viewModel.state)
        #expect(content.selectedPeriod == .perShift(shiftID: older.id))
        #expect(content.expectedBreakdown?.shiftBreakdowns.map(\.shift) == [older])
        #expect(content.shiftHistoryBreakdowns.map(\.shift) == [older, newer])
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, older.id])
        let count: UILabel = try requireView(
            identifier: "overview.shiftCount.value",
            in: try requireRootView(subject.viewController)
        )
        #expect(count.text == "2")
    }

    @Test("Shift history renders an unpaid-break indicator only when the Shift contains one")
    func shiftHistoryRendersUnpaidBreakOnlyWhenPresent() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let withoutBreak = try makeShift(id: 1, month: 9, day: 10)
        let start = try date(year: 2026, month: 9, day: 20, hour: 8)
        let withBreak = try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
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

        let breakLabel: UILabel = try requireView(
            identifier: "overview.shift.\(withBreak.id.uuidString).break",
            in: try requireRootView(subject.viewController)
        )
        let absentBreakLabel: UILabel = try requireView(
            identifier: "overview.shift.\(withoutBreak.id.uuidString).break",
            in: try requireRootView(subject.viewController)
        )
        #expect(breakLabel.isHidden == false)
        #expect(breakLabel.text?.contains(OverviewFormatting.duration(30 * 60)) == true)
        #expect(absentBreakLabel.isHidden)
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

    @Test("Tapping a Shift makes that persisted Shift the only full deck front")
    func shiftCardTapControlsSingleExpandedDetailAndDeckFront() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let middle = try makeShift(id: 2, month: 9, day: 15)
        let newer = try makeShift(id: 3, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, middle, newer])
        subject.viewController.loadViewIfNeeded()

        let newerFront: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).frontContent",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(newerFront) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id])

        let middleCard: UIControl = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        middleCard.sendActions(for: .touchUpInside)

        let middleFront: UIView = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString).frontContent",
            in: try requireRootView(subject.viewController)
        )
        let newerCovered: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).header",
            in: try requireRootView(subject.viewController)
        )
        let middleDetail: UIView = try requireView(
            identifier: "overview.shift.\(middle.id.uuidString).detail.paidTime",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(middleFront) == false)
        #expect(isEffectivelyHidden(newerCovered) == false)
        #expect(isEffectivelyHidden(middleDetail) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [middle.id])

        let olderCard: UIControl = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        olderCard.sendActions(for: .touchUpInside)

        let olderFront: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).frontContent",
            in: try requireRootView(subject.viewController)
        )
        let newerCard: UIControl = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(olderFront) == false)
        #expect(visibleFrontCardIdentifiers(in: try requireRootView(subject.viewController)) == [older.id])
        #expect(olderCard.accessibilityTraits.contains(.selected))
        #expect(newerCard.accessibilityTraits.contains(.selected) == false)
        #expect(shiftCardIdentifiers(in: try requireRootView(subject.viewController)) == [newer.id, middle.id, older.id])

        let olderDetail: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).detail.paidTime",
            in: try requireRootView(subject.viewController)
        )

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

        card.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(editButton.isHidden == false)
        #expect(editButton.configuration?.title == OverviewStrings.editShift)
        #expect(editButton.bounds.height >= 44)
        #expect(card.accessibilityCustomActions?.map(\.name) == [OverviewStrings.editShift])

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

        card.sendActions(for: .touchUpInside)
        #expect(editButton.isHidden)
    }

    @Test("Covered Shift strips resolve hit testing to their own card before making it front")
    func coveredShiftStripsReceiveTouches() throws {
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

    @Test("Normal Shift history is a static deck while accessibility size remains a vertical accordion")
    func shiftStackAdaptsForAccessibilityContentSize() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shifts = try [
            makeShift(id: 1, month: 9, day: 10),
            makeShift(id: 2, month: 9, day: 15),
            makeShift(id: 3, month: 9, day: 20),
            makeShift(id: 4, month: 9, day: 21)
        ]
        let subject = try makeSubject(job: job, shifts: shifts)
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
        expectBackgroundDeck(cards, in: deck, window: window)

        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.layoutIfNeeded()
        try requireRootView(subject.viewController).layoutIfNeeded()
        expectAccessibleDocumentOrder(cards, in: window)
    }

    @Test("Accessibility Shift dates fill card headers without character wrapping")
    func accessibilityShiftHeadersUseFullWidth() throws {
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
            identifier: "overview.shift.\(newer.id.uuidString).frontDate", in: root
        )
        let coveredAmount: UILabel = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).expected", in: root
        )
        let frontAmount: UILabel = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).frontExpected", in: root
        )
        for (date, amount) in [(coveredDate, coveredAmount), (frontDate, frontAmount)] {
            #expect(date.numberOfLines == 1)
            #expect(date.bounds.width > 0)
            #expect(date.bounds.width + 0.5 >= date.intrinsicContentSize.width)
            #expect(date.bounds.width >= amount.bounds.width - 1)
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

    @Test("One Shift stays full while two and three Shifts layer background tops above a lower front card")
    func shiftStackUsesStaticDeckGeometryForEachHistorySize() throws {
        for count in 1...3 {
            let ids = (1...count).map {
                UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
            }
            let view = OverviewView(frame: .zero)
            let host = UIViewController()
            host.view = view
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

            if count == 1 {
                let cardFrame = cards[0].convert(cards[0].bounds, to: deck)
                #expect(abs(cardFrame.minY - deck.bounds.minY) < 0.5)
                #expect(abs(cardFrame.maxY - deck.bounds.maxY) < 0.5)
            } else {
                expectBackgroundDeck(cards, in: deck, window: window)
            }
        }
    }

    @Test("Selected or missing selection determines the visual front without changing canonical card order")
    func shiftStackUsesSelectedCardOrNewestFallbackAsVisualFront() throws {
        let ids = (1...4).map {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8($0)))
        }
        let view = OverviewView(frame: .zero)
        let host = UIViewController()
        host.view = view
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
        expectBackgroundDeck([cards[0], cards[1], cards[2], cards[3]], in: deck, window: window)

        renderPresentationCards(ids: ids, selectedID: ids[2], in: view)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: view) == [ids[2]])
        expectBackgroundDeck([cards[2], cards[0], cards[1], cards[3]], in: deck, window: window)

        renderPresentationCards(ids: ids, selectedID: UUID(), in: view)
        window.layoutIfNeeded()
        #expect(visibleFrontCardIdentifiers(in: view) == [ids[0]])
    }

    @Test("Six decorative Shift surface roles each provide a foreground")
    func shiftSurfaceRolesProvideForegrounds() {
        #expect(ShiftSurfaceRole.allCases.count == 6)

        for traits in [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(userInterfaceStyle: .dark)
        ] {
            for role in ShiftSurfaceRole.allCases {
                let surface = ShiftLedgerColors.shiftSurface(for: role).resolvedColor(with: traits)
                let foreground = ShiftLedgerColors.shiftForeground(for: role).resolvedColor(with: traits)
                #expect(surface.isEqual(foreground) == false)
            }
        }
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

    @Test("Scheduled zero-shift period renders an honest Shift history empty state")
    func scheduledZeroShiftPeriodRendersShiftHistoryEmptyState() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.shiftHistory.empty",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(label) == false)
        #expect(label.text == OverviewStrings.shiftHistoryEmpty)
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

    @Test("Overview устанавливает меню Add work type в navigation bar")
    func installsAddWorkTypeMenu() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let item = try #require(subject.viewController.navigationItem.rightBarButtonItem)
        #expect(item.accessibilityIdentifier == "overview.more")
        #expect(item.image == UIImage(systemName: "ellipsis.circle"))
        let menu = try #require(item.menu)
        #expect(menu.children.count == 1)
        #expect(menu.children.first?.title == OverviewStrings.addWorkType)
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

        subject.viewController.loadViewIfNeeded()

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
        shiftCardIdentifiers(in: view).filter { id in
            guard let front = descendant(identifier: "overview.shift.\(id.uuidString).frontContent", in: view) else {
                return false
            }
            return isEffectivelyHidden(front) == false
        }
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

    private func expectBackgroundDeck(_ cards: [UIView], in deck: UIView, window: UIWindow) {
        let zIndices = cards.compactMap { deck.subviews.firstIndex(of: $0) }
        #expect(zIndices.count == cards.count)

        let frontFrame = cards[0].convert(cards[0].bounds, to: deck)
        #expect(abs(frontFrame.maxY - deck.bounds.maxY) < 0.5)

        for (frontward, backgroundward) in zip(cards, cards.dropFirst()) {
            let frontwardFrame = frontward.convert(frontward.bounds, to: deck)
            let backgroundFrame = backgroundward.convert(backgroundward.bounds, to: deck)
            #expect(backgroundFrame.minY < frontwardFrame.minY)
            #expect(backgroundFrame.maxY > frontwardFrame.minY)
            let exposedTopHeight = frontwardFrame.minY - backgroundFrame.minY
            #expect((56...80).contains(Int(exposedTopHeight.rounded())))
        }

        for (front, background) in zip(zIndices, zIndices.dropFirst()) {
            #expect(front > background)
        }
    }

    private func expectAccessibleDocumentOrder(_ cards: [UIView], in window: UIWindow) {
        for (first, second) in zip(cards, cards.dropFirst()) {
            let firstFrame = first.convert(first.bounds, to: window)
            let secondFrame = second.convert(second.bounds, to: window)
            #expect(firstFrame.maxY <= secondFrame.minY)
        }
    }

    private func renderPresentationCards(
        ids: [UUID],
        selectedID: UUID?,
        expectedAmount: String = "€160",
        in view: OverviewView
    ) {
        let cards = ids.map { id in
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
                expectedAmount: expectedAmount,
                paidDuration: "8h",
                unpaidBreak: nil,
                unpaidBreakTimeRange: nil,
                appliedRate: "€20 / h",
                payBasis: "Hourly",
                isSelected: id == selectedID,
                isExpanded: false,
                accessibilityLabel: "Shift"
            )
        }
        view.renderContent(
            expectedGross: "€640",
            expectedGrossContext: "Expected gross · EUR",
            period: "September 2026",
            periodItems: [],
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
}
