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
        payPeriodSetupView.onCycleKindSelected = { [weak self] cycleKind in
            guard let self else {
                return
            }

            viewModel.selectCycleKind(cycleKind)
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
            cycleKind: viewModel.selectedCycleKind,
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
        navigationController.view.tintColor = ShiftLedgerColors.accentPrimary
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }
}

private final class HeaderActionControl: UIControl {
    private let titleLabel = UILabel()

    init(title: String, color: UIColor) {
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.textColor = color
        titleLabel.font = ShiftLedgerTypography.callout
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds.insetBy(dx: 4, dy: 0)
    }
}

final class PayPeriodAnchorDateViewController: UIViewController {
    private let timeZoneIdentifier: String
    private let initialDate: LocalDate?
    private let onDateSelected: (LocalDate) -> Void
    private let datePicker = UIDatePicker()
    private let headerStack = UIStackView()
    private let headerTitleLabel = UILabel()

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
        view.tintColor = ShiftLedgerColors.accentPrimary
        navigationController?.setNavigationBarHidden(true, animated: false)

        let cancelControl = HeaderActionControl(
            title: PayPeriodSetupStrings.cancel,
            color: ShiftLedgerColors.textSecondary
        )
        cancelControl.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        let doneControl = HeaderActionControl(
            title: PayPeriodSetupStrings.done,
            color: ShiftLedgerColors.accentPrimary
        )
        doneControl.addTarget(self, action: #selector(done), for: .touchUpInside)
        headerTitleLabel.text = title
        headerTitleLabel.font = ShiftLedgerTypography.headline
        headerTitleLabel.textColor = ShiftLedgerColors.textPrimary
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.adjustsFontForContentSizeCategory = true
        headerTitleLabel.numberOfLines = 1
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.addArrangedSubview(cancelControl)
        headerStack.addArrangedSubview(headerTitleLabel)
        headerStack.addArrangedSubview(doneControl)
        cancelControl.widthAnchor.constraint(equalToConstant: 72).isActive = true
        doneControl.widthAnchor.constraint(equalTo: cancelControl.widthAnchor).isActive = true
        cancelControl.heightAnchor.constraint(equalToConstant: 44).isActive = true
        doneControl.heightAnchor.constraint(equalTo: cancelControl.heightAnchor).isActive = true

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.tintColor = ShiftLedgerColors.accentPrimary
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        datePicker.timeZone = timeZone

        if let initialDate, let date = try? initialDate.startOfDay(in: timeZone) {
            datePicker.date = date
        }

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)
        view.addSubview(datePicker)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: 44),
            datePicker.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
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
