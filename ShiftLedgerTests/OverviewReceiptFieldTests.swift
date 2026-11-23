import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewReceiptFieldTests {
    @Test("Unpaid break detail title is localized in Russian and English")
    func unpaidBreakDetailLocalization() throws {
        for (language, expected) in [("ru", "Перерыв без оплаты"), ("en", "Unpaid break")] {
            let path = try #require(Bundle(for: OverviewViewController.self).path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            #expect(bundle.localizedString(forKey: "overview.shift.unpaidBreakDetail", value: nil, table: "Localizable") == expected)
        }
    }

    @Test("Break and rate fields retain complete text at 320 points and AXXXL")
    func breakAndRateFieldsAtNarrowAccessibilityWidth() {
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: host.view.topAnchor)
        ])
        let breakField = OverviewReceiptFieldView()
        let rate = OverviewReceiptFieldView()
        stack.addArrangedSubview(breakField)
        stack.addArrangedSubview(rate)
        breakField.update(label: "Перерыв без оплаты", value: "09:00–09:30 · 30 мин", wrappedValue: "09:00–09:30\n30 мин", identifier: "break")
        rate.update(label: "Ставка", value: "100,00 SEK / час", wrappedValue: "100,00 SEK\n/ час", identifier: "rate")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 1200))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        #expect(breakField.label.text == "Перерыв без оплаты")
        let paragraph = breakField.label.attributedText?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect((paragraph?.hyphenationFactor ?? 0) == 0)
        #expect(breakField.value.text == "09:00–09:30\n30 мин")
        #expect(breakField.accessibilityLabel == "Перерыв без оплаты, 09:00–09:30 · 30 мин")
        #expect(rate.value.text == "100,00 SEK\n/ час")
        for field in [breakField, rate] {
            #expect(field.axis == .vertical)
            #expect(field.label.frame.maxY <= field.value.frame.minY)
            for label in [field.label, field.value] {
                #expect(label.bounds.height + 0.5 >= label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                #expect(label.frame.maxX <= field.bounds.width + 0.5)
            }
        }
    }
}
