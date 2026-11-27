import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftHistoryHeaderLayoutTests {
    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge],
          [false, true])
    func buttonsUseReadableLayoutAt320(category: UIContentSizeCategory, active: Bool) throws {
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = category
        let view = OverviewView()
        view.showsShiftHistoryOnly = true
        view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 320),
            view.centerXAnchor.constraint(equalTo: host.view.centerXAnchor),
            view.topAnchor.constraint(equalTo: host.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 1000))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        view.renderHistoryOnly([], totalCount: 0, query: ShiftHistoryQuery(minimum: active ? 1 : nil))
        func find(_ id: String, in parent: UIView) -> UIView? {
            if parent.accessibilityIdentifier == id { return parent }
            return parent.subviews.lazy.compactMap { find(id, in: $0) }.first
        }
        let filter = try #require(find("shiftHistory.filters", in: view) as? UIButton)
        let sort = try #require(find("shiftHistory.sort", in: view) as? UIButton)
        let filterTitle = active ? ShiftHistoryStrings.filters + " (1)" : ShiftHistoryStrings.filters
        let sortTitle = ShiftHistoryStrings.sort
        #expect(["Фильтры", "Filters"].contains(ShiftHistoryStrings.filters))
        #expect(["Сортировка", "Sort"].contains(sortTitle))
        host.view.setNeedsLayout()
        window.layoutIfNeeded()
        view.setNeedsLayout()
        window.layoutIfNeeded()
        let stack = try #require(filter.superview as? UIStackView)
        let font = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: filter.traitCollection)
        print("SL567 layout window=\(window.bounds) host=\(host.view.bounds) overview=\(view.bounds) history=\(stack.superview?.bounds ?? .zero) traits=\(host.traitCollection.preferredContentSizeCategory.rawValue)/\(view.traitCollection.preferredContentSizeCategory.rawValue)/\(filter.traitCollection.preferredContentSizeCategory.rawValue)/\(sort.traitCollection.preferredContentSizeCategory.rawValue) font=\(font.pointSize) titles=\(filterTitle),\(sortTitle) widths=\((filterTitle as NSString).size(withAttributes:[.font:font]).width),\((sortTitle as NSString).size(withAttributes:[.font:font]).width) axis=\(stack.axis.rawValue) distribution=\(stack.distribution.rawValue)")
        #expect(abs(view.bounds.width - 320) < 0.5)
        #expect(view.traitCollection.preferredContentSizeCategory == category)
        #expect(filter.traitCollection.preferredContentSizeCategory == category)
        #expect(sort.traitCollection.preferredContentSizeCategory == category)
        if category.isAccessibilityCategory {
            #expect(stack.axis == .vertical)
            #expect(filter.configuration?.imagePlacement == .top)
            #expect(sort.configuration?.imagePlacement == .top)
        }
        #expect(filter.bounds.width >= 44 && filter.bounds.height >= 44)
        #expect(sort.bounds.width >= 44 && sort.bounds.height >= 44)
        #expect(filter.accessibilityLabel == ShiftHistoryStrings.filters)
        let fullSort = ShiftHistoryStrings.sort
        let sortWidth = (fullSort as NSString).size(withAttributes: [.font: font]).width
        let insets = try #require(sort.configuration).contentInsets
        let expectedSort = sortWidth <= stack.bounds.width - insets.leading - insets.trailing
            ? fullSort : ShiftHistoryStrings.sortCompact
        #expect(sort.accessibilityLabel == fullSort)
        for (button, expected) in [(filter, filterTitle), (sort, expectedSort)] {
            let label = try #require(button.titleLabel)
            let frame = button.convert(label.bounds, from: label)
            print("SL567 button=\(expected) bounds=\(button.bounds) titleFrame=\(frame) font=\(label.font.pointSize) imagePlacement=\(String(describing: button.configuration?.imagePlacement))")
            #expect(button.configuration?.title == expected)
            #expect(label.numberOfLines == 0)
            #expect(abs(label.font.pointSize - font.pointSize) < 0.5)
            #expect(label.bounds.height + 1 >= label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height)
            #expect(frame.minX >= -0.5 && frame.maxX <= button.bounds.width + 0.5)
            #expect(frame.minY >= -0.5 && frame.maxY <= button.bounds.height + 0.5)
        }
        #expect(stack.axis == .vertical ? filter.frame.maxY <= sort.frame.minY : filter.frame.maxX <= sort.frame.minX)
    }
}
