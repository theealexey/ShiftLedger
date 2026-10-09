import UIKit

struct ArchivedJobHistoryContent: Equatable {
    struct Row: Equatable {
        let id: UUID
        let title: String
        let detail: String
        let contribution: Decimal
    }
    let identity: JobSelectionItem
    let total: Decimal
    let totalText: String
    let rows: [Row]
}

final class ArchivedJobHistoryView: UIView {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        tableView.allowsSelection = false
        tableView.accessibilityIdentifier = "archive.history.list"
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

    func cell(title: String, detail: String, identifier: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "History")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "History")
        var content = UIListContentConfiguration.subtitleCell()
        content.text = title
        content.secondaryText = detail
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.directionalLayoutMargins.leading = 16
        content.directionalLayoutMargins.trailing = 16
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        cell.accessibilityIdentifier = identifier
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = title
        cell.accessibilityValue = detail
        cell.accessibilityTraits = .staticText
        return cell
    }
}
