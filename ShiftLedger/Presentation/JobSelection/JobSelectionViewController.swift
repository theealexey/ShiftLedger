import UIKit

final class JobSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSelectJob: ((UUID) -> Void)?
    var onReload: (() -> Void)?
    private var items: [JobSelectionItem]
    private let selectionView = JobSelectionView()

    init(items: [JobSelectionItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() { view = selectionView }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = JobSelectionStrings.title
        selectionView.tableView.dataSource = self
        selectionView.tableView.delegate = self
    }

    func reload(items: [JobSelectionItem]) {
        self.items = items
        selectionView.tableView.reloadData()
    }

    func presentSelectionError() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: JobSelectionStrings.errorTitle,
            message: JobSelectionStrings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: JobSelectionStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: JobSelectionStrings.retry, style: .default) { [weak self] _ in
            self?.onReload?()
        })
        present(alert, animated: true)
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? JobSelectionStrings.active : JobSelectionStrings.archived
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 && rows(in: 0).isEmpty ? JobSelectionStrings.noActive : nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows(in: section).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        selectionView.cell(for: rows(in: indexPath.section)[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        item(at: indexPath)?.isArchived == false ? indexPath : nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = item(at: indexPath), !item.isArchived else { return }
        onSelectJob?(item.id)
    }

    private func rows(in section: Int) -> [JobSelectionItem] {
        guard section == 0 || section == 1 else { return [] }
        return items.filter { $0.isArchived == (section == 1) }
    }

    private func item(at indexPath: IndexPath) -> JobSelectionItem? {
        let rows = rows(in: indexPath.section)
        guard rows.indices.contains(indexPath.row) else { return nil }
        return rows[indexPath.row]
    }
}
