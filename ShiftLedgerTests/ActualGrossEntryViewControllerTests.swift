import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct ActualGrossEntryViewControllerTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test("Question and supporting copy render")
    func questionAndSupportingCopyRender() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let question: UILabel = try requireView(
            identifier: "actualGrossEntry.question",
            in: viewController.view
        )
        let supporting: UILabel = try requireView(
            identifier: "actualGrossEntry.supporting",
            in: viewController.view
        )

        #expect(question.text == ActualGrossEntryStrings.question)
        #expect(supporting.text == ActualGrossEntryStrings.supporting)
        #expect(question.accessibilityTraits.contains(.header))
    }

    @Test("Currency code renders as immutable context")
    func currencyCodeRenders() throws {
        let viewController = makeViewController(currencyCode: "SEK")
        viewController.loadViewIfNeeded()

        let currency: UILabel = try requireView(
            identifier: "actualGrossEntry.currency",
            in: viewController.view
        )

        #expect(currency.text == "SEK")
        #expect(currency.accessibilityLabel == "SEK")
    }

    @Test("Compare is initially disabled")
    func compareIsInitiallyDisabled() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )

        #expect(button.isEnabled == false)
    }

    @Test("Entering a valid amount enables Compare")
    func validAmountEnablesCompare() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        try enter("12.34", in: viewController.view)

        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )
        #expect(button.isEnabled)
    }

    @Test("Zero enables Compare")
    func zeroEnablesCompare() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        try enter("0", in: viewController.view)

        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )
        #expect(button.isEnabled)
    }

    @Test("Malformed non-empty input shows validation")
    func malformedInputShowsValidation() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        try enter("12abc", in: viewController.view)

        let validation: UILabel = try requireView(
            identifier: "actualGrossEntry.validation",
            in: viewController.view
        )
        #expect(isEffectivelyHidden(validation) == false)
        #expect(validation.text == ActualGrossEntryStrings.invalidAmount)
    }

    @Test("Returning to valid input hides validation")
    func validInputHidesValidation() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()
        try enter("12abc", in: viewController.view)

        try enter("12.34", in: viewController.view)

        let validation: UILabel = try requireView(
            identifier: "actualGrossEntry.validation",
            in: viewController.view
        )
        #expect(isEffectivelyHidden(validation))
    }

    @Test("Valid Compare invokes onContinue exactly once")
    func validCompareInvokesCallbackOnce() throws {
        let viewController = makeViewController()
        var callCount = 0
        viewController.onContinue = { _ in callCount += 1 }
        viewController.loadViewIfNeeded()
        try enter("250.75", in: viewController.view)
        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(callCount == 1)
    }

    @Test("Callback receives the exact ActualGross Decimal")
    func callbackReceivesExactDecimal() throws {
        let viewController = makeViewController()
        let expected = try #require(Decimal(string: "1234.56789", locale: locale))
        var received: ActualGross?
        viewController.onContinue = { received = $0 }
        viewController.loadViewIfNeeded()
        try enter("1234.56789", in: viewController.view)
        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(received?.amount == expected)
    }

    @Test("Invalid input cannot produce a successful callback")
    func invalidInputCannotContinue() throws {
        let viewController = makeViewController()
        var callCount = 0
        viewController.onContinue = { _ in callCount += 1 }
        viewController.loadViewIfNeeded()
        try enter("invalid", in: viewController.view)
        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )

        button.sendActions(for: .touchUpInside)

        #expect(button.isEnabled == false)
        #expect(callCount == 0)
    }

    @Test("Amount field uses decimalPad")
    func amountFieldUsesDecimalPad() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let input: UITextField = try requireView(
            identifier: "actualGrossEntry.amount.input",
            in: viewController.view
        )

        #expect(input.keyboardType == .decimalPad)
    }

    @Test("Required accessibility identifiers exist")
    func requiredAccessibilityIdentifiersExist() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let identifiers = [
            "actualGrossEntry.screen",
            "actualGrossEntry.question",
            "actualGrossEntry.supporting",
            "actualGrossEntry.amount.label",
            "actualGrossEntry.amount.input",
            "actualGrossEntry.currency",
            "actualGrossEntry.validation",
            "actualGrossEntry.compare"
        ]

        for identifier in identifiers {
            let view = descendant(identifier: identifier, in: viewController.view)
            #expect(view != nil)
        }
    }

    @Test("Amount input has a meaningful accessibility label")
    func amountInputHasAccessibilityLabel() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let input: UITextField = try requireView(
            identifier: "actualGrossEntry.amount.input",
            in: viewController.view
        )

        #expect(input.accessibilityLabel == ActualGrossEntryStrings.amount)
    }

    @Test("Text and controls support Dynamic Type")
    func contentSupportsDynamicType() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let identifiers = [
            "actualGrossEntry.question",
            "actualGrossEntry.supporting",
            "actualGrossEntry.amount.label",
            "actualGrossEntry.currency",
            "actualGrossEntry.validation"
        ]
        for identifier in identifiers {
            let label: UILabel = try requireView(identifier: identifier, in: viewController.view)
            #expect(label.adjustsFontForContentSizeCategory)
        }
        let input: UITextField = try requireView(
            identifier: "actualGrossEntry.amount.input",
            in: viewController.view
        )
        let button: UIButton = try requireView(
            identifier: "actualGrossEntry.compare",
            in: viewController.view
        )
        #expect(input.adjustsFontForContentSizeCategory)
        #expect(button.titleLabel?.adjustsFontForContentSizeCategory == true)
    }

    @Test("Flexible labels have no fixed heights")
    func flexibleLabelsHaveNoFixedHeights() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        for identifier in [
            "actualGrossEntry.question",
            "actualGrossEntry.supporting",
            "actualGrossEntry.validation"
        ] {
            let label: UILabel = try requireView(identifier: identifier, in: viewController.view)
            #expect(hasFixedHeight(label) == false)
            #expect(label.numberOfLines == 0)
        }
    }

    @Test("Scroll view keeps accessibility-size content reachable")
    func scrollViewSupportsLargeContent() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let scrollView = try #require(firstDescendant(of: UIScrollView.self, in: viewController.view))

        #expect(scrollView.alwaysBounceVertical)
    }

    private func makeViewController(
        currencyCode: String = "EUR"
    ) -> ActualGrossEntryViewController {
        ActualGrossEntryViewController(
            viewModel: ActualGrossEntryViewModel(decimalInputLocale: locale),
            currencyCode: currencyCode
        )
    }

    private func enter(_ text: String, in rootView: UIView) throws {
        let input: UITextField = try requireView(
            identifier: "actualGrossEntry.amount.input",
            in: rootView
        )
        input.text = text
        input.sendActions(for: .editingChanged)
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

    private func firstDescendant<View: UIView>(
        of type: View.Type,
        in view: UIView
    ) -> View? {
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
}
