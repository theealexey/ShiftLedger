import UIKit

final class ShiftDateTimePickerViewController: UIViewController {
    private let datePicker = UIDatePicker()
    private let initialDate: Date
    private let timeZone: TimeZone
    private let onDateSelected: (Date) -> Void

    init(
        title: String,
        initialDate: Date,
        timeZone: TimeZone,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        onDateSelected: @escaping (Date) -> Void
    ) {
        self.initialDate = initialDate
        self.timeZone = timeZone
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
        self.title = title
        datePicker.minimumDate = minimumDate
        datePicker.maximumDate = maximumDate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        view.tintColor = ShiftLedgerColors.accentPrimary
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: AddShiftStrings.cancel,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: AddShiftStrings.done,
            style: .done,
            target: self,
            action: #selector(done)
        )

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .dateAndTime
        datePicker.minuteInterval = 1
        datePicker.timeZone = timeZone
        datePicker.date = initialDate
        datePicker.preferredDatePickerStyle = .wheels
        view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            datePicker.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func done() {
        onDateSelected(datePicker.date)
        dismiss(animated: true)
    }
}
