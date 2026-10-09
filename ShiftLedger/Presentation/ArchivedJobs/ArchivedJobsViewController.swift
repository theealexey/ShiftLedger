import UIKit

final class ArchivedJobsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSelectJob: ((UUID) -> Void)?
    var onReload: (() -> Void)?
    private enum State {
        case notLoaded
        case loaded([JobSelectionItem])
        case failed
    }
    private var state: State
    private let listView = JobSelectionView()

    init() {
        state = .notLoaded
        super.init(nibName: nil, bundle: nil)
    }

    init(items: [JobSelectionItem]) {
        state = .loaded(items.filter(\.isArchived))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() { view = listView }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = ArchivedJobHistoryStrings.jobsTitle
        listView.tableView.accessibilityIdentifier = "archive.jobs.list"
        listView.tableView.dataSource = self
        listView.tableView.delegate = self
    }

    func reload(items: [JobSelectionItem]) {
        state = .loaded(items.filter(\.isArchived))
        listView.tableView.reloadData()
    }

    func showLoadFailure() {
        state = .failed
        listView.tableView.reloadData()
    }

    func presentLoadError() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: ArchivedJobHistoryStrings.errorTitle, message: ArchivedJobHistoryStrings.errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: JobSelectionStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: JobSelectionStrings.retry, style: .default) { [weak self] _ in self?.onReload?() })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case .notLoaded: 0
        case .loaded(let items): items.count
        case .failed: 2
        }
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if case .loaded(let items) = state, items.isEmpty { return ArchivedJobHistoryStrings.emptyJobs }
        return nil
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if case .loaded(let items) = state { return listView.cell(for: items[indexPath.row]) }
        let isRetry = indexPath.row == 1
        let text = isRetry ? JobSelectionStrings.retry : String(localized: "archive.jobs.loadFailed", table: "Localizable")
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.cell()
        content.text = text
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.numberOfLines = 0
        content.textProperties.color = isRetry ? listView.tintColor : .label
        cell.contentConfiguration = content
        cell.selectionStyle = isRetry ? .default : .none
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = text
        cell.accessibilityIdentifier = isRetry ? "archive.jobs.retry" : "archive.jobs.loadFailed"
        cell.accessibilityTraits = isRetry ? .button : .staticText
        return cell
    }
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch state {
        case .notLoaded: nil
        case .loaded(let items): items.indices.contains(indexPath.row) ? indexPath : nil
        case .failed: indexPath.row == 1 ? indexPath : nil
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch state {
        case .notLoaded: break
        case .loaded(let items):
            guard items.indices.contains(indexPath.row) else { return }
            onSelectJob?(items[indexPath.row].id)
        case .failed:
            guard indexPath.row == 1 else { return }
            onReload?()
        }
    }
}
