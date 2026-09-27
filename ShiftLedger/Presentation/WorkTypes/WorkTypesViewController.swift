import UIKit

final class WorkTypesViewController: UITableViewController {
    var onAddWorkType: (() -> Void)?
    var onRenameWorkType: ((WorkType) -> Void)?
    var onChangePayRate: ((WorkType) -> Void)?
    var onPayRateHistory: ((WorkType) -> Void)?
    var onArchived: ((Job) -> Void)?

    private let viewModel: WorkTypesViewModel

    init(viewModel: WorkTypesViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = WorkTypesStrings.title
        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        tableView.backgroundColor = ShiftLedgerColors.backgroundPrimary
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        let addItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )
        addItem.accessibilityIdentifier = "workTypes.add"
        addItem.accessibilityLabel = WorkTypesStrings.add
        navigationItem.rightBarButtonItem = addItem
    }

    func reload(workTypes: [WorkType]) {
        viewModel.reload(workTypes: workTypes)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { viewModel.sections.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard viewModel.sections.indices.contains(section) else { return nil }
        switch viewModel.sections[section] {
        case .active: return WorkTypesStrings.activeSection
        case .archived: return WorkTypesStrings.archivedSection
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard viewModel.sections.indices.contains(section) else { return 0 }
        return viewModel.sections[section].workTypes.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let identifier = "WorkType"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        let workType = viewModel.sections[indexPath.section].workTypes[indexPath.row]
        let name = workType.name ?? WorkTypesStrings.unnamed
        let basis: String
        switch workType.basePayBasis {
        case .hourly:
            basis = WorkTypesStrings.hourly
        case .fixedPerShift:
            basis = WorkTypesStrings.fixedPerShift
        }

        var content = UIListContentConfiguration.subtitleCell()
        content.text = name
        content.secondaryText = basis
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "workTypes.row.\(workType.id.uuidString)"
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = name
        cell.accessibilityValue = workType.isArchived
            ? "\(basis), \(WorkTypesStrings.archivedStatus)" : basis
        cell.accessibilityHint = WorkTypesStrings.actionsHint
        cell.accessibilityTraits.insert(.button)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard viewModel.sections.indices.contains(indexPath.section),
              viewModel.sections[indexPath.section].workTypes.indices.contains(indexPath.row)
        else { return }
        let workType = viewModel.sections[indexPath.section].workTypes[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(
            title: workType.name ?? WorkTypesStrings.unnamed,
            message: nil,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: WorkTypesStrings.rename, style: .default) { [weak self] _ in
            self?.onRenameWorkType?(workType)
        })
        sheet.addAction(UIAlertAction(title: WorkTypesStrings.changePayRate, style: .default) { [weak self] _ in
            self?.onChangePayRate?(workType)
        })
        sheet.addAction(UIAlertAction(title: WorkTypesStrings.payRateHistory, style: .default) { [weak self] _ in
            self?.onPayRateHistory?(workType)
        })
        if !workType.isArchived {
            sheet.addAction(UIAlertAction(title: WorkTypesStrings.archive, style: .destructive) { [weak self] _ in
                self?.presentArchiveConfirmation(for: workType)
            })
        }
        sheet.addAction(UIAlertAction(title: WorkTypesStrings.cancel, style: .cancel))
        if let popover = sheet.popoverPresentationController {
            let cell = tableView.cellForRow(at: indexPath)
            popover.sourceView = cell ?? tableView
            popover.sourceRect = cell?.bounds ?? tableView.rectForRow(at: indexPath)
        }
        present(sheet, animated: true)
    }

    @objc private func addTapped() {
        onAddWorkType?()
    }

    func presentArchiveConfirmation(for workType: WorkType) {
        let name = workType.name ?? WorkTypesStrings.unnamed
        let alert = UIAlertController(
            title: String(format: WorkTypesStrings.archiveConfirmationTitle, name),
            message: WorkTypesStrings.archiveConfirmationMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: WorkTypesStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: WorkTypesStrings.archive, style: .destructive) { [weak self] _ in
            self?.archive(workType)
        })
        present(alert, animated: true)
    }

    func archive(_ workType: WorkType) {
        switch viewModel.archive(id: workType.id) {
        case let .archived(job):
            tableView.reloadData()
            onArchived?(job)
        case .failed:
            let alert = UIAlertController(
                title: WorkTypesStrings.archiveErrorTitle,
                message: WorkTypesStrings.archiveErrorMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: WorkTypesStrings.ok, style: .default))
            present(alert, animated: true)
        case .ignored:
            break
        }
    }
}
