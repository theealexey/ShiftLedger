import UIKit

final class WorkTypeSelectionViewController: UITableViewController {
    private let options: [AddShiftWorkTypeOption]
    private let selectedWorkTypeID: UUID?
    private let onSelected: (UUID) -> Void

    init(
        options: [AddShiftWorkTypeOption],
        selectedWorkTypeID: UUID?,
        onSelected: @escaping (UUID) -> Void
    ) {
        self.options = options
        self.selectedWorkTypeID = selectedWorkTypeID
        self.onSelected = onSelected
        super.init(style: .insetGrouped)
        title = AddShiftStrings.workType
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        tableView.backgroundColor = ShiftLedgerColors.backgroundPrimary
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: AddShiftStrings.cancel,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let reuseIdentifier = "WorkTypeOption"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
        let option = options[indexPath.row]
        let isSelected = option.id == selectedWorkTypeID

        cell.textLabel?.text = option.name ?? AddShiftStrings.unnamedWorkType
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.accessibilityIdentifier = "addShift.workTypeOption.\(option.id.uuidString)"
        if isSelected {
            cell.accessibilityTraits.insert(.selected)
        } else {
            cell.accessibilityTraits.remove(.selected)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = options[indexPath.row]
        onSelected(option.id)
        dismiss(animated: true)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }
}
