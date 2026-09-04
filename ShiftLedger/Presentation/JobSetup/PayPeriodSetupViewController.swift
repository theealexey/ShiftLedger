import UIKit

final class PayPeriodSetupViewController: UIViewController {
    var onBack: (() -> Void)?
    var onContinue: ((JobSetupDraft) -> Void)?

    private let viewModel: PayPeriodSetupViewModel
    private let dateFormattingLocale: Locale
    private let payPeriodSetupView = PayPeriodSetupView(frame: .zero)

    init(
        viewModel: PayPeriodSetupViewModel,
        dateFormattingLocale: Locale = .autoupdatingCurrent
    ) {
        self.viewModel = viewModel
        self.dateFormattingLocale = dateFormattingLocale
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
        guard let anchorDate = viewModel.anchorDate else {
            return nil
        }

        return JobSetupDateFormatting.string(
            for: anchorDate,
            timeZoneIdentifier: viewModel.draft.timeZoneIdentifier,
            locale: dateFormattingLocale
        )
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

enum JobSetupDateFormatting {
    static func string(for date: LocalDate, timeZoneIdentifier: String, locale: Locale) -> String? {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let foundationDate = try? date.startOfDay(in: timeZone)
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: foundationDate)
    }
}

final class PayPeriodAnchorDateViewController: UIViewController {
    private let timeZoneIdentifier: String
    private let initialDate: LocalDate?
    private let onDateSelected: (LocalDate) -> Void
    private let anchorDateView = PayPeriodAnchorDateView(frame: .zero)

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

    override func loadView() {
        view = anchorDateView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.setNavigationBarHidden(true, animated: false)
        bindView()
        configureAnchorDateView()
    }

    private func bindView() {
        anchorDateView.onCancelTapped = { [weak self] in
            self?.dismiss(animated: true)
        }
        anchorDateView.onDoneTapped = { [weak self] in
            self?.finishSelection()
        }
    }

    private func configureAnchorDateView() {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        let date = initialDate.flatMap { try? $0.startOfDay(in: timeZone) }
        anchorDateView.configure(
            title: title,
            date: date,
            timeZone: timeZone
        )
    }

    private func finishSelection() {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let localDate = try? LocalDate(date: anchorDateView.selectedDate, in: timeZone)
        else {
            return
        }

        onDateSelected(localDate)
        dismiss(animated: true)
    }
}
