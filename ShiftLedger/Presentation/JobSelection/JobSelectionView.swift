import UIKit

struct JobSelectionItem: Equatable {
    let id: UUID
    let name: String?
    let currencyCode: String
    let timeZoneIdentifier: String
    let isArchived: Bool

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return JobSelectionStrings.unnamed
        }
        return name
    }

    var metadata: String {
        "\(currencyCode) · \(timeZoneIdentifier) · \(id.uuidString.prefix(8))"
    }
}

final class JobSelectionView: UIView {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        tableView.accessibilityIdentifier = "jobSelection.list"
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func cell(for item: JobSelectionItem) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Job")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Job")
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.displayName
        content.secondaryText = item.isArchived
            ? "\(item.metadata)\n\(JobSelectionStrings.archivedStatus)" : item.metadata
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        cell.isAccessibilityElement = true
        cell.accessibilityIdentifier = "jobSelection.job.\(item.id.uuidString)"
        cell.accessibilityLabel = item.displayName
        cell.accessibilityValue = "\(item.currencyCode), \(item.timeZoneIdentifier), \(item.id.uuidString)"
            + (item.isArchived ? ", \(JobSelectionStrings.archivedStatus)" : "")
        cell.accessibilityTraits = .button
        return cell
    }
}
