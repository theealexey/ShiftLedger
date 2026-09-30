import UIKit

final class EditShiftViewController: UIViewController {
    var onSaved: ((Shift) -> Void)?
    var onDeleted: ((UUID) -> Void)?

    private let viewModel: EditShiftViewModel
    private let displayLocale: Locale
    private let dateFormattingLocale: Locale
    private let editShiftView = EditShiftView()
    private var shiftFormView: ShiftFormView { editShiftView.shiftFormView }

    init(
        viewModel: EditShiftViewModel,
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

    override func loadView() {
        view = editShiftView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = EditShiftStrings.title
        navigationItem.largeTitleDisplayMode = .never
        let saveItem = UIBarButtonItem(
            title: EditShiftStrings.save,
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveItem.accessibilityIdentifier = "editShift.save"
        navigationItem.rightBarButtonItem = saveItem
        bindView()
        render()
    }

    private func bindView() {
        shiftFormView.onWorkTypeTapped = { [weak self] in self?.presentWorkTypePicker() }
        shiftFormView.onStartTapped = { [weak self] in self?.presentPicker(for: .start) }
        shiftFormView.onEndTapped = { [weak self] in self?.presentPicker(for: .end) }
        shiftFormView.onBreakStartTapped = { [weak self] in self?.presentPicker(for: .breakStart) }
        shiftFormView.onBreakEndTapped = { [weak self] in self?.presentPicker(for: .breakEnd) }
        shiftFormView.onBreakEnabledChanged = { [weak self] enabled in
            self?.viewModel.setUnpaidBreakEnabled(enabled)
            self?.render()
        }
        editShiftView.onDeleteTapped = { [weak self] in self?.presentDeleteConfirmation() }
    }

    private func render() {
        let timeZoneName = TimeZoneDisplayName.value(
            for: viewModel.timeZoneIdentifier,
            locale: displayLocale
        )
        let timeZoneText = "\(AddShiftStrings.timeZonePrefix) \(timeZoneName)"

        shiftFormView.render(
            workTypeText: selectedWorkTypeText,
            canSelectWorkType: canSelectWorkType,
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

        navigationItem.rightBarButtonItem?.isEnabled = viewModel.canSave
        editShiftView.setDeleteEnabled(viewModel.isSaving == false && viewModel.isDeleting == false)
    }

    private var selectedWorkTypeText: String {
        guard let selectedWorkType = viewModel.selectedWorkType else {
            return AddShiftStrings.select
        }
        let name = selectedWorkType.name ?? AddShiftStrings.unnamedWorkType
        return selectedWorkType.isArchived
            ? "\(name) · \(ShiftFormStrings.archived)" : name
    }

    private var canSelectWorkType: Bool {
        viewModel.workTypeOptions.count > 1 || viewModel.selectedWorkTypeID == nil
    }

    private func presentWorkTypePicker() {
        guard canSelectWorkType else { return }
        let picker = WorkTypeSelectionViewController(
            options: viewModel.workTypeOptions,
            selectedWorkTypeID: viewModel.selectedWorkTypeID
        ) { [weak self] workTypeID in
            guard let self, viewModel.selectWorkType(id: workTypeID) else { return }
            render()
        }
        presentSheet(picker)
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
        return AddShiftDateFormatting.string(
            for: date,
            timeZoneIdentifier: viewModel.timeZoneIdentifier,
            locale: dateFormattingLocale
        )
    }

    private func accessibilityFormatted(_ date: Date?) -> String? {
        guard let date else { return nil }
        return AddShiftDateFormatting.accessibilityString(
            for: date,
            timeZoneIdentifier: viewModel.timeZoneIdentifier,
            locale: dateFormattingLocale
        )
    }

    private enum PickerField {
        case start
        case end
        case breakStart
        case breakEnd
    }

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
        presentSheet(picker)
    }

    private func presentSheet(_ viewController: UIViewController) {
        let navigationController = UINavigationController(rootViewController: viewController)
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
        case .breakStart, .breakEnd: viewModel.start
        case .start, .end: nil
        }
    }

    private func maximumDate(for field: PickerField) -> Date? {
        switch field {
        case .end: viewModel.start?.addingTimeInterval(48 * 60 * 60)
        case .breakStart, .breakEnd: viewModel.end
        case .start: nil
        }
    }

    @objc private func saveTapped() {
        switch viewModel.save() {
        case let .saved(shift):
            onSaved?(shift)
        case let .failed(failure):
            presentSaveError(failure)
        case .invalid, .ignored:
            break
        }
        render()
    }

    private func presentSaveError(_ failure: EditShiftSaveFailure) {
        guard viewIfLoaded?.window != nil else { return }
        let isOverlap = failure == .overlap
        let alert = UIAlertController(
            title: isOverlap ? EditShiftStrings.overlapTitle : EditShiftStrings.genericErrorTitle,
            message: isOverlap ? EditShiftStrings.overlapMessage : EditShiftStrings.genericErrorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: EditShiftStrings.alertOK, style: .default))
        present(alert, animated: true)
    }

    private func presentDeleteConfirmation() {
        let alert = UIAlertController(
            title: EditShiftStrings.deleteConfirmationTitle,
            message: EditShiftStrings.deleteConfirmationMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: EditShiftStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(
            title: EditShiftStrings.delete,
            style: .destructive
        ) { [weak self] _ in
            self?.performConfirmedDelete()
        })
        present(alert, animated: true)
    }

    func performConfirmedDelete() {
        let result = viewModel.delete()
        render()

        let complete = { [weak self] in
            guard let self else { return }
            switch result {
            case let .deleted(id):
                onDeleted?(id)
            case .failed(.generic):
                presentDeleteError()
            case .ignored:
                break
            }
        }

        if presentedViewController is UIAlertController {
            dismiss(animated: true, completion: complete)
        } else {
            complete()
        }
    }

    private func presentDeleteError() {
        guard viewIfLoaded?.window != nil else { return }
        let alert = UIAlertController(
            title: EditShiftStrings.deleteErrorTitle,
            message: EditShiftStrings.deleteErrorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: EditShiftStrings.alertOK, style: .default))
        present(alert, animated: true)
    }
}
