import UIKit

final class WorkTypesViewController: UITableViewController {
    var onAddWorkType: (() -> Void)?
    var onRenameWorkType: ((WorkType) -> Void)?

    private var workTypes: [WorkType]

    init(workTypes: [WorkType]) {
        self.workTypes = workTypes
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
        self.workTypes = workTypes
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        workTypes.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let identifier = "WorkType"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        let workType = workTypes[indexPath.row]
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
        cell.accessibilityValue = basis
        cell.accessibilityTraits.insert(.button)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard workTypes.indices.contains(indexPath.row) else { return }
        let workType = workTypes[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        onRenameWorkType?(workType)
    }

    @objc private func addTapped() {
        onAddWorkType?()
    }
}
