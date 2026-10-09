import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct JobSelectionViewControllerTests {
    @Test("Native list exposes distinct active and archived history actions")
    func sectionsAndAccessibility() throws {
        let active = try item(index: 1, name: "Same Name")
        let other = try item(index: 2, name: "Same Name")
        let archived = try item(index: 3, name: nil, archived: true)
        let controller = JobSelectionViewController(items: [archived, active, other])
        let window = attach(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let view = try #require(controller.view as? JobSelectionView)
        let table = view.tableView
        #expect(table.style == .insetGrouped)
        #expect(table.numberOfSections == 2)
        #expect(table.numberOfRows(inSection: 0) == 2)
        #expect(table.numberOfRows(inSection: 1) == 1)
        #expect(controller.tableView(table, titleForHeaderInSection: 0) == JobSelectionStrings.active)
        #expect(controller.tableView(table, titleForHeaderInSection: 1) == JobSelectionStrings.archived)
        let activeCell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        let otherCell = controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0))
        let archivedCell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1))
        #expect(activeCell.accessibilityIdentifier == "jobSelection.job.\(active.id.uuidString)")
        #expect(activeCell.accessibilityLabel == "Same Name")
        #expect(activeCell.accessibilityValue?.contains(active.id.uuidString) == true)
        #expect(activeCell.accessibilityValue != otherCell.accessibilityValue)
        #expect(activeCell.accessibilityTraits.contains(.button))
        #expect(activeCell.accessoryType == .disclosureIndicator)
        #expect(archivedCell.accessibilityLabel == JobSelectionStrings.unnamed)
        #expect(archivedCell.accessibilityValue?.contains(JobSelectionStrings.archivedStatus) == true)
        #expect(archivedCell.accessibilityTraits.contains(.button))
        #expect(archivedCell.accessoryType == .disclosureIndicator)
        #expect(controller.tableView(table, willSelectRowAt: IndexPath(row: 0, section: 1)) == IndexPath(row: 0, section: 1))
        var selected: [UUID] = []
        var selectedArchived: [UUID] = []
        controller.onSelectJob = { selected.append($0) }
        controller.onSelectArchivedJob = { selectedArchived.append($0) }
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        #expect(selected == [other.id])
        #expect(selectedArchived == [archived.id])
        controller.reload(items: [other, archived, active])
        let reloadedCell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        #expect(reloadedCell.accessibilityIdentifier == "jobSelection.job.\(other.id.uuidString)")
        #expect(reloadedCell.accessibilityLabel == other.displayName)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        #expect(selected == [other.id, other.id])
    }

    @Test("Only archived Jobs show explicit no-active explanation")
    func noActiveState() throws {
        let controller = JobSelectionViewController(items: [try item(index: 3, name: nil, archived: true)])
        let window = attach(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let table = try #require(controller.view as? JobSelectionView).tableView
        #expect(table.numberOfRows(inSection: 0) == 0)
        #expect(table.numberOfRows(inSection: 1) == 1)
        #expect(controller.tableView(table, titleForFooterInSection: 0) == JobSelectionStrings.noActive)
    }

    @Test("Meaningful names remain exact and blank names use localized fallback", arguments: [nil, "", " \n\t", "  Hospital A  "] as [String?])
    func namePresentation(name: String?) throws {
        let value = try item(index: 1, name: name)
        #expect(value.name == name)
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            #expect(value.displayName == name)
        } else {
            #expect(value.displayName == JobSelectionStrings.unnamed)
        }
        #expect(value.metadata.contains("EUR"))
        #expect(value.metadata.contains("Europe/Stockholm"))
        #expect(value.metadata.contains(value.id.uuidString.prefix(8)))
    }

    @Test("Automatic rows wrap identity metadata at accessibility size")
    func accessibleRowsWrap() throws {
        let value = try item(index: 1, name: "Long hospital department name that must remain fully readable")
        let controller = JobSelectionViewController(items: [value])
        let navigation = UINavigationController(rootViewController: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }
        let table = try #require(controller.view as? JobSelectionView).tableView
        table.layoutIfNeeded()
        let cell = try #require(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let config = try #require(cell.contentConfiguration as? UIListContentConfiguration)
        #expect(config.text == value.displayName)
        #expect(config.secondaryText == value.metadata)
        #expect(config.textProperties.numberOfLines == 0)
        #expect(config.secondaryTextProperties.numberOfLines == 0)
        #expect(cell.bounds.height >= 44)
        #expect(cell.bounds.height > 100)
        #expect(controller.traitCollection.preferredContentSizeCategory == .accessibilityExtraExtraLarge)
    }

    private func item(index: Int, name: String?, archived: Bool = false) throws -> JobSelectionItem {
        JobSelectionItem(
            id: try #require(UUID(uuidString: String(format: "%08d-0000-0000-0000-000000000001", index))),
            name: name, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm", isArchived: archived
        )
    }

    private func attach(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

}
