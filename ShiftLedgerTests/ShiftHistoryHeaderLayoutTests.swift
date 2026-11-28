import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct ShiftHistoryHeaderLayoutTests {
    @Test(arguments: [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge],
          [false, true])
    func searchFieldUsesReadableLayoutAt320(category: UIContentSizeCategory, active: Bool) throws {
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
        let language = try #require(Bundle.main.preferredLocalizations.first)
        let field = try #require(find("shiftHistory.search", in: view) as? UISearchTextField)
        view.renderHistoryOnly([], totalCount: 0, query: .init(minimum: active ? 1 : nil, searchText: "Nov"))
        window.layoutIfNeeded()
        let clear = try #require(find("shiftHistory.clearSearch", in: field))
        let options = try #require(find("shiftHistory.searchOptions", in: field))
        do {
            #expect(abs(view.bounds.width - 320) < 0.5)
            #expect(abs(field.bounds.width - 288) < 0.5)
            #expect(field.traitCollection.preferredContentSizeCategory == category)
            let body = UIFont.preferredFont(forTextStyle: .body, compatibleWith: field.traitCollection)
            #expect(abs((field.font?.pointSize ?? 0) - body.pointSize) < 0.5)
            #expect(!field.adjustsFontSizeToFitWidth)
            #expect(!clear.isHidden)
            #expect(field.placeholder == (language == "ru" ? "Поиск" : "Search"))
            #expect(options.accessibilityLabel == (language == "ru" ? "Параметры поиска" : "Search options"))
            #expect(options.accessibilityValue == ShiftHistoryStrings.optionsValue(active ? 1 : 0, sort: .newest))
            let clearRect = clear.convert(clear.bounds, to: field)
            let menuRect = options.convert(options.bounds, to: field)
            for rect in [clearRect, menuRect] {
                #expect(rect.width >= 43.99 && rect.height >= 43.99)
                #expect(field.bounds.contains(rect))
                #expect(!field.editingRect(forBounds: field.bounds).intersects(rect))
            }
            #expect(!clearRect.intersects(menuRect))
        }
        view.renderHistoryOnly([], totalCount: 0, query: .init())
        #expect(clear.isHidden)
        #expect(!options.isHidden)
    }
}
