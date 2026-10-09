import UIKit

final class ArchivedJobHistoryViewController: UIViewController, UITableViewDataSource {
    let content: ArchivedJobHistoryContent
    private let historyView = ArchivedJobHistoryView()

    init(content: ArchivedJobHistoryContent) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() { view = historyView }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ArchivedJobHistoryStrings.title
        historyView.tableView.dataSource = self
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 2 : content.rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 1 ? "\(ArchivedJobHistoryStrings.count) · \(content.rows.count)" : nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 && content.rows.isEmpty ? ArchivedJobHistoryStrings.emptyHistory : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                return historyView.cell(
                    title: content.identity.displayName,
                    detail: "\(content.identity.metadata)\n\(content.identity.id.uuidString)\n\(ArchivedJobHistoryStrings.readOnly)",
                    identifier: "archive.history.job.\(content.identity.id.uuidString)"
                )
            }
            return historyView.cell(title: ArchivedJobHistoryStrings.total, detail: content.totalText, identifier: "archive.history.total")
        }
        let row = content.rows[indexPath.row]
        return historyView.cell(title: row.title, detail: row.detail, identifier: "archive.history.shift.\(row.id.uuidString)")
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { false }
}
