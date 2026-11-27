import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct OverviewExpandedShiftDetailsTests {
    @Test("Saved Shifts resolve their associated current Work Type, including archived and unnamed types")
    func workTypeNamesFollowJobReload() throws {
        let history = try PayRateHistory(payRates: [PayRate(amount: 100, effectiveFrom: nil)])
        let active = WorkType(id: UUID(), name: "Day shift", basePayBasis: .hourly, payRateHistory: history)
        let archived = WorkType(id: UUID(), name: "Former assignment", basePayBasis: .hourly,
                                payRateHistory: history, isArchived: true)
        let unnamed = WorkType(id: UUID(), basePayBasis: .hourly, payRateHistory: history)
        let job = try Job(currencyCode: "SEK", timeZoneIdentifier: "Europe/Stockholm",
                          payCalculationCycle: .perShift, workTypes: [archived, unnamed, active])
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let shifts = try [active, archived, unnamed].enumerated().map { index, workType in
            let start = day.addingTimeInterval(TimeInterval(index * 3600))
            return try Shift(jobID: job.id, workTypeID: workType.id, start: start,
                             end: start.addingTimeInterval(3600))
        }
        let model = OverviewViewModel(job: job, loadShifts: { shifts }, currentDate: { day })
        let mapper = OverviewShiftCardMapper(currencyCode: "SEK", timeZoneIdentifier: job.timeZoneIdentifier,
                                             displayLocale: Locale(identifier: "en_US"))
        func cards() throws -> [OverviewView.ShiftCard] {
            let content = try #require({
                if case let .content(content) = model.state { return content }
                return nil
            }() as OverviewViewModel.Content?)
            return try mapper.map(content.shiftHistoryBreakdowns, workTypeNames: content.workTypeNames,
                                  selectedShiftID: content.selectedShiftID, expandedShiftID: content.expandedShiftID)
        }

        model.load()
        let initial = try cards()
        #expect(initial.map(\.id) == shifts.map(\.id))
        #expect(initial.map(\.workTypeName) == ["Day shift", "Former assignment", AddShiftStrings.unnamedWorkType])
        #expect(initial.allSatisfy { $0.exactExpectedAmount == nil })

        model.handleShiftCardTap(with: shifts[1].id)
        #expect(try cards().filter(\.isExpanded).map(\.id) == [shifts[1].id])
        model.handleShiftCardTap(with: shifts[0].id)
        #expect(try cards().filter(\.isExpanded).map(\.id) == [shifts[0].id])

        model.reload(job: try job.renamingWorkType(id: active.id, to: "Updated day shift"))
        let updated = try cards()
        #expect(updated.map(\.workTypeName) == ["Updated day shift", "Former assignment", AddShiftStrings.unnamedWorkType])
        #expect(updated.map(\.expectedAmount) == initial.map(\.expectedAmount))
    }

    @Test("Expanded Work Type and full-precision amount fit at 320 pt and Accessibility XXXL")
    func expandedFieldsFitAndKeepCombinedAccessibility() throws {
        let longName = "Контроль безопасности производственного оборудования и техническое обслуживание"
        let job = try Job(currencyCode: "SEK", timeZoneIdentifier: "Europe/Stockholm",
                          basePayBasis: .hourly, workTypeName: longName, payCalculationCycle: .perShift,
                          payRates: [PayRate(amount: 100, effectiveFrom: nil)])
        let workType = try #require(job.soleWorkType)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let shift = try Shift(jobID: job.id, workTypeID: workType.id, start: start,
                              end: start.addingTimeInterval(60))
        let breakdown = try job.expectedGrossBreakdown(for: .perShift(shiftID: shift.id), from: [shift])
        let mapper = OverviewShiftCardMapper(currencyCode: job.currencyCode, timeZoneIdentifier: job.timeZoneIdentifier,
                                             displayLocale: Locale(identifier: "ru_RU"))
        func card(expanded: Bool, breakdowns: [ShiftPayBreakdown]) throws -> OverviewView.ShiftCard {
            try #require(mapper.map(breakdowns, workTypeNames: [workType.id: longName],
                                    selectedShiftID: shift.id, expandedShiftID: expanded ? shift.id : nil).first)
        }

        let expanded = try card(expanded: true, breakdowns: breakdown.shiftBreakdowns)
        let exact = try #require(expanded.exactExpectedAmount)
        let engineAmount = try #require(breakdown.shiftBreakdowns.first?.basePay)
        let canonical = NSDecimalNumber(decimal: engineAmount).stringValue
        let localized = canonical.replacingOccurrences(of: ".", with: ",")
        #expect(exact == "\(localized)\u{00A0}SEK")
        #expect(expanded.expectedAmount == "1,67\u{00A0}SEK")

        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let row = OverviewShiftLedgerRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: host.view.topAnchor),
            row.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16)
        ])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 1600))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        var edited: UUID?
        row.update(expanded, showsDivider: false, onCardTapped: nil) { edited = $0 }
        window.layoutIfNeeded()
        let prefix = "overview.shift.\(shift.id.uuidString)"
        let name = try requireLabel("\(prefix).detail.workType", in: row)
        let amount = try requireLabel("\(prefix).detail.exactContribution", in: row)
        let rate = try requireLabel("\(prefix).detail.rate", in: row)
        let edit = try #require(descendant("\(prefix).edit", in: row) as? UIButton)
        #expect(name.text == longName)
        #expect(amount.text == exact)
        #expect(amount.numberOfLines == 0)
        #expect(amount.adjustsFontForContentSizeCategory)
        #expect(!amount.adjustsFontSizeToFitWidth)
        #expect(rate.text?.contains("100") == true)
        for label in [name, amount, rate] {
            let frame = label.convert(label.bounds, to: row)
            #expect(isVisible(label, in: row))
            #expect(row.bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame))
            #expect(label.bounds.width > 0)
            let fitted = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            #expect(label.bounds.height + 0.5 >= fitted.height)
            #expect(!label.isAccessibilityElement)
        }
        #expect(name.convert(name.bounds, to: row).maxY <= rate.convert(rate.bounds, to: row).minY)
        #expect(rate.convert(rate.bounds, to: row).maxY <= amount.convert(amount.bounds, to: row).minY)
        #expect(amount.convert(amount.bounds, to: row).maxY <= edit.convert(edit.bounds, to: row).minY)
        #expect(row.accessibilityLabel?.contains("\(AddShiftStrings.workType): \(longName)") == true)
        let exactDescription = "\(OverviewStrings.exactContribution): \(exact)"
        #expect(row.accessibilityLabel?.components(separatedBy: exactDescription).count == 2)
        edit.sendActions(for: .touchUpInside)
        #expect(edited == shift.id)

        row.update(try card(expanded: false, breakdowns: breakdown.shiftBreakdowns),
                   showsDivider: false, onCardTapped: nil, onEditTapped: nil)
        #expect(!isVisible(name, in: row))
        #expect(!isVisible(amount, in: row))
        #expect(row.accessibilityLabel?.contains(longName) == false)
        #expect(row.accessibilityLabel?.components(separatedBy: exactDescription).count == 2)

        let ordinary = try Shift(id: shift.id, jobID: job.id, workTypeID: workType.id, start: start,
                                 end: start.addingTimeInterval(3600))
        let ordinaryBreakdown = try job.expectedGrossBreakdown(for: .perShift(shiftID: ordinary.id), from: [ordinary])
        let ordinaryCard = try card(expanded: true, breakdowns: ordinaryBreakdown.shiftBreakdowns)
        #expect(ordinaryCard.exactExpectedAmount == nil)
        row.update(ordinaryCard, showsDivider: false, onCardTapped: nil, onEditTapped: nil)
        #expect(isVisible(name, in: row))
        #expect(!isVisible(amount, in: row))
        #expect(row.accessibilityLabel?.contains(OverviewStrings.exactContribution) == false)
    }

    @Test("Home precision explanation keeps the exact gross and displayed zero separate")
    func homePrecisionExplanationPreservesExactDecimal() throws {
        let locale = Locale(identifier: "en_US")
        let number = "0.000000000000000000000000000000000000000000000000000000012345"
        let gross = try #require(Decimal(string: number, locale: locale))
        let job = try Job(currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                          basePayBasis: .fixedPerShift, payCalculationCycle: .perShift,
                          payRates: [PayRate(amount: gross, effectiveFrom: nil)])
        let workType = try #require(job.soleWorkType)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let shift = try Shift(jobID: job.id, workTypeID: workType.id, start: start,
                              end: start.addingTimeInterval(3600))
        let model = OverviewViewModel(job: job, loadShifts: { [shift] }, currentDate: { start })
        let controller = OverviewViewController(viewModel: model, currencyCode: job.currencyCode,
                                                timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let exact = try requireLabel("overview.receipt.precision.exact", in: controller.view)
        let displayed = try requireLabel("overview.receipt.precision.displayed", in: controller.view)
        #expect(isVisible(exact, in: controller.view))
        #expect(exact.text == "€\(number)")
        #expect(displayed.text == "€0.00")
        let breakdown = try job.expectedGrossBreakdown(for: .perShift(shiftID: shift.id), from: [shift])
        #expect(breakdown.expectedGross == gross)
    }

    @Test("Exact amount detail has its own Russian and English titles",
          arguments: [("ru", "Точная сумма"), ("en", "Exact amount")])
    func exactAmountDetailLocalization(_ localization: (language: String, expected: String)) throws {
        let path = try #require(Bundle(for: OverviewViewController.self)
            .path(forResource: localization.language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        #expect(bundle.localizedString(forKey: "overview.shift.exactAmountDetail", value: nil, table: "Localizable")
            == localization.expected)
    }

    private func requireLabel(_ identifier: String, in root: UIView) throws -> UILabel {
        try #require(descendant(identifier, in: root) as? UILabel)
    }

    private func descendant(_ identifier: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        return root.subviews.lazy.compactMap { descendant(identifier, in: $0) }.first
    }

    private func isVisible(_ view: UIView, in root: UIView) -> Bool {
        var ancestor: UIView? = view
        while let current = ancestor, current !== root {
            if current.isHidden { return false }
            ancestor = current.superview
        }
        return ancestor === root
    }
}
