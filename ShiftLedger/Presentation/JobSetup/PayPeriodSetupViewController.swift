import UIKit

final class PayPeriodSetupViewController: UIViewController {
    var onBack: (() -> Void)?
    var onContinue: ((JobSetupDraft) -> Void)?

    private let viewModel: PayPeriodSetupViewModel
    private let displayLocale: Locale
    private let payPeriodSetupView = PayPeriodSetupView(frame: .zero)

    init(
        viewModel: PayPeriodSetupViewModel,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale
    ) {
        self.viewModel = viewModel
        self.displayLocale = displayLocale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = payPeriodSetupView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindView()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func bindView() {
        payPeriodSetupView.onBackTapped = { [weak self] in
            self?.onBack?()
        }
        payPeriodSetupView.onFrequencySelected = { [weak self] frequency in
            guard let self else {
                return
            }

            viewModel.selectFrequency(frequency)
            render()
        }
        payPeriodSetupView.onAnchorTapped = { [weak self] in
            self?.presentAnchorDatePicker()
        }
        payPeriodSetupView.onContinueTapped = { [weak self] in
            guard let self, viewModel.canContinue else {
                return
            }

            onContinue?(viewModel.draft)
        }
    }

    private func render() {
        payPeriodSetupView.render(
            frequency: viewModel.selectedFrequency,
            anchorDateText: formattedAnchorDate,
            canContinue: viewModel.canContinue
        )
    }

    private var formattedAnchorDate: String? {
        guard
            let anchorDate = viewModel.anchorDate,
            let timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier),
            let foundationDate = try? anchorDate.startOfDay(in: timeZone)
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = displayLocale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: foundationDate)
    }

    private func presentAnchorDatePicker() {
        let picker = PayPeriodAnchorDateViewController(
            timeZoneIdentifier: viewModel.draft.timeZoneIdentifier,
            initialDate: viewModel.anchorDate
        ) { [weak self] date in
            guard let self else {
                return
            }

            viewModel.selectAnchorDate(date)
            render()
        }
        picker.title = PayPeriodSetupStrings.anchorPickerTitle

        let navigationController = UINavigationController(rootViewController: picker)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
}

final class PayPeriodAnchorDateViewController: UIViewController {
    private let timeZoneIdentifier: String
    private let initialDate: LocalDate?
    private let onDateSelected: (LocalDate) -> Void
    private let datePicker = UIDatePicker()

    init(
        timeZoneIdentifier: String,
        initialDate: LocalDate?,
        onDateSelected: @escaping (LocalDate) -> Void
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.initialDate = initialDate
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        datePicker.timeZone = timeZone

        if let initialDate, let date = try? initialDate.startOfDay(in: timeZone) {
            datePicker.date = date
        }

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: PayPeriodSetupStrings.cancel,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: PayPeriodSetupStrings.done,
            style: .done,
            target: self,
            action: #selector(done)
        )
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func done() {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let localDate = try? LocalDate(date: datePicker.date, in: timeZone)
        else {
            return
        }

        onDateSelected(localDate)
        dismiss(animated: true)
    }
}
