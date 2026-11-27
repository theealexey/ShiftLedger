import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct OverviewViewControllerTests {
    private let displayLocale = Locale(identifier: "en_US_POSIX")

    @Test("Saved Shift heading preserves complete words and count across text sizes",
          arguments: [CGFloat(320), 375, 402], ["Всего", "Total", "Все сохранённые смены", "All saved shifts"])
    func savedShiftHeadingWrapsWholeWords(_ width: CGFloat, _ heading: String) throws {
        let host = UIViewController()
        let root = OverviewView()
        host.view = root
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        root.renderContent(expectedGross: "4,700.00", expectedGrossContext: "Expected gross · EUR",
            period: "2026", periodItems: [], showPeriodNavigation: false,
            shiftCount: 12, shiftCards: [], canNavigatePrevious: false,
            canNavigateNext: false, canCheckPaycheck: true)
        let title: UILabel = try requireView(identifier: "overview.shiftCount.label", in: root)
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        let gross: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        title.text = heading
        for style: UIUserInterfaceStyle in [.light, .dark] {
            host.overrideUserInterfaceStyle = style
            var normalSize: CGFloat?
            for category: UIContentSizeCategory in [.large, .extraExtraLarge, .accessibilityExtraExtraExtraLarge, .large] {
                host.traitOverrides.preferredContentSizeCategory = category
                window.layoutIfNeeded()
                root.layoutIfNeeded()
                root.layoutIfNeeded()
                #expect(title.text == heading && count.text == "12")
                let titleFrame = title.convert(title.bounds, to: root)
                let countFrame = count.convert(count.bounds, to: root)
                #expect(!titleFrame.intersects(countFrame))
                #expect(titleFrame.minX >= 0 && titleFrame.maxX <= width)
                #expect(count.intrinsicContentSize.height <= count.bounds.height + 0.5)
                #expect(gross.intrinsicContentSize.width <= gross.bounds.width)
                let storage = NSTextStorage(string: heading, attributes: [.font: title.font as Any])
                let manager = NSLayoutManager()
                let container = NSTextContainer(size: CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude))
                container.lineFragmentPadding = 0
                container.lineBreakMode = .byWordWrapping
                manager.addTextContainer(container)
                storage.addLayoutManager(manager)
                manager.ensureLayout(for: container)
                let words = heading.split(separator: " ").map(String.init)
                manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, range, _ in
                    let characters = manager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
                    let line = (heading as NSString).substring(with: characters)
                    for word in line.split(whereSeparator: { $0.isWhitespace }) {
                        #expect(words.contains(String(word)))
                    }
                }
                let fitted = title.sizeThatFits(CGSize(width: title.bounds.width, height: .greatestFiniteMagnitude))
                let pixel = 1 / max(1, title.traitCollection.displayScale)
                #expect(fitted.height <= title.bounds.height + pixel)
                #expect(title.numberOfLines == 0 && title.lineBreakMode == .byWordWrapping)
                for word in words {
                    let measurement = UILabel()
                    measurement.font = title.font
                    measurement.text = word
                    #expect(measurement.intrinsicContentSize.width <= title.bounds.width)
                }
                if category == .large {
                    if let normalSize { #expect(abs(title.font.pointSize - normalSize) < 0.01) }
                    else { normalSize = title.font.pointSize }
                }
            }
        }
    }

    @Test("Gross fits the complete localized amount without horizontal interaction",
          arguments: [CGFloat(320), 375, 402], ["ru_RU", "en_US"])
    func grossAmountRemainsWhole(_ width: CGFloat, _ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        for amountText in ["0", "1", "4700", "1234567.89", "999999999999.99", "1.004"] {
            let amount = try #require(Decimal(string: amountText))
            let job = try Job(id: testWorkTypeID, currencyCode: "EUR",
                timeZoneIdentifier: "Europe/Stockholm", basePayBasis: .fixedPerShift,
                payCalculationCycle: .scheduled(.calendarMonthly),
                payRates: [try PayRate(amount: amount == 0 ? 1 : amount, effectiveFrom: nil)],
                createdAt: Date(timeIntervalSinceReferenceDate: 0))
            let shift = try makeShift(id: 1, month: 9, day: 15)
            let model = OverviewViewModel(job: job, loadShifts: { amount == 0 ? [] : [shift] }, currentDate: { shift.end })
            let controller = OverviewViewController(viewModel: model, currencyCode: job.currencyCode,
                timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }
            let root = try requireRootView(controller)
            let label: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
            let caption: UILabel = try requireView(identifier: "overview.expectedGross.label", in: root)
            let expected = OverviewFormatting.heroAmount(amount, currencyCode: "EUR", locale: locale)
            for appearance: UIUserInterfaceStyle in [.light, .dark] {
                controller.overrideUserInterfaceStyle = appearance
                var normalFontSize: CGFloat?
                for category: UIContentSizeCategory in [.large, .extraExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge, .large] {
                    controller.traitOverrides.preferredContentSizeCategory = category
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    root.layoutIfNeeded()
                    #expect(label.text == expected)
                    #expect(label.accessibilityLabel?.contains(expected) == true)
                    #expect(label.numberOfLines == 1 && !label.adjustsFontSizeToFitWidth)
                    let natural = label.intrinsicContentSize
                    #expect(label.bounds.width + 0.5 >= natural.width)
                    #expect(label.bounds.height + 0.5 >= natural.height)
                    #expect(label.bounds.height < label.font.lineHeight * 1.5)
                    #expect(label.font.pointSize >= 17)
                    if category == .large {
                        if let normalFontSize { #expect(abs(normalFontSize - label.font.pointSize) < 0.01) }
                        else { normalFontSize = label.font.pointSize }
                    }
                    let fittedSize = label.font.pointSize
                    window.frame.size.width = width == 320 ? 402 : 320
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    #expect(label.intrinsicContentSize.width <= label.bounds.width)
                    window.frame.size.width = width
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    #expect(abs(fittedSize - label.font.pointSize) < 0.01)
                    #expect(caption.convert(caption.bounds, to: root).maxY <= label.convert(label.bounds, to: root).minY)
                    #expect(descendant(identifier: "overview.expectedGross.scroll", in: root) == nil)
                    #expect(descendant(identifier: "overview.expectedGross.scrollHint", in: root) == nil)
                    #expect(try requireContent(model.state).expectedBreakdown?.expectedGross == amount)
                }
            }
        }
    }

    @Test("Extreme signed amounts wrap only at localized grouping boundaries",
          arguments: [CGFloat(320), 375, 402], ["ru_RU", "en_US"])
    func extremeGrossGroups(_ width: CGFloat, _ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        let separator = try #require(formatter.currencyGroupingSeparator)
        let host = UIViewController()
        let root = OverviewView()
        host.view = root
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        let label: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        for input in ["123456789012345678901234567890123456.78", "-123456789012345678901234567890123456.78", "-999999999999.99", "-4700", "1"] {
            let value = try #require(Decimal(string: input))
            let formatted = OverviewFormatting.heroAmount(value, currencyCode: "EUR", locale: locale)
            for style: UIUserInterfaceStyle in [.light, .dark] {
                host.overrideUserInterfaceStyle = style
                for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge, .large] {
                    host.traitOverrides.preferredContentSizeCategory = category
                    root.renderContent(expectedGross: formatted, expectedGrossContext: "EUR", amountLocale: locale,
                        period: "2026", periodItems: [], showPeriodNavigation: false,
                        shiftCount: 0, shiftCards: [], canNavigatePrevious: false,
                        canNavigateNext: false, canCheckPaycheck: true)
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    root.layoutIfNeeded()
                    let rendered = try #require(label.text)
                    #expect(rendered.replacingOccurrences(of: "\n", with: "") == formatted)
                    #expect(label.accessibilityLabel == "EUR, " + formatted)
                    #expect(label.font.pointSize >= 17)
                    let lines = rendered.components(separatedBy: "\n")
                    for line in lines.dropLast() { #expect(line.hasSuffix(separator)) }
                    #expect(lines.last?.hasSuffix(formatted.components(separatedBy: separator).last ?? formatted) == true)
                    let floorMeasurement = UILabel()
                    floorMeasurement.font = label.font.withSize(17)
                    let groups = formatted.components(separatedBy: separator)
                    for (index, group) in groups.enumerated() {
                        floorMeasurement.text = group + (index < groups.count - 1 ? separator : "")
                        #expect(floorMeasurement.intrinsicContentSize.width <= label.bounds.width - 1 / max(1, label.traitCollection.displayScale))
                    }
                    let measurement = UILabel()
                    measurement.font = label.font
                    for line in lines {
                        measurement.text = line
                        #expect(measurement.intrinsicContentSize.width <= label.bounds.width)
                    }
                    #expect(label.intrinsicContentSize.height <= label.bounds.height + 0.5)
                    if width == 320, input.count > 30, category == .accessibilityExtraExtraExtraLarge {
                        let scroll: UIScrollView = try requireView(identifier: "overview.pageScroll", in: root)
                        let hero: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
                        let section = hero.convert(hero.bounds, to: scroll)
                        #expect(section.height + 32 <= scroll.bounds.height)
                        scroll.scrollRectToVisible(section.insetBy(dx: 0, dy: -16), animated: false)
                        window.layoutIfNeeded()
                        root.layoutIfNeeded()
                        let visibleSection = hero.convert(hero.bounds, to: scroll)
                        #expect(scroll.bounds.contains(visibleSection))
                        let data = try #require(UIGraphicsImageRenderer(bounds: window.bounds).image { context in
                            window.layer.render(in: context.cgContext)
                        }.pngData())
                        let sign = input.hasPrefix("-") ? "negative" : "positive"
                        let appearance = style == .dark ? "dark" : "light"
                        Attachment.record(Array(data), named: "fallback-\(localeID)-\(sign)-\(appearance).png")
                    }
                    window.frame.size.width = width == 320 ? 402 : 320
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    #expect(label.text?.replacingOccurrences(of: "\n", with: "") == formatted)
                    #expect(label.intrinsicContentSize.width <= label.bounds.width)
                    #expect(label.font.pointSize >= 17)
                    window.frame.size.width = width
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    if input.count > 30 { #expect(lines.count > 1) }
                    else { #expect(lines.count == 1) }
                    #expect(descendant(identifier: "overview.expectedGross.scroll", in: root) == nil)
                }
            }
        }
    }

    @Test("Gross transitions replace financial content synchronously before layout", arguments: ["ru_RU", "en_US"])
    func grossTransitionsAreSynchronous(_ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let root = OverviewView()
        let host = UIViewController()
        host.view = root
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        let label: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let extreme = "123456789012345678901234567890123456.78"
        for input in ["12.05", "1", "12.05", "0", "2.01", "1", extreme, "1", extreme, "-" + extreme, "-" + extreme] {
            let value = try #require(Decimal(string: input))
            let formatted = OverviewFormatting.heroAmount(value, currencyCode: "EUR", locale: locale)
            root.renderContent(expectedGross: formatted, expectedGrossContext: "EUR", amountLocale: locale,
                period: input, periodItems: [], showPeriodNavigation: false,
                shiftCount: 0, shiftCards: [], canNavigatePrevious: false,
                canNavigateNext: false, canCheckPaycheck: true)
            // Deliberately before any explicit layout: geometry cannot own the current money value.
            #expect(label.text?.replacingOccurrences(of: "\n", with: "") == formatted)
            #expect(label.accessibilityLabel == "EUR, " + formatted)
            for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
                host.traitOverrides.preferredContentSizeCategory = category
                for width: CGFloat in [375, 320] {
                    window.frame.size.width = width
                    window.layoutIfNeeded()
                    root.layoutIfNeeded()
                    #expect(label.text?.replacingOccurrences(of: "\n", with: "") == formatted)
                    #expect(label.intrinsicContentSize.width <= label.bounds.width)
                    #expect(label.intrinsicContentSize.height <= label.bounds.height + 0.5)
                    #expect(label.font.pointSize >= 17)
                    if input.count < 10 { #expect(label.numberOfLines == 1) }
                }
            }
        }
    }

    @Test("Equal gross remains fully visible when payroll period changes")
    func equalAmountPeriodResetsOverflow() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shifts = try [makeShift(id: 1, month: 8, day: 15), makeShift(id: 2, month: 9, day: 15)]
        let subject = try makeSubject(job: job, shifts: shifts)
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let amount: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        let next: UIButton = try requireView(identifier: "overview.period.next", in: root)
        let originalText = amount.text
        previous.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(amount.text == originalText)
        #expect(amount.intrinsicContentSize.width <= amount.bounds.width + 0.5)
        next.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(amount.text == originalText)
        #expect(amount.intrinsicContentSize.width <= amount.bounds.width + 0.5)
    }

    @Test("Overview navigation brand stays complete through Dynamic Type changes",
          arguments: [CGFloat(320), 375, 402], ["ru_RU", "en_US"])
    func navigationBrandRemainsContained(_ width: CGFloat, _ localeID: String) throws {
        let job = try makeJob(cycle: .perShift)
        let shift = try makeShift(id: 1, month: 9, day: 15)
        let model = OverviewViewModel(job: job, loadShifts: { [shift] }, currentDate: { shift.end })
        let controller = OverviewViewController(viewModel: model, currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: Locale(identifier: localeID))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        let navigation = UINavigationController(rootViewController: controller)
        window.rootViewController = navigation
        window.isHidden = false
        defer { window.isHidden = true }
        let root = try requireRootView(controller)
        let periodCard: UIView = try requireView(identifier: "overview.period.card", in: root)
        let grossCard: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        let brand = try #require(controller.navigationItem.titleView as? UILabel)
        #expect(!root.subviews.contains { $0 === brand })
        #expect(controller.navigationItem.rightBarButtonItem?.menu?.children.count == 2)
        let date: UILabel = try requireView(identifier: "overview.receipt.perShiftPeriod", in: root)
        let time: UILabel = try requireView(identifier: "overview.receipt.perShiftTime", in: root)
        let gross: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let heading = try #require(OverviewFormatting.perShiftHeading(shift,
            timeZoneIdentifier: job.timeZoneIdentifier, locale: Locale(identifier: localeID)))
        var normalBrandSize: CGFloat?
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
            window.traitOverrides.preferredContentSizeCategory = category
            window.layoutIfNeeded()
            root.layoutIfNeeded()
            #expect(brand.text == "ShiftLedger")
            #expect(brand.numberOfLines == 1)
            let text = try #require(brand.text)
            #expect((text as NSString).size(withAttributes: [.font: brand.font as Any]).width <= brand.bounds.width + 0.5)
            #expect(brand.font.pointSize >= 20)
            let fittedFont = brand.font
            let fittedBounds = brand.bounds
            for _ in 0..<3 {
                brand.setNeedsLayout()
                brand.layoutIfNeeded()
                #expect(brand.font == fittedFont)
                #expect(brand.bounds == fittedBounds)
            }
            #expect(brand.bounds.height < brand.font.lineHeight * 1.5)
            #expect(date.text == heading.date && time.text == heading.time)
            #expect(date.accessibilityLabel == heading.accessibilityLabel)
            #expect(!time.isAccessibilityElement)
            #expect([date, time, gross].filter(\.isAccessibilityElement).count == 2)
            for label in [date, time, gross] {
                let card = label === gross ? grossCard : periodCard
                let frame = label.convert(label.bounds, to: card)
                #expect(frame.minX >= 15.5 && frame.maxX <= card.bounds.width - 15.5)
                let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                #expect(label.bounds.height + 0.5 >= required.height)
            }
            for (upper, lower) in zip([date, time], [time, gross]) {
                #expect(upper.convert(upper.bounds, to: root).maxY <= lower.convert(lower.bounds, to: root).minY)
            }
            if category == .large {
                if let normalBrandSize { #expect(abs(brand.font.pointSize - normalBrandSize) < 0.01) }
                else {
                    normalBrandSize = brand.font.pointSize
                    #expect(brand.font.pointSize == 20)
                }
            } else {
                #expect(brand.font.pointSize > (normalBrandSize ?? 0))
            }
        }
    }

    @Test("Hosted PerShift period keeps DST tokens whole and exposes both accessible endpoints",
          arguments: [CGFloat(320), 375, 402], ["ru_RU", "en_US"])
    func hostedPerShiftPeriod(_ width: CGFloat, _ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let job = try Job(id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "America/New_York",
                          basePayBasis: .hourly, payCalculationCycle: .perShift,
                          payRates: [PayRate(amount: 100, effectiveFrom: nil)],
                          createdAt: Date(timeIntervalSinceReferenceDate: 0))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        for (name, month, day, hour, duration) in [
            ("overnight", 1, 1, 4, 7200), ("spring", 3, 8, 6, 3600), ("fall", 11, 1, 5, 3600)
        ] {
            let start = try #require(utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: 30)))
            let shift = try Shift(jobID: job.id, workTypeID: testWorkTypeID,
                                  start: start, end: start.addingTimeInterval(TimeInterval(duration)), unpaidBreak: nil)
            let model = OverviewViewModel(job: job, loadShifts: { [shift] }, currentDate: { shift.end })
            let controller = OverviewViewController(viewModel: model, currencyCode: job.currencyCode,
                timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
            window.rootViewController = UINavigationController(rootViewController: controller)
            window.isHidden = false
            defer { window.isHidden = true }
            let root = try requireRootView(controller)
            let period: UILabel = try requireView(identifier: "overview.receipt.perShiftPeriod", in: root)
            let time: UILabel = try requireView(identifier: "overview.receipt.perShiftTime", in: root)
            let heading = try #require(OverviewFormatting.perShiftHeading(shift,
                timeZoneIdentifier: job.timeZoneIdentifier, locale: locale))
            var initialFont: UIFont?
            for (category, style) in [(UIContentSizeCategory.large, UIUserInterfaceStyle.light),
                                      (.large, .dark), (.accessibilityExtraExtraExtraLarge, .light),
                                      (.accessibilityExtraExtraExtraLarge, .dark), (.large, .light)] {
                window.traitOverrides.preferredContentSizeCategory = category
                window.overrideUserInterfaceStyle = style
                window.layoutIfNeeded()
                root.layoutIfNeeded()
                let font = try #require(time.font)
                if category == .large {
                    if let initialFont { #expect(font == initialFont) }
                    else { initialFont = font }
                    #expect(font == UIFont.preferredFont(forTextStyle: .callout, compatibleWith: time.traitCollection))
                } else {
                    #expect(font.pointSize >= 17)
                }
                let frame = time.frame
                for _ in 0..<2 {
                    root.setNeedsLayout()
                    root.layoutIfNeeded()
                    #expect(time.font == font)
                    #expect(time.frame == frame)
                }
                #expect(period.text == heading.date)
                #expect(time.text == heading.time)
                #expect(period.accessibilityLabel == heading.accessibilityLabel)
                if name != "overnight" {
                    let offsets = (time.text ?? "").split(whereSeparator: \.isWhitespace)
                        .filter { $0.contains("GMT") || $0.contains("UTC") }
                    #expect(offsets.count == 2)
                    let text = try #require(time.text)
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineBreakMode = time.lineBreakMode
                    paragraph.lineBreakStrategy = time.lineBreakStrategy
                    paragraph.alignment = time.textAlignment
                    let storage = NSTextStorage(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
                    let layout = NSLayoutManager()
                    let container = NSTextContainer(size: CGSize(width: time.bounds.width, height: .greatestFiniteMagnitude))
                    container.lineFragmentPadding = 0
                    container.lineBreakMode = time.lineBreakMode
                    storage.addLayoutManager(layout)
                    layout.addTextContainer(container)
                    layout.ensureLayout(for: container)
                    var lines: [NSRange] = []
                    layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, glyphs, _ in
                        lines.append(layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil))
                    }
                    var remaining = NSRange(location: 0, length: storage.length)
                    for offset in offsets {
                        let range = (text as NSString).range(of: String(offset), options: [], range: remaining)
                        try #require(range.location != NSNotFound)
                        #expect(lines.contains { NSIntersectionRange($0, range) == range })
                        remaining = NSRange(location: NSMaxRange(range), length: storage.length - NSMaxRange(range))
                    }
                }
                for label in [period, time] {
                    let size = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    #expect(size.height <= label.bounds.height + 0.5)
                    let tokens = (label.text ?? "").split(whereSeparator: \.isWhitespace)
                    for token in tokens where token.contains("GMT") || token.contains("UTC") {
                        let tokenWidth = (String(token) as NSString).size(withAttributes: [.font: label.font as Any]).width
                        #expect(tokenWidth <= label.bounds.width)
                    }
                }
                #expect(period.convert(period.bounds, to: root).maxY <= time.convert(time.bounds, to: root).minY)
                if width == 320 {
                    let image = UIGraphicsImageRenderer(bounds: root.bounds).image { context in
                        root.layer.render(in: context.cgContext)
                    }
                    let data = try #require(image.pngData())
                    Attachment.record(Array(data), named: "per-shift-\(name)-\(localeID)-\(category.rawValue)-\(style.rawValue).png")
                }
            }
        }
    }

    @Test("Hosted scheduled Overview preserves inclusive periods and real navigation",
          arguments: [false, true], ["ru_RU", "en_US"])
    func scheduledHeadingHostedNavigation(_ weekly: Bool, _ localeID: String) throws {
        let cycle: PayCalculationCycle = weekly
            ? .scheduled(.weekly(anchorDate: try LocalDate(year: 2026, month: 9, day: 7)))
            : .scheduled(.calendarMonthly)
        let job = try makeJob(cycle: cycle)
        let shifts = try [makeShift(id: 1, month: 9, day: 15), makeShift(id: 2, month: 9, day: 16)]
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let model = OverviewViewModel(job: job, loadShifts: { shifts }, currentDate: { now })
        let controller = OverviewViewController(viewModel: model, currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: Locale(identifier: localeID))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.isHidden = false
        defer { window.isHidden = true }
        let root = try requireRootView(controller)
        let original = try requireContent(model.state)
        let period: UILabel = try requireView(identifier: "overview.period.label", in: root)
        let time: UILabel = try requireView(identifier: "overview.receipt.perShiftTime", in: root)
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        let next: UIButton = try requireView(identifier: "overview.period.next", in: root)
        #expect(isEffectivelyHidden(time))
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
            controller.traitOverrides.preferredContentSizeCategory = category
            window.layoutIfNeeded()
            root.layoutIfNeeded()
            #expect(period.text?.contains("2026") == true)
            let data = try #require(UIGraphicsImageRenderer(bounds: root.bounds).image { context in
                root.layer.render(in: context.cgContext)
            }.pngData())
            // A UIWindow-hosted UIKit layer capture, not installed-app navigation evidence.
            Attachment.record(Array(data), named: "hosted-\(weekly ? "weekly" : "monthly")-\(localeID)-\(category.rawValue).png")
        }
        previous.sendActions(for: .touchUpInside)
        #expect(try requireContent(model.state).selectedPeriod != original.selectedPeriod)
        next.sendActions(for: .touchUpInside)
        let restored = try requireContent(model.state)
        #expect(restored.selectedPeriod == original.selectedPeriod)
        #expect(restored.expectedBreakdown?.expectedGross == original.expectedBreakdown?.expectedGross)
        #expect(shiftCardIdentifiers(in: root) == [shifts[1].id, shifts[0].id])
    }

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
                    #expect(item.accessibilityLabel == fallback.accessibilityLabel)
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
        let receipt: UIView = try requireView(identifier: "overview.period.card", in: root)
        let perShiftPeriod: UILabel = try requireView(identifier: "overview.receipt.perShiftPeriod", in: root)
        let time: UILabel = try requireView(identifier: "overview.receipt.perShiftTime", in: root)
        let heading = try #require(OverviewFormatting.perShiftHeading(
            latest, timeZoneIdentifier: "Europe/Stockholm", locale: displayLocale))
        #expect(perShiftPeriod.text == heading.date)
        #expect(time.text == heading.time)
        #expect(perShiftPeriod.accessibilityLabel == heading.accessibilityLabel)
        #expect(perShiftPeriod.isAccessibilityElement)
        #expect(!time.isAccessibilityElement)
        for size: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
            subject.viewController.traitOverrides.preferredContentSizeCategory = size
            window.layoutIfNeeded()
            root.layoutIfNeeded()
            let dateFrame = perShiftPeriod.convert(perShiftPeriod.bounds, to: receipt)
            let timeFrame = time.convert(time.bounds, to: receipt)
            #expect(timeFrame.minY >= dateFrame.maxY + 4)
            #expect(timeFrame.maxX <= receipt.bounds.width)
            #expect(perShiftPeriod.numberOfLines == 0 && time.numberOfLines == 0)
        }
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

    @Test("Hero exposes one combined gross accessibility element and the single Shift heading")
    func heroGrossAccessibilityAndShiftHeadingHaveOneHierarchy() throws {
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: [makeShift(id: 1, month: 9, day: 10)])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let context: UILabel = try requireView(identifier: "overview.expectedGross.label", in: root)
        let amount: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let gross: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        let heading: UIStackView = try requireView(identifier: "overview.shiftHistory.title", in: root)
        #expect(context.text == OverviewStrings.expectedGrossContext(currencyCode: "EUR"))
        #expect(amount.text == OverviewFormatting.heroAmount(160, currencyCode: "EUR", locale: displayLocale))
        #expect(context.isAccessibilityElement == false)
        #expect(amount.isAccessibilityElement)
        #expect(amount.accessibilityLabel == "\(context.text ?? ""), \(amount.text ?? "")")
        let grossElements = try #require(gross.accessibilityElements as? [UIView])
        #expect(grossElements.count == 1)
        #expect(grossElements[0] === amount)
        #expect(heading.isAccessibilityElement)
        #expect(heading.accessibilityLabel == "\(OverviewStrings.shiftHistoryCountTitle) 1")
        #expect(heading.arrangedSubviews.count == 2)
    }

    @Test("Shifts history separates its localized scope title from the internal count")
    func shiftHistoryUsesDistinctNavigationAndCountTitles() throws {
        for (language, expectedNavigationTitle, expectedCountTitle) in [
            ("ru", "Все смены", "Всего"),
            ("en", "All shifts", "Total")
        ] {
            let path = try #require(
                Bundle(for: OverviewViewController.self).path(forResource: language, ofType: "lproj")
            )
            let localization = try #require(Bundle(path: path))
            #expect(localization.localizedString(
                forKey: "overview.ledgerHistory.title", value: nil, table: "Localizable"
            ) == expectedNavigationTitle)
            #expect(localization.localizedString(
                forKey: "overview.ledgerHistory.countTitle", value: nil, table: "Localizable"
            ) == expectedCountTitle)
        }

        let shifts = try [
            makeShift(id: 1, month: 9, day: 10),
            makeShift(id: 2, month: 9, day: 11),
            makeShift(id: 3, month: 9, day: 12)
        ]
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: shifts)
        subject.viewController.showsShiftHistoryOnly = true
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 844))
        window.rootViewController = UINavigationController(rootViewController: subject.viewController)
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()

        let root = try requireRootView(subject.viewController)
        let title: UILabel = try requireView(identifier: "overview.shiftCount.label", in: root)
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        let counter: UIStackView = try requireView(identifier: "overview.shiftHistory.title", in: root)
        #expect(subject.viewController.title == OverviewStrings.allShiftHistory)
        #expect(subject.viewController.tabBarItem.title == String(localized: "tabs.shifts", table: "Localizable"))
        #expect(subject.viewController.navigationController?.tabBarItem.title == String(localized: "tabs.shifts", table: "Localizable"))
        #expect(root.accessibilityIdentifier == "shifts.screen")
        #expect(title.text == OverviewStrings.shiftHistoryCountTitle)
        #expect(count.text == "3")
        #expect(counter.accessibilityLabel == "\(OverviewStrings.shiftHistoryCountTitle) 3")
        #expect(title.text != subject.viewController.title)
        #expect(!title.convert(title.bounds, to: root).intersects(count.convert(count.bounds, to: root)))

        let empty = OverviewView()
        empty.renderHistoryOnly([], totalCount: 0, query: ShiftHistoryQuery())
        let emptyTitle: UILabel = try requireView(identifier: "overview.shiftCount.label", in: empty)
        let emptyCount: UILabel = try requireView(identifier: "overview.shiftCount.value", in: empty)
        #expect(emptyTitle.text == OverviewStrings.shiftHistoryCountTitle)
        #expect(emptyCount.text == "0")

        let home = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: shifts)
        home.viewController.usesHomeComposition = true
        home.viewController.loadViewIfNeeded()
        #expect((home.viewController.navigationItem.titleView as? UILabel)?.text == "ShiftLedger")
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
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        subject.viewController.loadViewIfNeeded()
        window.layoutIfNeeded()
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
        let gross: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        let exactTotal: UIView = try requireView(identifier: "overview.receipt.precision.exactField", in: root)
        let displayedTotal: UIView = try requireView(identifier: "overview.receipt.precision.displayedField", in: root)
        #expect(exactField.text == exactTwelve)
        #expect(displayedField.text == OverviewFormatting.currency(twelveAmount, currencyCode: "EUR", locale: displayLocale))
        let populatedGrossElements = try #require(gross.accessibilityElements as? [UIView])
        #expect(populatedGrossElements.count == 4)
        #expect(populatedGrossElements[0] === hero)
        #expect(populatedGrossElements[1] === exactTotal)
        #expect(populatedGrossElements[2] === displayedTotal)
        #expect(populatedGrossElements[3] === explanation)
        #expect(shiftCardIdentifiers(in: root).count == 13)
        let septemberCard: UIView = try requireView(
            identifier: "overview.shift.\(september[0].id.uuidString)", in: root
        )
        #expect(septemberCard.accessibilityLabel?.contains(exactOne) == true)

        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        previous.sendActions(for: .touchUpInside)
        #expect(hero.text == "1.00")
        #expect(isEffectivelyHidden(explanation)) // One rounded row already reconciles with the displayed total.
        let historicalGrossElements = try #require(gross.accessibilityElements as? [UIView])
        #expect(historicalGrossElements.count == 1)
        #expect(historicalGrossElements[0] === hero)
        #expect(shiftCardIdentifiers(in: root).count == 13)
        previous.sendActions(for: .touchUpInside)
        #expect(hero.text == "0.00")
        #expect(isEffectivelyHidden(explanation))
        let emptyGrossElements = try #require(gross.accessibilityElements as? [UIView])
        #expect(emptyGrossElements.count == 1)
        #expect(emptyGrossElements[0] === hero)
        #expect(shiftCardIdentifiers(in: root).count == 13)
        let next: UIButton = try requireView(identifier: "overview.period.next", in: root)
        next.sendActions(for: .touchUpInside)
        next.sendActions(for: .touchUpInside)
        #expect(hero.text == "12.05")
        let restoredGrossElements = try #require(gross.accessibilityElements as? [UIView])
        #expect(restoredGrossElements.count == 4)
        #expect(restoredGrossElements[0] === hero)
        #expect(restoredGrossElements[1] === exactTotal)
        #expect(restoredGrossElements[2] === displayedTotal)
        #expect(restoredGrossElements[3] === explanation)
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
            ).map(breakdown.shiftBreakdowns, workTypeNames: [testWorkTypeID: "Day"], selectedShiftID: nil, expandedShiftID: nil)
            #expect(cards.map(\.exactExpectedAmount) == [expectedFirst, expectedSecond])
            #expect(cards[0].appliedRate.hasPrefix(expectedFirst))
            #expect(cards[1].appliedRate.hasPrefix(expectedSecond))
            #expect(cards.map(\.appliedRateAmount) == [expectedFirst, expectedSecond])
            #expect(OverviewFormatting.displayedCurrencyValue(firstRate, currencyCode: "EUR", locale: locale) == 1)
        }
    }

    @Test("Tiny nonzero selected payroll remains explainable while a genuinely empty period has no note",
          arguments: ["0.004", "0.000000000000000001"], ["en_US", "ru_RU"])
    func receiptExplainsNonzeroDisplayedAsZero(_ amount: String, _ localeID: String) throws {
        let rate = try #require(Decimal(string: amount))
        let locale = Locale(identifier: localeID)
        let job = try Job(
            id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .fixedPerShift, payCalculationCycle: .scheduled(.calendarMonthly),
            payRates: [PayRate(amount: rate, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let shift = try makeShift(id: 1, month: 9, day: 10)
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = OverviewViewModel(job: job, loadShifts: { [shift] }, currentDate: { now })
        let controller = OverviewViewController(viewModel: viewModel, currencyCode: "EUR",
                                              timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale)
        controller.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(controller)
        let hero: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let exact: UILabel = try requireView(identifier: "overview.receipt.precision.exact", in: root)
        let note: UILabel = try requireView(identifier: "overview.receipt.precision", in: root)
        #expect(hero.text == OverviewFormatting.heroAmount(rate, currencyCode: "EUR", locale: locale))
        #expect(!isEffectivelyHidden(note))
        #expect(exact.text == OverviewFormatting.exactCurrency(rate, currencyCode: "EUR", locale: locale))
        #expect(exact.text != OverviewFormatting.currency(.zero, currencyCode: "EUR", locale: locale))
        #expect(try requireContent(viewModel.state).expectedBreakdown?.expectedGross == rate)
        #expect(shiftCardIdentifiers(in: root) == [shift.id])
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        previous.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()
        #expect(hero.text == OverviewFormatting.heroAmount(.zero, currencyCode: "EUR", locale: locale))
        #expect(isEffectivelyHidden(note))
        #expect(shiftCardIdentifiers(in: root) == [shift.id])
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        #expect(check.isEnabled)
        var requestedPeriod: PayCalculationPeriod?
        controller.onCheckPaycheck = { requestedPeriod = $0 }
        check.sendActions(for: .touchUpInside)
        #expect(requestedPeriod == (try requireContent(viewModel.state)).selectedPeriod)
    }

    @Test("Optional precision failure keeps valid payroll, history and paycheck navigation",
          arguments: [1, 3])
    func unavailablePrecisionDoesNotHideContent(_ failingCall: Int) throws {
        let rate = try #require(Decimal(string: "1.004"))
        let job = try Job(
            id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .fixedPerShift, payCalculationCycle: .scheduled(.calendarMonthly),
            payRates: [PayRate(amount: rate, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let shifts = try [makeShift(id: 1, month: 8, day: 31), makeShift(id: 2, month: 9, day: 1),
                          makeShift(id: 3, month: 9, day: 2)]
        let now = try date(year: 2026, month: 9, day: 18, hour: 12)
        let viewModel = OverviewViewModel(job: job, loadShifts: { shifts }, currentDate: { now })
        var calls = 0
        let controller = OverviewViewController(
            viewModel: viewModel, currencyCode: "EUR", timeZoneIdentifier: job.timeZoneIdentifier,
            displayLocale: displayLocale,
            displayedCurrencyValue: { amount, code, locale in
                calls += 1
                return calls == failingCall ? nil : OverviewFormatting.displayedCurrencyValue(amount, currencyCode: code, locale: locale)
            }
        )
        controller.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(controller)
        let hero: UILabel = try requireView(identifier: "overview.expectedGross.amount", in: root)
        let note: UILabel = try requireView(identifier: "overview.receipt.precision", in: root)
        let error: UILabel = try requireView(identifier: "overview.error.title", in: root)
        let count: UILabel = try requireView(identifier: "overview.shiftCount.value", in: root)
        #expect(hero.text == "2.01")
        #expect(!isEffectivelyHidden(hero))
        #expect(isEffectivelyHidden(note))
        #expect(isEffectivelyHidden(error))
        #expect(count.text == "3")
        #expect(shiftCardIdentifiers(in: root) == shifts.reversed().map(\.id))
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        #expect(check.isEnabled)
        var requestedPeriod: PayCalculationPeriod?
        controller.onCheckPaycheck = { requestedPeriod = $0 }
        check.sendActions(for: .touchUpInside)
        #expect(requestedPeriod == (try requireContent(viewModel.state)).selectedPeriod)
        let previous: UIButton = try requireView(identifier: "overview.period.previous", in: root)
        previous.sendActions(for: .touchUpInside)
        #expect(hero.text == "1.00")
        #expect(shiftCardIdentifiers(in: root) == shifts.reversed().map(\.id))
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

        let root = try requireRootView(subject.viewController)
        for identifier in ["overview.period.card", "overview.expectedGross.hero", "overview.shiftHistory.section"] {
            let card: UIView = try requireView(identifier: identifier, in: root)
            #expect(isEffectivelyHidden(card) == false)
            #expect(card.layer.cornerRadius == 16)
            #expect(card.layer.sublayers?.contains { $0 is CAShapeLayer } != true)
            for (style, rgb) in [(UIUserInterfaceStyle.light, 0xFFFFFF), (.dark, 0x1C1D24), (.light, 0xFFFFFF)] {
                window.overrideUserInterfaceStyle = style
                window.layoutIfNeeded()
                let fill = try #require(card.backgroundColor)
                let components = try colorComponents(fill, traits: card.traitCollection)
                #expect(abs(components.red - CGFloat((rgb >> 16) & 255) / 255) < 0.001)
                #expect(abs(components.green - CGFloat((rgb >> 8) & 255) / 255) < 0.001)
                #expect(abs(components.blue - CGFloat(rgb & 255) / 255) < 0.001)
            }
        }
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

    @Test("Receipt rate retains its exact amount and complete unit at accessibility sizes",
          arguments: ["en_US", "ru_RU"])
    func receiptRateReflowsWithoutSplittingUnit(_ localeIdentifier: String) throws {
        let exactRate = try #require(Decimal(string: "1.004"))
        let amount = try #require(OverviewFormatting.exactCurrency(
            exactRate, currencyCode: "EUR", locale: Locale(identifier: localeIdentifier)))
        let fullRate = amount + " / " + PaycheckResultStrings.rateShift
        let wrappedRate = amount + "\n/\u{00a0}" + PaycheckResultStrings.rateShift
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
        field.update(label: PaycheckResultStrings.rate, value: fullRate, wrappedValue: wrappedRate, identifier: "rate")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        #expect(field.value.text == fullRate)
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.layoutIfNeeded()
        #expect(field.axis == .vertical)
        #expect(field.value.text == wrappedRate)
        #expect(field.accessibilityLabel == "\(PaycheckResultStrings.rate), \(fullRate)")
        #expect(field.label.frame.maxY <= field.value.frame.minY)
        #expect(field.value.frame.height + 0.5 >= field.value.sizeThatFits(
            CGSize(width: field.value.bounds.width, height: .greatestFiniteMagnitude)).height)
        host.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        #expect(field.value.text == fullRate)
    }

    @Test("Full Russian break metadata stacks before either text is compressed",
          arguments: [CGFloat(320), CGFloat(375), CGFloat(402)], [false, true])
    func unpaidBreakFieldUsesStableVerticalLayout(_ width: CGFloat, _ accessibilitySize: Bool) throws {
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = accessibilitySize ? .accessibilityExtraExtraLarge : .large
        let field = OverviewReceiptFieldView()
        field.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 60),
            field.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -60),
            field.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 80)
        ])
        let title = "Неоплачиваемый перерыв"
        let text = "6 ноября 2026 г., 14:43–15:43 · 1 ч"
        field.update(label: title, value: text, identifier: "break")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let height = field.bounds.height
        for _ in 0..<5 {
            field.setNeedsLayout()
            window.layoutIfNeeded()
            field.layoutIfNeeded()
            #expect(field.axis == .vertical)
            #expect(abs(field.bounds.height - height) < 0.5)
            #expect(field.label.frame.maxY + field.spacing <= field.value.frame.minY + 0.5)
        }
        #expect(field.label.text == title)
        #expect(field.value.text == text)
        #expect(field.accessibilityLabel == "\(title), \(text)")
        for label in [field.label, field.value] {
            #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
        }
        field.update(label: "Rate", value: "€1.004 / shift", identifier: "rate")
        window.layoutIfNeeded()
        #expect(field.axis == (accessibilitySize ? .vertical : .horizontal))
    }

    @Test("Mapped break distinguishes same-day, multi-day and midnight calendar context",
          arguments: [0, 1, 2], ["en_US", "ru_RU"])
    func mappedBreakPreservesCalendarContext(_ scenario: Int, _ localeID: String) throws {
        let job = try Job(id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                          basePayBasis: .hourly, payCalculationCycle: .perShift,
                          payRates: [PayRate(amount: 100, effectiveFrom: nil)],
                          createdAt: Date(timeIntervalSinceReferenceDate: 0))
        let start = try date(year: 2026, month: 11, day: 5, hour: 8)
        let breakStart = try date(year: 2026, month: 11, day: scenario == 0 ? 5 : 6,
                                 hour: scenario == 2 ? 22 : 12)
        let unpaidBreak = UnpaidBreak(start: breakStart, end: breakStart.addingTimeInterval(scenario == 2 ? 7200 : 3600))
        let end = try date(year: 2026, month: 11, day: scenario == 0 ? 5 : 7, hour: scenario == 0 ? 16 : 8)
        let shift = try Shift(jobID: job.id, workTypeID: testWorkTypeID, start: start, end: end, unpaidBreak: unpaidBreak)
        let breakdown = try job.expectedGrossBreakdown(for: .perShift(shiftID: shift.id), from: [shift])
        let locale = Locale(identifier: localeID)
        let card = try #require(OverviewShiftCardMapper(currencyCode: "EUR", timeZoneIdentifier: job.timeZoneIdentifier,
            displayLocale: locale).map(breakdown.shiftBreakdowns, workTypeNames: [testWorkTypeID: "Day"],
                    selectedShiftID: shift.id, expandedShiftID: shift.id).first)
        let interval = try #require(card.unpaidBreakTimeRange)
        let expected = DateIntervalFormatter()
        expected.locale = locale
        expected.timeZone = TimeZone(identifier: job.timeZoneIdentifier)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = expected.timeZone
        expected.calendar = calendar
        expected.dateStyle = scenario == 0 ? .none : .long
        expected.timeStyle = .short
        #expect(interval == expected.string(from: unpaidBreak.start, to: unpaidBreak.end))
        expected.dateStyle = .long
        let fullInterval = expected.string(from: unpaidBreak.start, to: unpaidBreak.end)
        #expect(card.accessibilityLabel.contains(fullInterval))
        #expect(card.id == shift.id)
        #expect(card.expectedAmount == OverviewFormatting.currency(breakdown.expectedGross, currencyCode: "EUR", locale: locale))
        #expect(card.paidDuration == OverviewFormatting.duration(shift.paidDuration))
    }

    @Test("Shift time range remains readable when it wraps",
          arguments: [CGFloat(320), CGFloat(375), CGFloat(402)], ["en_US", "ru_RU"])
    func receiptTimeRangeReflowsAsAWhole(_ width: CGFloat, _ localeID: String) throws {
        for hour in [8, 11] {
            let job = try makeJob(cycle: .scheduled(.calendarMonthly))
            let start = try date(year: 2026, month: 9, day: 10, hour: hour)
            let shift = try Shift(id: UUID(), jobID: job.id, workTypeID: testWorkTypeID,
                                  start: start, end: start.addingTimeInterval(3600))
            let subject = try makeSubject(job: job, shifts: [shift])
            let locale = Locale(identifier: localeID)
            let controller = OverviewViewController(viewModel: subject.viewModel, currencyCode: job.currencyCode,
                timeZoneIdentifier: job.timeZoneIdentifier, displayLocale: locale)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }
            let root = try requireRootView(controller)
            let prefix = "overview.shift.\(shift.id.uuidString)"
            let row: UIControl = try requireView(identifier: prefix, in: root)
            let time: UILabel = try requireView(identifier: "\(prefix).time", in: row)
            let duration: UILabel = try requireView(identifier: "\(prefix).duration", in: row)
            let amount: UILabel = try requireView(identifier: "\(prefix).expected", in: row)
            let expected = try #require(OverviewFormatting.shiftRowHeading(shift,
                timeZoneIdentifier: job.timeZoneIdentifier, locale: locale)).time
            for style in [UIUserInterfaceStyle.light, .dark] {
                controller.overrideUserInterfaceStyle = style
                for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
                    controller.traitOverrides.preferredContentSizeCategory = category
                    for _ in 0..<5 { root.setNeedsLayout(); window.layoutIfNeeded() }
                    let pixel = 1 / window.screen.scale
                    #expect(time.text == expected)
                    #expect(!expected.contains("…"))
                    #expect(time.numberOfLines == 0 && time.lineBreakMode == .byWordWrapping)
                    #expect(time.bounds.height + pixel >= time.sizeThatFits(
                        CGSize(width: time.bounds.width, height: .greatestFiniteMagnitude)).height)
                    let frames = [time, duration, amount].map { $0.convert($0.bounds, to: row) }
                    #expect(!frames[0].intersects(frames[1]) && !frames[0].intersects(frames[2]))
                    for frame in frames {
                        #expect(frame.minX >= -pixel && frame.maxX <= row.bounds.maxX + pixel)
                        #expect(frame.minY >= -pixel && frame.maxY <= row.bounds.maxY + pixel)
                    }
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineBreakMode = time.lineBreakMode
                    paragraph.lineBreakStrategy = time.lineBreakStrategy
                    let storage = NSTextStorage(string: expected, attributes: [.font: time.font as Any, .paragraphStyle: paragraph])
                    let manager = NSLayoutManager()
                    let container = NSTextContainer(size: CGSize(width: time.bounds.width, height: .greatestFiniteMagnitude))
                    container.lineFragmentPadding = 0
                    manager.addTextContainer(container)
                    storage.addLayoutManager(manager)
                    manager.ensureLayout(for: container)
                    let glyphRange = manager.glyphRange(for: container)
                    #expect(NSMaxRange(manager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)) == (expected as NSString).length)
                    let clockPattern = try NSRegularExpression(pattern: #"\d{1,2}:\d{2}"#)
                    let clockRanges = clockPattern.matches(in: expected, range: NSRange(location: 0, length: (expected as NSString).length))
                    #expect(clockRanges.count == 2)
                    for match in clockRanges {
                        let glyphs = manager.glyphRange(forCharacterRange: match.range, actualCharacterRange: nil)
                        var line = NSRange()
                        _ = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: &line)
                        #expect(NSMaxRange(glyphs) <= NSMaxRange(line))
                    }
                    manager.enumerateLineFragments(forGlyphRange: glyphRange) { _, used, _, _, _ in
                        #expect(used.minX >= -pixel && used.maxX <= time.bounds.width + pixel)
                    }
                    let prior = [time.frame, duration.frame, amount.frame, row.frame]
                    for _ in 0..<3 { root.setNeedsLayout(); window.layoutIfNeeded() }
                    #expect(prior == [time.frame, duration.frame, amount.frame, row.frame])
                    let image = UIGraphicsImageRenderer(bounds: row.bounds).image { context in
                        row.layer.render(in: context.cgContext)
                    }
                    let appearance = style == .light ? "light" : "dark"
                    let size = category == .large ? "normal" : "axxxl"
                    Attachment.record(Array(try #require(image.pngData())),
                        named: "SL538-\(localeID)-\(Int(width))-\(hour)-\(appearance)-\(size).png")
                }
            }
            if try requireContent(subject.viewModel.state).selectedShiftID != shift.id {
                row.sendActions(for: .touchUpInside)
                #expect(try requireContent(subject.viewModel.state).expandedShiftID == shift.id)
                row.sendActions(for: .touchUpInside)
            }
            #expect(try requireContent(subject.viewModel.state).selectedShiftID == shift.id)
            row.sendActions(for: .touchUpInside)
            #expect(try requireContent(subject.viewModel.state).expandedShiftID == shift.id)
            row.sendActions(for: .touchUpInside)
            #expect(try requireContent(subject.viewModel.state).expandedShiftID == nil)
        }
    }

    @Test("Expanded details retain exact hourly and fixed rates without repeating the summary",
          arguments: [false, true], ["en_US", "ru_RU"])
    func expandedDetailsContainOnlyAdditionalFields(_ accessibilitySize: Bool, _ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let exactRate = try #require(Decimal(string: "1.004"))
        for basis in [BasePayBasis.hourly, .fixedPerShift] {
            let job = try Job(id: testWorkTypeID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
                              basePayBasis: basis, payCalculationCycle: .perShift,
                              payRates: [PayRate(amount: exactRate, effectiveFrom: nil)],
                              createdAt: Date(timeIntervalSinceReferenceDate: 0))
            let start = try date(year: 2026, month: 9, day: 10, hour: 8)
            let shift = try Shift(jobID: job.id, workTypeID: testWorkTypeID, start: start, end: start.addingTimeInterval(3600))
            let breakdown = try job.expectedGrossBreakdown(for: .perShift(shiftID: shift.id), from: [shift])
            let card = try #require(OverviewShiftCardMapper(currencyCode: "EUR", timeZoneIdentifier: job.timeZoneIdentifier,
                displayLocale: locale).map(breakdown.shiftBreakdowns, workTypeNames: [testWorkTypeID: "Day"],
                    selectedShiftID: shift.id, expandedShiftID: shift.id).first)
            let row = OverviewShiftLedgerRowView()
            let host = UIViewController()
            host.traitOverrides.preferredContentSizeCategory = accessibilitySize ? .accessibilityExtraExtraLarge : .large
            row.translatesAutoresizingMaskIntoConstraints = false
            host.view.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 60),
                row.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 20),
                row.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -20)
            ])
            var editedShiftIDs: [UUID] = []
            row.update(card, showsDivider: false, onCardTapped: nil) { editedShiftIDs.append($0) }
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.rootViewController = host
            window.isHidden = false
            defer { window.isHidden = true }
            window.layoutIfNeeded()
            let prefix = "overview.shift.\(shift.id.uuidString)"
            let rate: UILabel = try requireView(identifier: "\(prefix).detail.rate", in: row)
            if accessibilitySize {
                let time: UILabel = try requireView(identifier: "\(prefix).time", in: row)
                #expect(abs(rate.convert(rate.bounds, to: row).minX
                    - time.convert(time.bounds, to: row).minX) < 0.5)
            }
            let rateLabel: UILabel = try requireView(identifier: "\(prefix).detail.rate.label", in: row)
            #expect(rateLabel.bounds.height + 0.5 >= rateLabel.sizeThatFits(
                CGSize(width: rateLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
            let unit = basis == .hourly ? PaycheckResultStrings.rateHour : PaycheckResultStrings.rateShift
            let fullWidth = card.appliedRate.size(withAttributes: [.font: rate.font as Any]).width
            let expectedRate = fullWidth > rate.bounds.width
                ? card.appliedRate.replacingOccurrences(of: " / ", with: "\n/\u{00a0}") : card.appliedRate
            #expect(rate.text == expectedRate)
            #expect(rate.text?.contains(unit) == true)
            #expect(rate.text?.contains(try #require(OverviewFormatting.exactCurrency(exactRate, currencyCode: "EUR", locale: locale))) == true)
            #expect(rate.bounds.height + 0.5 >= rate.sizeThatFits(CGSize(width: rate.bounds.width, height: .greatestFiniteMagnitude)).height)
            #expect(row.accessibilityLabel?.contains(card.appliedRate) == true)
            #expect(row.accessibilityLabel?.contains(try #require(card.exactExpectedAmount)) == true)
            #expect(row.accessibilityLabel?.components(separatedBy: PaycheckResultStrings.paidTime).count == 2)
            for removed in ["endpoints", "detail.paidTime", "detail.payBasis"] {
                #expect(descendant(identifier: "\(prefix).\(removed)", in: row) == nil)
            }
            let edit: UIButton = try requireView(identifier: "\(prefix).edit", in: row)
            #expect(!edit.isHidden)
            #expect(row.accessibilityCustomActions?.map(\.name) == [OverviewStrings.editShift])
            #expect(edit.isAccessibilityElement)
            edit.sendActions(for: .touchUpInside)
            #expect(editedShiftIDs == [shift.id])

            row.update(card, showsDivider: false, onCardTapped: nil, onEditTapped: nil)
            #expect(edit.isHidden)
            #expect(!edit.isAccessibilityElement)
            #expect(row.accessibilityCustomActions?.isEmpty ?? true)
        }
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
        #expect(heading.text == OverviewStrings.shiftHistoryCountTitle)
        #expect(heading.text?.hasSuffix("·") == false)
        #expect(heading.bounds.width <= width - 64 + 0.5)
        #expect(heading.lineBreakMode == .byWordWrapping)
        #expect(heading.bounds.height + 0.5 >= heading.sizeThatFits(
            CGSize(width: heading.bounds.width, height: .greatestFiniteMagnitude)).height)
        #expect(heading.convert(heading.bounds, to: root).maxY <= count.convert(count.bounds, to: root).minY)
    }

    @Test("Overview cards and actions remain in vertical reading order")
    func overviewCardsPrecedeActions() throws {
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
        let history: UIView = try requireView(identifier: "overview.shiftHistory.section", in: root)
        let check: UIButton = try requireView(identifier: "overview.checkPaycheck", in: root)
        let add: UIButton = try requireView(identifier: "overview.addShift", in: root)
        let period: UIView = try requireView(identifier: "overview.period.card", in: root)
        let gross: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        let historyFrame = history.convert(history.bounds, to: root)
        let grossFrame = gross.convert(gross.bounds, to: root)
        #expect(period.convert(period.bounds, to: root).maxY + 15.5 <= grossFrame.minY)
        #expect(grossFrame.maxY + 15.5 <= historyFrame.minY)
        let checkFrame = check.convert(check.bounds, to: root)
        let addFrame = add.convert(add.bounds, to: root)
        #expect(historyFrame.maxY + 15.5 <= checkFrame.minY)
        #expect(checkFrame.maxY <= addFrame.minY)
    }

    @Test("Overview keeps cards, columns and actions inside wide and narrow viewports",
          arguments: [CGFloat(402), CGFloat(375), CGFloat(320)])
    func cardMarginsMatchViewport(_ width: CGFloat) throws {
        let shift = try makeShift(id: 1, month: 9, day: 10)
        let subject = try makeSubject(job: makeJob(cycle: .scheduled(.calendarMonthly)), shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: width == 375 ? 667 : 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let root = try requireRootView(subject.viewController)
        let paper: UIView = try requireView(identifier: "overview.shiftHistory.section", in: root)
        let row: UIView = try requireView(identifier: "overview.shift.\(shift.id.uuidString)", in: root)
        let paperFrame = paper.convert(paper.bounds, to: root)
        let rowFrame = row.convert(row.bounds, to: root)
        #expect(abs(paperFrame.minX - 16) < 0.5)
        #expect(abs(paperFrame.width - (width - 32)) < 0.5)
        #expect(abs(rowFrame.minX - 32) < 0.5)
        #expect(abs(rowFrame.width - (width - 64)) < 0.5)
        let halfPixel = 0.5 / row.traitCollection.displayScale
        #expect(rowFrame.height + halfPixel >= 92)
        let rowContent = try #require(row.subviews.compactMap { $0 as? UIStackView }.first)
        #expect(abs(rowContent.frame.minY - 16) <= halfPixel)
        #expect(abs(rowContent.frame.maxY - (row.bounds.height - 16)) <= halfPixel)
        for identifier in ["overview.checkPaycheck", "overview.addShift"] {
            let button: UIButton = try requireView(identifier: identifier, in: root)
            let frame = button.convert(button.bounds, to: root)
            #expect(abs(frame.minX - 16) < 0.5)
            #expect(abs(frame.width - (width - 32)) < 0.5)
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
        #expect(try requireContent(subject.viewModel.state).selectedShiftID == older.id)
        #expect(try requireContent(subject.viewModel.state).expandedShiftID == older.id)
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
        #expect(label.text == "September 2026")
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
        #expect(frontDate.text == OverviewFormatting.shiftRowHeading(
            newer,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        )?.date)
        #expect(amount.text == OverviewFormatting.currency(
            Decimal(160),
            currencyCode: job.currencyCode,
            locale: displayLocale
        ))
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(newer.paidDuration)))
        let expectedTime = try #require(OverviewFormatting.shiftRowHeading(
            newer,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        )?.time)
        let time: UILabel = try requireView(identifier: "overview.shift.\(newer.id.uuidString).time",
            in: try requireRootView(subject.viewController))
        #expect(time.text == expectedTime)
        #expect(descendant(identifier: "overview.shift.\(newer.id.uuidString).endpoints", in: newestRow) == nil)
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
        #expect(date.text == OverviewFormatting.shiftRowHeading(
            older,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        )?.date)
        #expect(time.text == OverviewFormatting.shiftRowHeading(
            older,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: displayLocale
        )?.time)
        #expect(amount.text == OverviewFormatting.currency(
            160, currencyCode: job.currencyCode, locale: displayLocale
        ))
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(older.paidDuration)))
        #expect(isEffectivelyHidden(rate))
        #expect(descendant(identifier: "overview.shift.\(older.id.uuidString).endpoints", in: card) == nil)
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
        let halfPixel = 0.5 / max(root.traitCollection.displayScale, 1)
        #expect(front.convert(front.bounds, to: root).maxY <= covered.convert(covered.bounds, to: root).minY + halfPixel)
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
    func onlyExpandedLedgerRowShowsAdditionalDetails() throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let older = try makeShift(id: 1, month: 9, day: 10)
        let newer = try makeShift(id: 2, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [older, newer])
        subject.viewController.loadViewIfNeeded()

        let newerDetails: UIView = try requireView(
            identifier: "overview.shift.\(newer.id.uuidString).detail.rate",
            in: try requireRootView(subject.viewController)
        )
        let olderDetails: UIView = try requireView(
            identifier: "overview.shift.\(older.id.uuidString).detail.rate",
            in: try requireRootView(subject.viewController)
        )
        #expect(isEffectivelyHidden(newerDetails))
        #expect(isEffectivelyHidden(olderDetails))
        let olderRow: UIControl = try requireView(
            identifier: "overview.shift.\(older.id.uuidString)",
            in: try requireRootView(subject.viewController)
        )
        olderRow.sendActions(for: .touchUpInside)
        olderRow.sendActions(for: .touchUpInside)
        #expect(isEffectivelyHidden(olderDetails) == false)
        #expect(isEffectivelyHidden(newerDetails))
    }

    @Test("Expanded ledger retains one summary and readable additional break and rate fields",
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
        let time: UILabel = try requireView(identifier: "\(prefix).time", in: card)
        let rate: UILabel = try requireView(identifier: "\(prefix).detail.rate", in: card)
        let duration: UILabel = try requireView(identifier: "\(prefix).duration", in: try requireRootView(subject.viewController))
        let unpaidBreak: UILabel = try requireView(identifier: "\(prefix).detail.break", in: try requireRootView(subject.viewController))

        #expect(descendant(identifier: "\(prefix).timeline", in: card) == nil)
        for removed in ["endpoints", "detail.paidTime", "detail.payBasis"] {
            #expect(descendant(identifier: "\(prefix).\(removed)", in: card) == nil)
        }
        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(shift.paidDuration)))
        #expect(isEffectivelyHidden(duration) == false)
        #expect(unpaidBreak.text?.contains(OverviewFormatting.duration(30 * 60)) == true)
        #expect(card.accessibilityLabel?.contains(AddShiftStrings.unpaidBreak) == true)
        #expect(card.accessibilityLabel?.contains(OverviewFormatting.duration(shift.paidDuration)) == true)

        let timeFrame = time.convert(time.bounds, to: card)
        let breakFrame = unpaidBreak.convert(unpaidBreak.bounds, to: card)
        let rateFrame = rate.convert(rate.bounds, to: card)
        #expect(timeFrame.maxY < breakFrame.minY)
        #expect(breakFrame.maxY < rateFrame.minY)
        #expect(rate.text?.contains(PaycheckResultStrings.rateHour) == true)
        #expect(card.accessibilityLabel?.contains(PaycheckResultStrings.rateHour) == true)
        for label in [time, rate, duration, unpaidBreak] {
            #expect(label.adjustsFontForContentSizeCategory)
            #expect(label.bounds.width > 0)
            #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            ).height)
        }
        #expect(time.isAccessibilityElement == false)
        #expect(rate.isAccessibilityElement == false)
    }

    @Test("Expanded row preserves complete local endpoints in its accessible summary")
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

        let prefix = "overview.shift.\(overnight.id.uuidString)"
        let endpoints = try #require(OverviewFormatting.shiftEndpoints(overnight,
            timeZoneIdentifier: job.timeZoneIdentifier, locale: displayLocale))
        let startTime: UILabel = try requireView(identifier: "\(prefix).startTime", in: card)
        let endTime: UILabel = try requireView(identifier: "\(prefix).endTime", in: card)
        #expect(startTime.text == endpoints.startTime)
        #expect(endTime.text == endpoints.endTime)
        let interval: UIStackView = try requireView(identifier: "\(prefix).time", in: card)
        #expect(startTime.isDescendant(of: interval))
        #expect(endTime.isDescendant(of: interval))
        #expect(interval.accessibilityLabel?.contains(endpoints.startTime) == true)
        #expect(interval.accessibilityLabel?.contains(endpoints.endTime) == true)
        #expect(descendant(identifier: "overview.shift.\(overnight.id.uuidString).endpoints", in: card) == nil)
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
            expectedAmount: "€123,456,789,012.90",
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

    @Test("Shift rows keep complete endpoints across widths and traits",
          arguments: [CGFloat(320), 375, 402], ["ru_RU", "en_US"])
    func rowBoundaryGeometry(_ width: CGFloat, _ localeID: String) throws {
        let fixtures = [
            ("2026-09-10T14:43:00Z", "2026-09-10T16:43:00Z", "Europe/Stockholm"),
            ("2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z", "America/New_York"),
            ("2026-03-08T06:30:00Z", "2026-03-08T07:30:00Z", "America/New_York"),
            ("2026-09-10T22:55:00Z", "2026-09-11T06:30:00Z", "Europe/Stockholm"),
            ("2026-09-30T21:55:00Z", "2026-10-01T06:30:00Z", "Europe/Stockholm"),
            ("2026-12-31T21:55:00Z", "2027-01-01T06:30:00Z", "Europe/Stockholm"),
            ("2026-09-10T12:43:00Z", "2026-09-12T12:43:00Z", "Europe/Stockholm"),
            ("2026-11-11T15:55:00Z", "2026-11-12T15:55:00Z", "Europe/Stockholm")
        ]
        for (scenario, (startText, endText, zone)) in fixtures.enumerated() {
            let isDST = scenario == 1 || scenario == 2
            let isOriginalOvernight = scenario == 7
            let job = try Job(id: testWorkTypeID, currencyCode: "EUR",
                timeZoneIdentifier: zone,
                basePayBasis: isOriginalOvernight ? .fixedPerShift : .hourly,
                payCalculationCycle: isOriginalOvernight ? .perShift : .scheduled(.calendarMonthly),
                payRates: [try PayRate(amount: isOriginalOvernight ? 1 : 20, effectiveFrom: nil)],
                createdAt: Date(timeIntervalSinceReferenceDate: 0))
            let formatter = ISO8601DateFormatter()
            let start = try #require(formatter.date(from: startText))
            let end = try #require(formatter.date(from: endText))
            let shift = try Shift(id: UUID(), jobID: job.id, workTypeID: testWorkTypeID,
                                  start: start, end: end)
            if scenario == 6 { #expect(shift.paidDuration == 48 * 3600) }
            if isOriginalOvernight { #expect(shift.paidDuration == 24 * 3600) }
            let subject = try makeSubject(job: job, shifts: [shift])
            let locale = Locale(identifier: localeID)
            let controller = OverviewViewController(viewModel: subject.viewModel, currencyCode: job.currencyCode,
                timeZoneIdentifier: zone, displayLocale: locale)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }
            let root = try requireRootView(controller)
            let prefix = "overview.shift.\(shift.id.uuidString)"
            let row: UIControl = try requireView(identifier: prefix, in: root)
            let date: UILabel = try requireView(identifier: "\(prefix).date", in: row)
            let endpoints = try #require(OverviewFormatting.shiftEndpoints(shift,
                timeZoneIdentifier: zone, locale: locale))
            let multiDay = endpoints.endDate != nil
            let time: UILabel = try requireView(identifier: "\(prefix).\(multiDay ? "endTime" : "time")", in: row)
            let startTime: UILabel = try requireView(identifier: "\(prefix).startTime", in: row)
            let endDate: UILabel = try requireView(identifier: "\(prefix).endDate", in: row)
            let amount: UILabel = try requireView(identifier: "\(prefix).expected", in: row)
            let duration: UILabel = try requireView(identifier: "\(prefix).duration", in: row)
            let initialMoney = amount.text
            let initialDuration = duration.text
            let expected = try #require(OverviewFormatting.shiftRowHeading(shift,
                timeZoneIdentifier: zone, locale: locale))
            for appearance in [UIUserInterfaceStyle.light, .dark] {
                controller.overrideUserInterfaceStyle = appearance
                for (step, category) in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large].enumerated() {
                    controller.traitOverrides.preferredContentSizeCategory = category
                    for _ in 0..<5 { root.setNeedsLayout(); window.layoutIfNeeded() }
                    #expect(date.text == (endpoints.startDate ?? expected.date))
                    #expect(time.text == (multiDay ? endpoints.endTime : expected.time))
                    let summary = try #require(duration.superview?.superview as? UIStackView)
                    #expect(summary.spacing == (summary.axis == .vertical ? 12 : 8))
                    #expect(isEffectivelyHidden(startTime) == !multiDay)
                    #expect(isEffectivelyHidden(endDate) == !multiDay)
                    if let end = endpoints.endDate {
                        #expect(startTime.text == endpoints.startTime)
                        #expect(endDate.text == "→ \(end)")
                        let interval: UIStackView = try requireView(identifier: "\(prefix).time", in: row)
                        #expect(interval.accessibilityLabel?.contains(end) == true)
                        #expect(time.isDescendant(of: interval))
                        #expect(startTime.isDescendant(of: interval))
                        let startFrame = startTime.convert(startTime.bounds, to: row)
                        let endDateFrame = endDate.convert(endDate.bounds, to: row)
                        let endTimeFrame = time.convert(time.bounds, to: row)
                        #expect(startFrame.minY >= date.convert(date.bounds, to: row).maxY + 7.5)
                        #expect(endDateFrame.minY >= startFrame.maxY + 7.5)
                        #expect(endTimeFrame.minY >= endDateFrame.maxY + 7.5)
                        #expect(duration.convert(duration.bounds, to: row).minY >= endTimeFrame.maxY + 11.5)
                    }
                    #expect(date.lineBreakMode == .byWordWrapping)
                    #expect(time.lineBreakMode == .byWordWrapping)
                    let headingFrames = [date, amount].map { $0.convert($0.bounds, to: row) }
                    #expect(!headingFrames[0].intersects(headingFrames[1]))
                    if !category.isAccessibilityCategory && headingFrames[0].minX < headingFrames[1].minX {
                        #expect(abs(headingFrames[1].maxX - (row.bounds.width - 16)) <= 0.5)
                    }
                    if isDST {
                        #expect(time.text?.contains("GMT-04:00") == true)
                        #expect(time.text?.contains("GMT-05:00") == true)
                    }
                    if isDST {
                        let clock = localeID == "ru_RU" ? "01:30" : "1:30 AM"
                        let endClock = scenario == 1 ? clock : (localeID == "ru_RU" ? "03:30" : "3:30 AM")
                        let startOffset = scenario == 1 ? "GMT-04:00" : "GMT-05:00"
                        let endOffset = scenario == 1 ? "GMT-05:00" : "GMT-04:00"
                        let normalized = (time.text ?? "").components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }.joined(separator: " ")
                        #expect(normalized == "\(clock) \(startOffset)–\(endClock) \(endOffset)")
                        let storage = NSTextStorage(string: time.text ?? "", attributes: [.font: time.font as Any])
                        let manager = NSLayoutManager()
                        let container = NSTextContainer(size: CGSize(width: time.bounds.width, height: .greatestFiniteMagnitude))
                        container.lineFragmentPadding = 0
                        container.lineBreakMode = time.lineBreakMode
                        manager.addTextContainer(container)
                        storage.addLayoutManager(manager)
                        manager.ensureLayout(for: container)
                        for offset in ["GMT-04:00", "GMT-05:00"] {
                            let range = ((time.text ?? "") as NSString).range(of: offset)
                            let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                            var line = NSRange()
                            _ = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: &line)
                            #expect(NSMaxRange(glyphs) <= NSMaxRange(line))
                        }
                        if category.isAccessibilityCategory { #expect(time.font.pointSize >= 17) }
                        if category == .large { #expect(abs(time.font.pointSize - 14) < 0.01) }
                        #expect(amount.text == OverviewFormatting.currency(20, currencyCode: "EUR", locale: locale))
                        #expect(shift.paidDuration == 3600)
                        #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(3600)))
                        #expect(shift.end == ISO8601DateFormatter().date(from: scenario == 1
                            ? "2026-11-01T06:30:00Z" : "2026-03-08T07:30:00Z"))
                        print("SL531 HOSTED \(width) \(localeID) scenario=\(scenario) \(appearance.rawValue) \(category.rawValue) row=\(row.bounds) date=\(date.frame) time=\(time.frame) font=\(time.font.pointSize) money=\(amount.frame) duration=\(duration.frame)")
                        if step < 2 {
                            let data = try #require(UIGraphicsImageRenderer(bounds: row.bounds).image { context in
                                row.layer.render(in: context.cgContext)
                            }.pngData())
                            let fixture = scenario == 1 ? "fallback" : "spring"
                            let style = appearance == .light ? "light" : "dark"
                            let size = category == .large ? "normal" : "axxxl"
                            Attachment.record(Array(data), named: "dst-\(fixture)-\(localeID)-\(Int(width))-\(style)-\(size).png")
                        }
                    }
                    if scenario >= 5 && step < 2 {
                        let fixture = scenario == 5 ? "cross-year" : scenario == 6 ? "48-hour" : "overnight-november"
                        let style = appearance == .light ? "light" : "dark"
                        let size = category == .large ? "normal" : "axxxl"
                        let data = try #require(UIGraphicsImageRenderer(bounds: row.bounds).image { context in
                            row.layer.render(in: context.cgContext)
                        }.pngData())
                        Attachment.record(Array(data), named: "\(fixture)-\(localeID)-\(Int(width))-\(style)-\(size).png")
                    }
                    #expect(amount.text == initialMoney && duration.text == initialDuration)
                    try assertPaidWords(duration)
                    #expect(duration.text == OverviewStrings.paidDuration(OverviewFormatting.duration(shift.paidDuration)))
                    let visibleLabels = [date, time, amount, duration] + (multiDay ? [startTime, endDate] : [])
                    for label in visibleLabels {
                        #expect(label.bounds.width > 0)
                        #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
                            CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
                        let frame = label.convert(label.bounds, to: row)
                        #expect(frame.minX >= 0 && frame.maxX <= row.bounds.width + 0.5)
                        #expect(frame.minY >= 0 && frame.maxY <= row.bounds.height + 0.5)
                    }
                    let endFrame = time.convert(time.bounds, to: row)
                    let amountFrame = amount.convert(amount.bounds, to: row)
                    #expect(!endFrame.intersects(amountFrame))
                    #expect(time.convert(time.bounds, to: row).minY >= date.convert(date.bounds, to: row).maxY)
                    let frames = [date.frame, time.frame, amount.frame, duration.frame]
                    for _ in 0..<3 { root.setNeedsLayout(); window.layoutIfNeeded() }
                    #expect(frames == [date.frame, time.frame, amount.frame, duration.frame])
                    #expect(row.hitTest(CGPoint(x: 8, y: 8), with: nil) === row)
                }
            }
            if try requireContent(subject.viewModel.state).selectedShiftID != shift.id {
                row.sendActions(for: .touchUpInside)
                #expect(try requireContent(subject.viewModel.state).expandedShiftID == shift.id)
                row.sendActions(for: .touchUpInside)
            }
            let selected = try requireContent(subject.viewModel.state)
            #expect(selected.selectedShiftID == shift.id)
            #expect(selected.expandedShiftID == nil)
            row.sendActions(for: .touchUpInside)
            #expect(try requireContent(subject.viewModel.state).expandedShiftID == shift.id)
            row.sendActions(for: .touchUpInside)
            #expect(try requireContent(subject.viewModel.state).expandedShiftID == nil)
        }
    }

    private func assertPaidWords(_ label: UILabel) throws {
        let text = try #require(label.text)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = label.lineBreakMode
        paragraph.lineBreakStrategy = label.lineBreakStrategy
        let storage = NSTextStorage(attributedString: label.attributedText ?? NSAttributedString(
            string: text, attributes: [.font: label.font as Any, .paragraphStyle: paragraph]))
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let probe = UILabel()
        probe.font = label.font
        var search = NSRange(location: 0, length: (text as NSString).length)
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            probe.text = String(word)
            #expect(probe.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude)).width <= label.bounds.width)
            let range = (text as NSString).range(of: String(word), range: search)
            let glyphs = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var line = NSRange()
            _ = manager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: &line)
            #expect(NSMaxRange(glyphs) <= NSMaxRange(line))
            search = NSRange(location: NSMaxRange(range), length: (text as NSString).length - NSMaxRange(range))
        }
        #expect(label.bounds.height + 0.5 >= label.sizeThatFits(
            CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
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
        #expect(content.expandedShiftID == older.id)
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
        for expectedExpandedID in [nil, older.id] as [UUID?] {
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
            identifier: "overview.shift.\(middle.id.uuidString).detail.rate",
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
            identifier: "overview.shift.\(older.id.uuidString).detail.rate",
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

    @Test("Expanded Shift exposes one secondary Edit button without changing card tap behavior",
          arguments: [CGFloat(320), CGFloat(402)], ["en", "ru"])
    func expandedShiftEditActionPreservesCardInteraction(_ width: CGFloat, _ language: String) throws {
        let job = try makeJob(cycle: .scheduled(.calendarMonthly))
        let shift = try makeShift(id: 1, month: 9, day: 20)
        let subject = try makeSubject(job: job, shifts: [shift])
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 874))
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
        #expect(editButton.isHidden && !editButton.isAccessibilityElement)
        #expect(card.accessibilityCustomActions?.isEmpty != false)
        #expect(card.accessibilityTraits.contains(.button))
        #expect(card.accessibilityTraits.contains(.selected) == false)
        #expect(card.accessibilityHint == OverviewStrings.selectShift)

        card.sendActions(for: .touchUpInside)
        #expect(editButton.isHidden && !editButton.isAccessibilityElement)
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
        let localizationPath = try #require(Bundle(for: OverviewViewController.self).path(forResource: language, ofType: "lproj"))
        let localization = try #require(Bundle(path: localizationPath))
        let title = localization.localizedString(forKey: "overview.editShift", value: nil, table: "Localizable")
        #expect(title != "overview.editShift")
        var configuration = try #require(editButton.configuration)
        configuration.title = title
        editButton.configuration = configuration
        window.layoutIfNeeded()
        #expect(editButton.bounds.height >= 50)
        #expect(editButton.configuration?.background.cornerRadius == 12)
        let ledger: OverviewShiftLedgerView = try #require(
            card.superview?.superview as? OverviewShiftLedgerView
        )
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
            subject.viewController.traitOverrides.preferredContentSizeCategory = category
            window.layoutIfNeeded()
            #expect(card.isAccessibilityElement)
            #expect(editButton.isAccessibilityElement)
            #expect(editButton.accessibilityTraits.contains(.button))
            #expect((ledger.accessibilityElements as? [UIView]) == [card, editButton])
        }
        #expect(card.accessibilityCustomActions?.map(\.name) == [OverviewStrings.editShift])
        let chevron: UIImageView = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString).edit.chevron", in: card)
        #expect(!chevron.isHidden && chevron.image != nil)
        #expect(!chevron.isAccessibilityElement && !chevron.isUserInteractionEnabled)
        let titleLabel = try #require(editButton.titleLabel)
        #expect(titleLabel.font.fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(titleLabel.font.pointSize >= 14)
        let titleFrame = titleLabel.convert(titleLabel.bounds, to: editButton)
        let chevronFrame = chevron.convert(chevron.bounds, to: editButton)
        #expect(titleFrame.maxX + 8 <= chevronFrame.minX + 0.5)
        #expect(chevronFrame.maxX <= editButton.bounds.maxX - 16 + 0.5)
        #expect(titleLabel.text == title)
        #expect(titleLabel.bounds.height + 0.5 >= titleLabel.sizeThatFits(
            CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let accent = try colorComponents(ShiftLedgerColors.accentPrimary, traits: traits)
            let surface = try colorComponents(try #require(editButton.configuration?.background.backgroundColor), traits: traits)
            #expect(abs(surface.alpha - 0.12) < 0.000001)
            #expect(abs(surface.red - accent.red) < 0.000001)
            #expect(abs(surface.green - accent.green) < 0.000001)
            #expect(abs(surface.blue - accent.blue) < 0.000001)
            for color in [editButton.configuration?.baseForegroundColor, editButton.configuration?.baseBackgroundColor, chevron.tintColor] {
                let actual = try colorComponents(try #require(color), traits: traits)
                #expect(abs(actual.red - accent.red) < 0.000001)
                #expect(abs(actual.green - accent.green) < 0.000001)
                #expect(abs(actual.blue - accent.blue) < 0.000001)
            }
        }

        let frontDate: UILabel = try requireView(
            identifier: "overview.shift.\(shift.id.uuidString).date",
            in: try requireRootView(subject.viewController)
        )
        let headerFrame = frontDate.convert(frontDate.bounds, to: card)
        let editFrame = editButton.convert(editButton.bounds, to: card)
        #expect(abs(headerFrame.minY - 16) <= 0.5)
        #expect(abs((card.bounds.maxY - editFrame.maxY) - 16) <= 0.5)
        #expect(abs(editFrame.minX - 16) <= 0.5)
        #expect(abs((card.bounds.maxX - editFrame.maxX) - 16) <= 0.5)
        #expect(headerFrame.minY >= card.bounds.minY)
        #expect(editFrame.maxY <= card.bounds.maxY)

        var receivedShift: Shift?
        var editInvocationCount = 0
        subject.viewController.onEditShift = { receivedShift = $0; editInvocationCount += 1 }
        let editAction = try #require(card.accessibilityCustomActions?.first)
        let editActionTarget = try #require(editAction.target as? NSObject)
        _ = editActionTarget.perform(editAction.selector)
        #expect(receivedShift == shift)
        #expect(editInvocationCount == 1)
        #expect(editButton.isHidden == false)

        receivedShift = nil
        editButton.sendActions(for: .touchUpInside)
        #expect(receivedShift == shift)
        #expect(editInvocationCount == 2)
        #expect(isEffectivelyHidden(editButton) == false)
        #expect(card.accessibilityValue == OverviewStrings.expanded)

        let buttonCenter = editButton.convert(
            CGPoint(x: editButton.bounds.midX, y: editButton.bounds.midY),
            to: card
        )
        #expect(card.hitTest(buttonCenter, with: nil) === editButton)
        // Exercise the complete surface, including the decorative chevron region.
        for x in [CGFloat(2), editButton.bounds.midX, editButton.bounds.maxX - 2] {
            for y in [CGFloat(2), editButton.bounds.midY, editButton.bounds.maxY - 2] {
                let point = editButton.convert(CGPoint(x: x, y: y), to: card)
                let target = try #require(card.hitTest(point, with: nil) as? UIControl)
                #expect(target === editButton)
                let previousCount = editInvocationCount
                target.sendActions(for: .touchUpInside)
                #expect(editInvocationCount == previousCount + 1)
                #expect(receivedShift == shift)
                #expect(card.accessibilityValue == OverviewStrings.expanded)
            }
        }
        let ordinaryPoint = CGPoint(x: card.bounds.midX, y: 12)
        #expect(card.hitTest(ordinaryPoint, with: nil) === card)

        #expect(editButton.configuration?.image != nil)
        let normalHeight = editButton.bounds.height
        subject.viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.layoutIfNeeded()
        #expect(editButton.configuration?.image == nil)
        #expect(chevron.isHidden)
        #expect(editButton.configuration?.title == title)
        #expect(editButton.bounds.height > normalHeight)
        #expect(titleLabel.adjustsFontForContentSizeCategory && titleLabel.numberOfLines == 0)
        #expect(titleLabel.bounds.height + 0.5 >= titleLabel.sizeThatFits(
            CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude)).height)
        let largeTitleFrame = titleLabel.convert(titleLabel.bounds, to: editButton)
        #expect(largeTitleFrame.maxX <= editButton.bounds.maxX - 16 + 0.5)
        #expect(largeTitleFrame.maxY <= editButton.bounds.maxY - 12 + 0.5)
        let rate: UILabel = try requireView(identifier: "overview.shift.\(shift.id.uuidString).detail.rate", in: card)
        #expect(rate.convert(rate.bounds, to: card).maxY < editButton.convert(editButton.bounds, to: card).minY)
        subject.viewController.traitOverrides.preferredContentSizeCategory = .large
        window.layoutIfNeeded()
        #expect(editButton.configuration?.image != nil)
        #expect(!chevron.isHidden)

        let outsideTarget = try #require(card.hitTest(ordinaryPoint, with: nil) as? UIControl)
        #expect(outsideTarget === card)
        outsideTarget.sendActions(for: .touchUpInside)
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

        let ordered = cards.sorted { $0.frame.minY < $1.frame.minY }
        let edits: [UIButton] = try shifts.map {
            try requireView(identifier: "overview.shift.\($0.id.uuidString).edit", in: root)
        }

        func expectAccessibleRows(expanded: UIControl? = nil) {
            var expectedOrder: [UIView] = []
            for row in ordered {
                expectedOrder.append(row)
                if row === expanded, let index = cards.firstIndex(where: { $0 === row }) {
                    expectedOrder.append(edits[index])
                }
            }
            #expect((deck.accessibilityElements ?? []).compactMap { ($0 as? UIView).map(ObjectIdentifier.init) }
                    == expectedOrder.map(ObjectIdentifier.init))
            #expect((deck.accessibilityElements ?? []).count == expectedOrder.count)
            for (index, card) in cards.enumerated() {
                #expect(card.isAccessibilityElement)
                #expect(card.accessibilityIdentifier == "overview.shift.\(shifts[index].id.uuidString)")
                #expect(card.accessibilityLabel?.contains(OverviewStrings.exactContribution) == false)
                #expect(card.accessibilityLabel?.contains(PaycheckResultStrings.shiftExpected) == true)
                #expect(card.bounds.width > 0)
                #expect(card.bounds.height >= 92)
                #expect(card.accessibilityTraits.contains(.button))
                let isExpanded = card === expanded
                #expect(edits[index].isHidden == !isExpanded)
                #expect(edits[index].isAccessibilityElement == isExpanded)
                #expect(edits[index].accessibilityTraits.contains(.button))
                #expect(card.accessibilityValue == (isExpanded ? OverviewStrings.expanded : OverviewStrings.collapsed))
                #expect((card.accessibilityCustomActions ?? []).map(\.name)
                        == (isExpanded ? [OverviewStrings.editShift] : []))
            }
            expectAccessibleDocumentOrder(ordered, in: window)
        }

        expectAccessibleRows()
        // Select another row, then expand and collapse it, retaining identity and order.
        for isExpanded in [false, true, false] {
            cards[1].sendActions(for: .touchUpInside)
            window.layoutIfNeeded()
            expectAccessibleRows(expanded: isExpanded ? cards[1] : nil)
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

        var editedShiftIDs: [UUID] = []
        view.onEditShiftTapped = { editedShiftIDs.append($0) }
        renderPresentationCards(ids: ids, selectedID: ids[7], isExpanded: true, in: view)
        window.layoutIfNeeded()
        let edit: UIButton = try requireView(identifier: "overview.shift.\(ids[7].uuidString).edit", in: view)
        #expect(isEffectivelyHidden(edit) == false)
        #expect(edit.bounds.height >= 44)
        #expect(edit.isAccessibilityElement)
        edit.sendActions(for: .touchUpInside)
        #expect(editedShiftIDs == [ids[7]])
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
        var editedShiftIDs: [UUID] = []
        view.onEditShiftTapped = { editedShiftIDs.append($0) }
        renderPresentationCards(ids: [id], selectedID: id, isExpanded: true, in: view)
        window.layoutIfNeeded()

        let prefix = "overview.shift.\(id.uuidString)"
        let card: UIView = try requireView(identifier: prefix, in: view)
        let foreground = try colorComponents(ShiftLedgerColors.textPrimary, traits: window.traitCollection)
        let surface = try colorComponents(ShiftLedgerColors.surfaceSelected, traits: window.traitCollection)
        let cardSurface = try colorComponents(try #require(card.backgroundColor), traits: window.traitCollection)
        #expect(abs(cardSurface.red - surface.red) < 0.000001)
        #expect(abs(cardSurface.green - surface.green) < 0.000001)
        #expect(abs(cardSurface.blue - surface.blue) < 0.000001)
        for identifier in [
            "\(prefix).date",
            "\(prefix).expected",
            "\(prefix).detail.rate"
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
        #expect(edit.isAccessibilityElement)
        edit.sendActions(for: .touchUpInside)
        #expect(editedShiftIDs == [id])
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

        #expect(subject.viewController.navigationItem.rightBarButtonItem == nil)
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
        let gross: UIView = try requireView(identifier: "overview.expectedGross.hero", in: root)
        #expect(container.layer.cornerRadius == 16)
        #expect(container.bounds.height > 12)
        #expect(isEffectivelyHidden(gross)) // No fictional payroll amount without a PerShift selection.
        #expect(container.convert(container.bounds, to: root).maxY < addButton.convert(addButton.bounds, to: root).minY)
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

        #expect(!amount.adjustsFontForContentSizeCategory)
        #expect(period.adjustsFontForContentSizeCategory)
        #expect(amount.numberOfLines == 1)
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

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = subject.viewController
        window.isHidden = false
        defer { window.isHidden = true }
        func captureFilledAction(
            _ button: UIButton, name: String, enabled: Bool, style: UIUserInterfaceStyle
        ) throws {
            window.overrideUserInterfaceStyle = style
            window.layoutIfNeeded()
            button.isEnabled = enabled
            button.updateConfiguration()
            button.layoutIfNeeded()
            let configuration = try #require(button.configuration)
            let traits = button.traitCollection
            #expect(traits.userInterfaceStyle == style)
            #expect(configuration.baseBackgroundColor?.resolvedColor(with: traits)
                == ShiftLedgerColors.accentPrimary.resolvedColor(with: traits))
            #expect(configuration.baseForegroundColor?.resolvedColor(with: traits)
                == ShiftLedgerColors.onAccent.resolvedColor(with: traits))
            #expect(button.isEnabled == enabled)
            let image = UIGraphicsImageRenderer(bounds: button.bounds).image {
                button.layer.render(in: $0.cgContext)
            }
            let appearance = style == .dark ? "dark" : "light"
            let state = enabled ? "enabled" : "disabled"
            let data = try #require(image.pngData())
            Attachment.record(Array(data), named: "SL534-\(name)-\(state)-\(appearance).png")
        }

        for style: UIUserInterfaceStyle in [.light, .dark] {
            try captureFilledAction(check, name: "check", enabled: false, style: style)
        }
        let overview = try #require(subject.viewController.view as? OverviewView)
        overview.renderEmpty()
        for style: UIUserInterfaceStyle in [.light, .dark] {
            for enabled in [true, false] {
                try captureFilledAction(add, name: "empty-add", enabled: enabled, style: style)
            }
        }
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
                workTypeName: "Day",
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
