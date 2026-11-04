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
            "actualGrossEntry.amount.container",
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

    @Test("Amount input uses a contained surface with secondary metadata")
    func amountInputUsesContainedSurface() throws {
        let viewController = makeViewController()
        viewController.loadViewIfNeeded()

        let container: UIView = try requireView(
            identifier: "actualGrossEntry.amount.container",
            in: viewController.view
        )
        let label: UILabel = try requireView(
            identifier: "actualGrossEntry.amount.label",
            in: viewController.view
        )
        let input: UITextField = try requireView(
            identifier: "actualGrossEntry.amount.input",
            in: viewController.view
        )
        let currency: UILabel = try requireView(
            identifier: "actualGrossEntry.currency",
            in: viewController.view
        )

        #expect(container.backgroundColor == ShiftLedgerColors.surfacePrimary)
        #expect(container.layer.cornerRadius == 18)
        #expect(label.textColor == ShiftLedgerColors.textSecondary)
        #expect(input.isDescendant(of: container))
        #expect(currency.isDescendant(of: container))
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

    @Test("Amount caption fits complete words and restores Dynamic Type", arguments: [320.0, 375.0, 402.0])
    func amountCaptionFitsWords(_ width: Double) throws {
        let controller = makeViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let label: UILabel = try requireView(identifier: "actualGrossEntry.amount.label", in: controller.view)
        let original = label.text
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            controller.overrideUserInterfaceStyle = appearance
            for language in ["ru", "en"] {
                let path = try #require(Bundle(for: ActualGrossEntryView.self).path(forResource: language, ofType: "lproj"))
                let bundle = try #require(Bundle(path: path))
                let text = bundle.localizedString(forKey: "actualGrossEntry.amount", value: nil, table: "Localizable")
                #expect(text != "actualGrossEntry.amount")
                #expect(text == (language == "ru" ? "Фактическая сумма до вычетов" : "Actual gross"))
                label.text = text
                var normalSize: CGFloat?
                for category in [UIContentSizeCategory.large, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge, .large] {
                    controller.traitOverrides.preferredContentSizeCategory = category
                    window.layoutIfNeeded()
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    controller.view.layoutIfNeeded()
                    #expect(label.text == text)
                    #expect(abs(label.bounds.width - (width - 80)) < 1)
                    let attributed = try #require(label.attributedText)
                    let paragraph = try #require(attributed.attribute(.paragraphStyle, at: 0,
                        effectiveRange: nil) as? NSParagraphStyle)
                    #expect(paragraph.usesDefaultHyphenation == false)
                    #expect(paragraph.hyphenationFactor == Float(0.001))
                    let renderedFont = try #require(attributed.attribute(.font, at: 0,
                        effectiveRange: nil) as? UIFont)
                    #expect(renderedFont == label.font)
                    #expect(renderedFont.fontDescriptor.object(forKey: .textStyle) as? String != UIFont.TextStyle.callout.rawValue)
                    let storage = NSTextStorage(attributedString: attributed)
                    let manager = NSLayoutManager()
                    manager.usesDefaultHyphenation = true
                    storage.addLayoutManager(manager)
                    let container = NSTextContainer(size: CGSize(width: label.bounds.width, height: 10000))
                    container.lineFragmentPadding = 0
                    manager.addTextContainer(container)
                    manager.ensureLayout(for: container)
                    let string = text as NSString
                    manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, glyphs, _ in
                        let range = manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                        let end = NSMaxRange(range)
                        if end > 0 && end < string.length {
                            let before = string.substring(with: NSRange(location: end - 1, length: 1))
                            let after = string.substring(with: NSRange(location: end, length: 1))
                            #expect(before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    let probe = UILabel()
                    probe.font = renderedFont
                    for word in text.split(whereSeparator: { $0.isWhitespace }) {
                        probe.text = String(word)
                        let size = probe.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                           height: CGFloat.greatestFiniteMagnitude))
                        #expect(size.width <= label.bounds.width)
                    }
                    let height = label.sizeThatFits(CGSize(width: label.bounds.width,
                                                          height: CGFloat.greatestFiniteMagnitude)).height
                    #expect(height <= label.bounds.height + 1 / max(1, label.traitCollection.displayScale))
                    if category == .large {
                        if let normalSize { #expect(label.font.pointSize == normalSize) }
                        normalSize = label.font.pointSize
                        let token = UIFont.preferredFont(forTextStyle: .callout,
                            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
                        #expect(label.font.pointSize == token.pointSize)
                        #expect(label.font.fontName == token.fontName)
                        #expect(label.font.fontDescriptor.symbolicTraits == token.fontDescriptor.symbolicTraits)
                    } else {
                        #expect(label.font.pointSize >= 17)
                        #expect(label.font.pointSize > (normalSize ?? 0))
                    }
                    let stableFont = label.font
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    #expect(label.font == stableFont)
                }
            }
        }
        label.text = original
    }

    @Test("Supporting text preserves words and layout", arguments: [320.0, 375.0, 402.0])
    func supportingWrapsWords(_ width: Double) throws {
        let controller = makeViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let label: UILabel = try requireView(identifier: "actualGrossEntry.supporting", in: controller.view)
        for language in ["ru", "en"] {
            let path = try #require(Bundle(for: ActualGrossEntryView.self).path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            let text = bundle.localizedString(forKey: "actualGrossEntry.supporting", value: nil, table: "Localizable")
            #expect(text != "actualGrossEntry.supporting")
            label.text = text
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

    @Test("Supporting geometry stabilizes across same-controller width changes")
    func supportingWidthTransitions() throws {
        let controller = makeViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let label: UILabel = try requireView(identifier: "actualGrossEntry.supporting", in: controller.view)
        for language in ["ru", "en"] {
            let path = try #require(Bundle(for: ActualGrossEntryView.self).path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            label.text = bundle.localizedString(forKey: "actualGrossEntry.supporting", value: nil, table: "Localizable")
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
                controller.traitOverrides.preferredContentSizeCategory = category
                for width in [402.0, 320.0, 375.0, 402.0] {
                    window.frame.size.width = width
                    var lastBounds: CGRect?
                    var lastFont: UIFont?
                    var stablePass: Int?
                    for pass in 1...5 {
                        window.setNeedsLayout()
                        window.layoutIfNeeded()
                        controller.view.setNeedsLayout()
                        controller.view.layoutIfNeeded()
                        print("SL529 WIDTH", language, category.rawValue, width, pass,
                              controller.view.bounds, label.bounds, label.font.fontName, label.font.pointSize,
                              label.sizeThatFits(CGSize(width: label.bounds.width, height: 10000)).height)
                        if label.bounds == lastBounds && label.font == lastFont { stablePass = pass; break }
                        lastBounds = label.bounds
                        lastFont = label.font
                    }
                    #expect(stablePass != nil)
                    #expect(abs(label.bounds.width - (width - 48)) < 1)
                    #expect(label.font.pointSize >= 17)
                    if category == .large { #expect(label.font.pointSize == 17) }
                    let probe = UILabel()
                    probe.font = label.font
                    for word in (label.text ?? "").split(whereSeparator: { $0.isWhitespace }) {
                        probe.text = String(word)
                        #expect(probe.sizeThatFits(CGSize(width: 10000, height: 10000)).width <= label.bounds.width)
                    }
                    #expect(label.sizeThatFits(CGSize(width: label.bounds.width, height: 10000)).height <= label.bounds.height + 1)
                    if let stack = label.superview as? UIStackView,
                       let index = stack.arrangedSubviews.firstIndex(of: label) {
                        let gap = stack.arrangedSubviews[index + 1].frame.minY - label.frame.maxY
                        print("SL529 GAP", gap)
                        #expect(gap >= 0)
                    }
                }
            }
        }
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
