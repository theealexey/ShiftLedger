import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct PayRateHistoryViewControllerTests {
    @Test("History screen renders context and read-only rows in presentation order")
    func rendersReadOnlyRows() throws {
        let fallback = try PayRate(id: id(1), amount: 10, effectiveFrom: nil)
        let dated = try PayRate(
            id: id(2),
            amount: 14,
            effectiveFrom: LocalDate(year: 2026, month: 9, day: 27)
        )
        let viewModel = PayRateHistoryViewModel(
            workType: try makeWorkType(rates: [fallback, dated]),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            displayLocale: Locale(identifier: "en_US")
        )
        let viewController = PayRateHistoryViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: viewController)
        window.makeKeyAndVisible()
        viewController.view.layoutIfNeeded()
        defer { window.isHidden = true }

        #expect(viewController.title == PayRateHistoryStrings.title)
        #expect(viewController.navigationItem.largeTitleDisplayMode == .never)
        let screen: UIView = try requireView("payRateHistory.screen", in: viewController.view)
        let context: UILabel = try requireView("payRateHistory.workType", in: screen)
        let datedRow: UIView = try requireView("payRateHistory.row.\(dated.id.uuidString)", in: screen)
        let fallbackRow: UIView = try requireView("payRateHistory.row.\(fallback.id.uuidString)", in: screen)
        #expect(context.text == "Teaching")
        #expect(context.numberOfLines == 0)
        #expect(datedRow.accessibilityLabel == viewModel.rows[0].accessibilityLabel)
        #expect(fallbackRow.accessibilityLabel == viewModel.rows[1].accessibilityLabel)
        #expect(datedRow.accessibilityTraits.contains(.button) == false)
        #expect(fallbackRow.accessibilityTraits.contains(.button) == false)
        #expect(datedRow.accessibilityTraits.contains(.staticText))
        #expect(fallbackRow.accessibilityTraits.contains(.staticText))
        let datedFrame = datedRow.convert(datedRow.bounds, to: screen)
        let fallbackFrame = fallbackRow.convert(fallbackRow.bounds, to: screen)
        #expect(datedFrame.minY < fallbackFrame.minY)
    }

    @Test("Accessibility text size keeps all meaningful labels multiline and scrollable")
    func accessibilityLayoutRemainsReadable() throws {
        let rates = [
            try PayRate(id: id(1), amount: 10, effectiveFrom: nil),
            try PayRate(
                id: id(2),
                amount: 1_234.56,
                effectiveFrom: LocalDate(year: 2026, month: 9, day: 27)
            )
        ]
        let viewController = PayRateHistoryViewController(
            viewModel: PayRateHistoryViewModel(
                workType: try makeWorkType(
                    name: "A very long Work Type name that must remain readable",
                    rates: rates
                ),
                currencyCode: "USD",
                timeZoneIdentifier: "Europe/Stockholm",
                displayLocale: Locale(identifier: "en_US")
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        defer { window.isHidden = true }

        let scrollView: UIScrollView = try requireView("payRateHistory.list", in: viewController.view)
        let context: UILabel = try requireView("payRateHistory.workType", in: viewController.view)
        #expect(scrollView.alwaysBounceVertical)
        #expect(context.numberOfLines == 0)
        for rate in rates {
            let amount: UILabel = try requireView(
                "payRateHistory.row.\(rate.id.uuidString).amount",
                in: viewController.view
            )
            let date: UILabel = try requireView(
                "payRateHistory.row.\(rate.id.uuidString).effectiveDate",
                in: viewController.view
            )
            #expect(amount.numberOfLines == 0)
            #expect(date.numberOfLines == 0)
            #expect(amount.frame.width > 0)
            #expect(date.frame.width > 0)
        }
    }

    private func makeWorkType(
        name: String? = "Teaching",
        rates: [PayRate]
    ) throws -> WorkType {
        WorkType(
            id: id(42),
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: rates)
        )
    }

    private func requireView<View: UIView>(
        _ identifier: String,
        in root: UIView
    ) throws -> View {
        func find(in view: UIView) -> View? {
            if view.accessibilityIdentifier == identifier {
                return view as? View
            }
            for subview in view.subviews {
                if let match = find(in: subview) {
                    return match
                }
            }
            return nil
        }

        return try #require(find(in: root))
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
