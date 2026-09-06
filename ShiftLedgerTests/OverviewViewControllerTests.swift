import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewViewControllerTests {
    private let displayLocale = Locale(identifier: "en_US_POSIX")

    @Test("Content displays the expected gross")
    func contentDisplaysExpectedGross() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 10)
        let subject = try makeSubject(job: job, shifts: [shift])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: subject.viewController.view
        )
        #expect(label.text?.contains("160") == true)
    }

    @Test("Content displays the selected scheduled period")
    func contentDisplaysScheduledPeriod() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.period.label",
            in: subject.viewController.view
        )
        #expect(label.text?.contains("Sep") == true)
        #expect(label.text?.contains("30") == true)
    }

    @Test("Shift count uses selected-period breakdown instead of stored total")
    func shiftCountUsesBreakdownCount() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let august = try makeShift(id: 1, month: 8, day: 20)
        let september = try makeShift(id: 2, month: 9, day: 10)
        let subject = try makeSubject(job: job, shifts: [august, september])

        subject.viewController.loadViewIfNeeded()

        let label: UILabel = try requireView(
            identifier: "overview.shiftCount.value",
            in: subject.viewController.view
        )
        #expect(label.text == "1")
        let content = try requireContent(subject.viewModel.state)
        #expect(content.totalStoredShiftCount == 2)
    }

    @Test("Previous button follows ViewModel navigation state")
    func previousButtonUsesViewModelState() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: subject.viewController.view
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
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        let initialText = label.text
        let button: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: subject.viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(label.text != initialText)
        #expect(label.text?.contains("Aug") == true)
        let nextButton: UIButton = try requireView(
            identifier: "overview.period.next",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        let initialText = label.text
        let previousButton: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: subject.viewController.view
        )
        let nextButton: UIButton = try requireView(
            identifier: "overview.period.next",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(callCount == 1)
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
            in: subject.viewController.view
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
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        let title: UILabel = try requireView(
            identifier: "overview.empty.title",
            in: subject.viewController.view
        )
        let addButton: UIButton = try requireView(
            identifier: "overview.addShift",
            in: subject.viewController.view
        )
        #expect(isEffectivelyHidden(container) == false)
        #expect(title.text == OverviewStrings.emptyTitle)
        #expect(isEffectivelyHidden(addButton) == false)
    }

    @Test("Check Paycheck is unavailable in per-shift empty state")
    func perShiftEmptyStateCannotCheckPaycheck() throws {
        let job = try makeJob(cycle: .perShift)
        let subject = try makeSubject(job: job, shifts: [])

        subject.viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        let message: UILabel = try requireView(
            identifier: "overview.error.message",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        let message: UILabel = try requireView(
            identifier: "overview.error.message",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )

        retryButton.sendActions(for: .touchUpInside)

        let errorContainer: UIView = try requireView(
            identifier: "overview.error.container",
            in: subject.viewController.view
        )
        let amount: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: subject.viewController.view
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
            in: subject.viewController.view
        )
        #expect(countLabel.text == "0")

        subject.viewController.reload()

        #expect(loadCalls == 2)
        #expect(countLabel.text == "1")
    }

    @Test("Large accessibility content does not use fixed label heights")
    func labelsSupportAccessibilityContentSizes() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.loadViewIfNeeded()
        let amount: UILabel = try requireView(
            identifier: "overview.expectedGross.amount",
            in: subject.viewController.view
        )
        let period: UILabel = try requireView(
            identifier: "overview.period.label",
            in: subject.viewController.view
        )

        #expect(amount.adjustsFontForContentSizeCategory)
        #expect(period.adjustsFontForContentSizeCategory)
        #expect(amount.numberOfLines == 0)
        #expect(period.numberOfLines == 0)
        #expect(hasFixedHeight(amount) == false)
        #expect(hasFixedHeight(period) == false)
    }

    @Test("Core buttons have stable accessibility labels, identifiers, and sizes")
    func buttonsExposeAccessibilityContract() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let subject = try makeSubject(job: job, shifts: [])
        subject.viewController.loadViewIfNeeded()
        let previous: UIButton = try requireView(
            identifier: "overview.period.previous",
            in: subject.viewController.view
        )
        let next: UIButton = try requireView(
            identifier: "overview.period.next",
            in: subject.viewController.view
        )
        let check: UIButton = try requireView(
            identifier: "overview.checkPaycheck",
            in: subject.viewController.view
        )
        let add: UIButton = try requireView(
            identifier: "overview.addShift",
            in: subject.viewController.view
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
