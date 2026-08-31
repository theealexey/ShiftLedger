import UIKit

final class AddShiftViewController: UIViewController {
    var onSaved: ((Shift) -> Void)?

    private let viewModel: AddShiftViewModel
    private let displayLocale: Locale
    private let dateFormattingLocale: Locale
    private let addShiftView = AddShiftView(frame: .zero)

    init(
        viewModel: AddShiftViewModel,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale,
        dateFormattingLocale: Locale = .autoupdatingCurrent
    ) {
        self.viewModel = viewModel
        self.displayLocale = displayLocale
        self.dateFormattingLocale = dateFormattingLocale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() { view = addShiftView }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AddShiftStrings.title
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: AddShiftStrings.save, style: .done, target: self, action: #selector(saveTapped))
        bindView()
        render()
    }

    private func bindView() {
        addShiftView.onStartTapped = { [weak self] in self?.presentPicker(for: .start) }
        addShiftView.onEndTapped = { [weak self] in self?.presentPicker(for: .end) }
        addShiftView.onBreakStartTapped = { [weak self] in self?.presentPicker(for: .breakStart) }
        addShiftView.onBreakEndTapped = { [weak self] in self?.presentPicker(for: .breakEnd) }
        addShiftView.onBreakEnabledChanged = { [weak self] enabled in
            self?.viewModel.setUnpaidBreakEnabled(enabled)
            self?.render()
        }
    }

    private func render() {
        let timeZoneText = "\(AddShiftStrings.timeZonePrefix) \(TimeZoneDisplayName.value(for: viewModel.timeZoneIdentifier, locale: displayLocale))"
        addShiftView.render(
            startText: formatted(viewModel.start),
            startAccessibilityText: accessibilityFormatted(viewModel.start),
            endText: formatted(viewModel.end),
            endAccessibilityText: accessibilityFormatted(viewModel.end),
            timeZoneText: timeZoneText,
            breakEnabled: viewModel.isUnpaidBreakEnabled,
            breakStartText: formatted(viewModel.breakStart),
            breakStartAccessibilityText: accessibilityFormatted(viewModel.breakStart),
            breakEndText: formatted(viewModel.breakEnd),
            breakEndAccessibilityText: accessibilityFormatted(viewModel.breakEnd),
            validationMessage: validationMessage
        )
        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canSave && viewModel.isSaving == false
    }

    private var validationMessage: String? {
        switch viewModel.validationError {
        case .startNotBeforeEnd:
            AddShiftStrings.endAfterStartError
        case .durationExceedsLimit:
            AddShiftStrings.durationError
        case .breakStartNotBeforeEnd:
            AddShiftStrings.breakEndAfterStartError
        case .breakOutsideShift:
            AddShiftStrings.breakInsideShiftError
        case .breakConsumesEntireShift:
            AddShiftStrings.breakWholeShiftError
        case nil:
            nil
        }
    }

    private func formatted(_ date: Date?) -> String? {
        guard let date else { return nil }
        return AddShiftDateFormatting.string(for: date, timeZoneIdentifier: viewModel.timeZoneIdentifier, locale: dateFormattingLocale)
    }

    private func accessibilityFormatted(_ date: Date?) -> String? {
        guard let date else { return nil }
        return AddShiftDateFormatting.accessibilityString(for: date, timeZoneIdentifier: viewModel.timeZoneIdentifier, locale: dateFormattingLocale)
    }

    private enum PickerField { case start, end, breakStart, breakEnd }

    private func presentPicker(for field: PickerField) {
        guard let timeZone = TimeZone(identifier: viewModel.timeZoneIdentifier) else { return }
        let fallbackDate = Date()
        let currentValue: Date
        switch field {
        case .start: currentValue = viewModel.start ?? fallbackDate
        case .end: currentValue = viewModel.end ?? fallbackDate
        case .breakStart: currentValue = viewModel.breakStart ?? fallbackDate
        case .breakEnd: currentValue = viewModel.breakEnd ?? fallbackDate
        }
        let picker = ShiftDateTimePickerViewController(
            title: pickerTitle(for: field),
            initialDate: currentValue,
            timeZone: timeZone,
            minimumDate: minimumDate(for: field),
            maximumDate: maximumDate(for: field)
        ) { [weak self] date in
            guard let self else { return }
            switch field {
            case .start: viewModel.setStart(date)
            case .end: viewModel.setEnd(date)
            case .breakStart: viewModel.setBreakStart(date)
            case .breakEnd: viewModel.setBreakEnd(date)
            }
            render()
        }
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

    private func pickerTitle(for field: PickerField) -> String {
        switch field {
        case .start: AddShiftStrings.shiftStartPickerTitle
        case .end: AddShiftStrings.shiftEndPickerTitle
        case .breakStart: AddShiftStrings.breakStartPickerTitle
        case .breakEnd: AddShiftStrings.breakEndPickerTitle
        }
    }

    private func minimumDate(for field: PickerField) -> Date? {
        switch field {
        case .breakStart, .breakEnd:
            return viewModel.start
        case .start, .end:
            return nil
        }
    }

    private func maximumDate(for field: PickerField) -> Date? {
        switch field {
        case .end:
            return viewModel.start?.addingTimeInterval(48 * 60 * 60)
        case .breakStart, .breakEnd:
            return viewModel.end
        case .start:
            return nil
        }
    }

    @objc private func saveTapped() {
        switch viewModel.save() {
        case let .saved(shift):
            onSaved?(shift)
            return
        case let .failed(failure):
            presentSaveError(failure)
        case .invalid, .ignored:
            break
        }
        render()
    }

    private func presentSaveError(_ failure: AddShiftSaveFailure) {
        guard viewIfLoaded?.window != nil else { return }
        let isOverlap = failure == .overlap
        let alert = UIAlertController(
            title: isOverlap ? AddShiftStrings.overlapTitle : AddShiftStrings.genericErrorTitle,
            message: isOverlap ? AddShiftStrings.overlapMessage : AddShiftStrings.genericErrorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AddShiftStrings.alertOK, style: .default))
        present(alert, animated: true)
    }
}
