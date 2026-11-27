import UIKit

final class ShiftHistoryFiltersViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    var onApply: ((ShiftHistoryQuery) -> Bool)?
    var onDismiss: (() -> Void)?

    private var draft: ShiftHistoryQuery
    private let options: [ShiftHistoryQuery.WorkTypeOption]
    private let timeZone: TimeZone
    private let currency: String
    private let locale: Locale
    private let now: Date
    private let form = UIStackView()
    private let dateChoices = UIStackView()
    private let dateFields = UIStackView()
    private let workChoices = UIStackView()
    private let first = UIDatePicker()
    private let last = UIDatePicker()
    private let minimum = UITextField()
    private let maximum = UITextField()
    private let feedback = UILabel()
    private let apply = UIButton(type: .system)
    private var dateMode: DateMode

    private enum DateMode { case all, month, custom }

    init(query: ShiftHistoryQuery, options: [ShiftHistoryQuery.WorkTypeOption], timeZone: TimeZone,
         currency: String, locale: Locale, now: Date) {
        draft = query
        self.options = options
        self.timeZone = timeZone
        self.currency = currency
        self.locale = locale
        self.now = now
        switch query.dates {
        case .all: dateMode = .all
        case .thisMonth: dateMode = .month
        case .custom: dateMode = .custom
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ShiftHistoryStrings.filters
        view.accessibilityIdentifier = "shiftHistory.filterSheet"
        view.backgroundColor = ShiftLedgerColors.backgroundPrimary
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: ShiftHistoryStrings.cancel, primaryAction: UIAction { [weak self] _ in self?.close() }
        )
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "shiftHistory.cancel"

        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "shiftHistory.filterScroll"
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        form.translatesAutoresizingMaskIntoConstraints = false
        form.axis = .vertical
        form.spacing = 12
        scroll.addSubview(form)
        let safe = view.safeAreaLayoutGuide
        let content = scroll.contentLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safe.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            form.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            form.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            form.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            form.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        [dateChoices, dateFields, workChoices].forEach { $0.axis = .vertical; $0.spacing = 8 }
        form.addArrangedSubview(label(ShiftHistoryStrings.date, header: true))
        form.addArrangedSubview(dateChoices)
        form.addArrangedSubview(dateFields)
        configurePicker(first, title: ShiftHistoryStrings.start, id: "start")
        configurePicker(last, title: ShiftHistoryStrings.end, id: "end")
        if case let .custom(start, end) = draft.dates {
            first.date = (try? start.startOfDay(in: timeZone)) ?? now
            last.date = (try? end.startOfDay(in: timeZone)) ?? now
        }
        form.addArrangedSubview(label(ShiftHistoryStrings.workType, header: true))
        form.addArrangedSubview(workChoices)
        form.addArrangedSubview(label(ShiftHistoryStrings.amount(currency), header: true))
        configureAmount(minimum, title: ShiftHistoryStrings.minimum, id: "minimum", bound: draft.minimum)
        configureAmount(maximum, title: ShiftHistoryStrings.maximum, id: "maximum", bound: draft.maximum)

        feedback.font = .preferredFont(forTextStyle: .footnote)
        feedback.adjustsFontForContentSizeCategory = true
        feedback.numberOfLines = 0
        feedback.textColor = ShiftLedgerColors.statusNegative
        feedback.accessibilityIdentifier = "shiftHistory.validation"
        form.addArrangedSubview(feedback)
        configureButton(apply, title: ShiftHistoryStrings.apply, id: "apply", filled: true)
        apply.addAction(UIAction { [weak self] _ in
            guard let self, let validated = validate(), onApply?(validated) == true else { return }
            close()
        }, for: .touchUpInside)
        form.addArrangedSubview(apply)
        let reset = UIButton(type: .system)
        configureButton(reset, title: ShiftHistoryStrings.reset, id: "resetDraft")
        reset.addAction(UIAction { [weak self] _ in self?.resetDraft() }, for: .touchUpInside)
        form.addArrangedSubview(reset)
        refreshChoices()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }

    private func close() {
        view.endEditing(true)
        dismiss(animated: true) { [onDismiss] in onDismiss?() }
    }

    private func configurePicker(_ picker: UIDatePicker, title: String, id: String) {
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        picker.locale = locale
        picker.calendar = calendar
        picker.timeZone = timeZone
        picker.date = now
        picker.accessibilityLabel = title
        picker.accessibilityIdentifier = "shiftHistory.date." + id
        picker.addAction(UIAction { [weak self] _ in _ = self?.validate() }, for: .valueChanged)
        dateFields.addArrangedSubview(label(title))
        let row = UIStackView(arrangedSubviews: [picker, UIView()])
        dateFields.addArrangedSubview(row)
    }

    private func configureAmount(_ field: UITextField, title: String, id: String, bound: Decimal?) {
        field.borderStyle = .roundedRect
        field.keyboardType = .decimalPad
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.accessibilityLabel = "\(title), \(currency)"
        field.accessibilityIdentifier = "shiftHistory.amount." + id
        if var bound { field.text = NSDecimalString(&bound, locale) }
        field.addAction(UIAction { [weak self] _ in _ = self?.validate() }, for: .editingChanged)
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak field] _ in field?.resignFirstResponder() })
        ]
        toolbar.sizeToFit()
        field.inputAccessoryView = toolbar
        form.addArrangedSubview(label(title))
        form.addArrangedSubview(field)
    }

    private func label(_ title: String, header: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = title
        label.textColor = ShiftLedgerColors.textPrimary
        label.font = .preferredFont(forTextStyle: header ? .headline : .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        if header { label.accessibilityTraits.insert(.header) }
        return label
    }

    private func configureButton(_ button: UIButton, title: String, id: String, filled: Bool = false) {
        var config = filled ? UIButton.Configuration.filled() : .plain()
        config.title = title
        config.titleLineBreakMode = .byWordWrapping
        config.contentInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
        config.baseForegroundColor = filled ? ShiftLedgerColors.onAccent : ShiftLedgerColors.accentPrimary
        config.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var result = incoming
            result.font = .preferredFont(forTextStyle: .body)
            return result
        }
        button.configuration = config
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.accessibilityIdentifier = "shiftHistory." + id
    }

    private func choice(_ stack: UIStackView, title: String, id: String, selected: Bool, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        configureButton(button, title: title, id: id)
        button.contentHorizontalAlignment = .leading
        button.configuration?.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        button.configuration?.imagePadding = 8
        if selected { button.accessibilityTraits.insert(.selected) }
        button.addAction(UIAction { [weak self, weak stack] _ in
            action()
            self?.refreshChoices()
            if let replacement = stack?.arrangedSubviews.first(where: { $0.accessibilityIdentifier == "shiftHistory." + id }) {
                UIAccessibility.post(notification: .layoutChanged, argument: replacement)
            }
        }, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    private func refreshChoices() {
        [dateChoices, workChoices].forEach { stack in
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }
        for (mode, title, id) in [(DateMode.all, ShiftHistoryStrings.allDates, "all"),
                                   (.month, ShiftHistoryStrings.thisMonth, "month"),
                                   (.custom, ShiftHistoryStrings.custom, "custom")] {
            choice(dateChoices, title: title, id: "date." + id, selected: dateMode == mode) { [weak self] in
                self?.dateMode = mode
            }
        }
        dateFields.isHidden = dateMode != .custom
        choice(workChoices, title: ShiftHistoryStrings.allTypes, id: "workType.all",
               selected: draft.workTypeIDs.isEmpty) { [weak self] in self?.draft.workTypeIDs.removeAll() }
        for option in options {
            choice(workChoices, title: option.isArchived ? ShiftHistoryStrings.archived(option.name) : option.name,
                   id: "workType." + option.id.uuidString, selected: draft.workTypeIDs.contains(option.id)) { [weak self] in
                guard let self else { return }
                if draft.workTypeIDs.remove(option.id) == nil { draft.workTypeIDs.insert(option.id) }
            }
        }
        _ = validate()
    }

    private func validate() -> ShiftHistoryQuery? {
        do {
            var query = draft
            switch dateMode {
            case .all: query.dates = .all
            case .month: query.dates = .thisMonth
            case .custom:
                guard let start = try? LocalDate(date: first.date, in: timeZone),
                      let end = try? LocalDate(date: last.date, in: timeZone)
                else { throw ShiftHistoryQuery.ValidationError.dates }
                query.dates = .custom(start, end)
            }
            query.minimum = try ShiftHistoryQuery.amount(minimum.text ?? "", locale: locale)
            query.maximum = try ShiftHistoryQuery.amount(maximum.text ?? "", locale: locale)
            _ = try query.results([], now: now, timeZone: timeZone)
            feedback.isHidden = true
            apply.isEnabled = true
            return query
        } catch {
            let text: String
            switch error as? ShiftHistoryQuery.ValidationError {
            case .dates: text = ShiftHistoryStrings.invalidDate
            case .amountRange: text = ShiftHistoryStrings.invalidRange
            default: text = ShiftHistoryStrings.invalidAmount
            }
            feedback.text = text
            feedback.isHidden = false
            apply.isEnabled = false
            return nil
        }
    }

    private func resetDraft() {
        draft = ShiftHistoryQuery(sort: draft.sort)
        dateMode = .all
        first.date = now
        last.date = now
        minimum.text = nil
        maximum.text = nil
        refreshChoices()
    }
}
