import UIKit

final class ChangePayRateView: UIView {
    var onAmountChanged: ((String) -> Void)?
    var onEffectiveDateChanged: ((Date) -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let contextStack = UIStackView()
    private let nameLabel = UILabel()
    private let basisLabel = UILabel()
    private let amountTitleLabel = UILabel()
    private let amountField = UITextField()
    private let amountUnderline = UIView()
    private let currencyRow = UIView()
    private let currencyTitleLabel = UILabel()
    private let currencyValueLabel = UILabel()
    private let effectiveDateTitleLabel = UILabel()
    private let effectiveDatePicker = UIDatePicker()
    private let effectiveDateExplanationLabel = UILabel()
    private let timeZoneRow = UIView()
    private let timeZoneTitleLabel = UILabel()
    private let timeZoneValueLabel = UILabel()
    private let duplicateDateLabel = UILabel()

    var amountText: String {
        get { amountField.text ?? "" }
        set { amountField.text = newValue }
    }

    init(workType: WorkType, currencyCode: String, timeZoneIdentifier: String, date: Date) {
        super.init(frame: .zero)
        configureAppearance(
            workType: workType,
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            date: date
        )
        configureHierarchy()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func render(amountText: String, effectiveDate: Date, hasDuplicateDate: Bool) {
        self.amountText = amountText
        if effectiveDatePicker.date != effectiveDate {
            effectiveDatePicker.date = effectiveDate
        }
        duplicateDateLabel.isHidden = !hasDuplicateDate
    }

    private func configureAppearance(
        workType: WorkType,
        currencyCode: String,
        timeZoneIdentifier: String,
        date: Date
    ) {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "changePayRate.screen"
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        contentStack.axis = .vertical
        contentStack.alignment = .fill

        contextStack.axis = .vertical
        contextStack.alignment = .fill
        contextStack.spacing = 4
        nameLabel.text = workType.name ?? ChangePayRateStrings.unnamed
        nameLabel.font = ShiftLedgerTypography.headline
        nameLabel.textColor = ShiftLedgerColors.textPrimary
        nameLabel.numberOfLines = 0
        nameLabel.adjustsFontForContentSizeCategory = true
        basisLabel.text = workType.basePayBasis == .hourly
            ? ChangePayRateStrings.hourly : ChangePayRateStrings.fixedPerShift
        basisLabel.font = ShiftLedgerTypography.callout
        basisLabel.textColor = ShiftLedgerColors.textSecondary
        basisLabel.numberOfLines = 0
        basisLabel.adjustsFontForContentSizeCategory = true
        contextStack.isAccessibilityElement = true
        contextStack.accessibilityLabel = nameLabel.text
        contextStack.accessibilityValue = basisLabel.text
        contextStack.accessibilityIdentifier = "changePayRate.workType"

        configureTitle(
            amountTitleLabel,
            text: workType.basePayBasis == .hourly
                ? ChangePayRateStrings.newHourlyRate : ChangePayRateStrings.newPerShiftAmount
        )
        amountField.font = ShiftLedgerTypography.basePayAmount
        amountField.textColor = ShiftLedgerColors.textPrimary
        amountField.backgroundColor = .clear
        amountField.borderStyle = .none
        amountField.keyboardType = .decimalPad
        amountField.adjustsFontForContentSizeCategory = true
        amountField.accessibilityIdentifier = "changePayRate.amount"
        amountField.accessibilityLabel = amountTitleLabel.text
        amountField.accessibilityHint = ChangePayRateStrings.amountHint
        amountUnderline.backgroundColor = ShiftLedgerColors.separator
        amountUnderline.isAccessibilityElement = false

        configureReadOnlyRow(
            currencyRow,
            title: currencyTitleLabel,
            value: currencyValueLabel,
            label: ChangePayRateStrings.currency,
            text: currencyCode,
            identifier: "changePayRate.currency"
        )
        configureTitle(effectiveDateTitleLabel, text: ChangePayRateStrings.effectiveDate)
        effectiveDatePicker.datePickerMode = .date
        effectiveDatePicker.preferredDatePickerStyle = .compact
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
            effectiveDatePicker.timeZone = timeZone
        }
        effectiveDatePicker.calendar = calendar
        effectiveDatePicker.date = date
        effectiveDatePicker.accessibilityIdentifier = "changePayRate.effectiveDate"
        effectiveDatePicker.accessibilityLabel = ChangePayRateStrings.effectiveDate

        effectiveDateExplanationLabel.text = ChangePayRateStrings.effectiveDateExplanation
        effectiveDateExplanationLabel.font = ShiftLedgerTypography.callout
        effectiveDateExplanationLabel.textColor = ShiftLedgerColors.textSecondary
        effectiveDateExplanationLabel.numberOfLines = 0
        effectiveDateExplanationLabel.adjustsFontForContentSizeCategory = true

        configureReadOnlyRow(
            timeZoneRow,
            title: timeZoneTitleLabel,
            value: timeZoneValueLabel,
            label: ChangePayRateStrings.timeZone,
            text: timeZoneIdentifier,
            identifier: "changePayRate.timeZone"
        )
        duplicateDateLabel.text = ChangePayRateStrings.duplicateDate
        duplicateDateLabel.font = ShiftLedgerTypography.callout
        duplicateDateLabel.textColor = ShiftLedgerColors.statusNegative
        duplicateDateLabel.numberOfLines = 0
        duplicateDateLabel.adjustsFontForContentSizeCategory = true
        duplicateDateLabel.accessibilityIdentifier = "changePayRate.effectiveDate.error"
        duplicateDateLabel.isHidden = true
    }

    private func configureTitle(_ label: UILabel, text: String) {
        label.text = text
        label.font = ShiftLedgerTypography.headline
        label.textColor = ShiftLedgerColors.textPrimary
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
    }

    private func configureReadOnlyRow(
        _ row: UIView,
        title: UILabel,
        value: UILabel,
        label: String,
        text: String,
        identifier: String
    ) {
        title.text = label
        title.font = ShiftLedgerTypography.body
        title.textColor = ShiftLedgerColors.textPrimary
        title.numberOfLines = 0
        title.adjustsFontForContentSizeCategory = true
        value.text = text
        value.font = ShiftLedgerTypography.callout
        value.textColor = ShiftLedgerColors.textSecondary
        value.numberOfLines = 0
        value.textAlignment = .right
        value.adjustsFontForContentSizeCategory = true
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = identifier
        row.accessibilityLabel = label
        row.accessibilityValue = text
    }

    private func configureHierarchy() {
        [scrollView, contentView, contentStack, contextStack, nameLabel, basisLabel,
         amountTitleLabel, amountField, amountUnderline, currencyRow, currencyTitleLabel,
         currencyValueLabel, effectiveDateTitleLabel, effectiveDatePicker,
         effectiveDateExplanationLabel, timeZoneRow, timeZoneTitleLabel, timeZoneValueLabel,
         duplicateDateLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)
        contextStack.addArrangedSubview(nameLabel)
        contextStack.addArrangedSubview(basisLabel)
        currencyRow.addSubview(currencyTitleLabel)
        currencyRow.addSubview(currencyValueLabel)
        timeZoneRow.addSubview(timeZoneTitleLabel)
        timeZoneRow.addSubview(timeZoneValueLabel)
        [contextStack, amountTitleLabel, amountField, amountUnderline, currencyRow,
         effectiveDateTitleLabel, effectiveDatePicker, effectiveDateExplanationLabel,
         timeZoneRow, duplicateDateLabel].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(28, after: contextStack)
        contentStack.setCustomSpacing(6, after: amountTitleLabel)
        contentStack.setCustomSpacing(12, after: amountField)
        contentStack.setCustomSpacing(18, after: amountUnderline)
        contentStack.setCustomSpacing(24, after: currencyRow)
        contentStack.setCustomSpacing(6, after: effectiveDateTitleLabel)
        contentStack.setCustomSpacing(12, after: effectiveDatePicker)
        contentStack.setCustomSpacing(12, after: effectiveDateExplanationLabel)
        contentStack.setCustomSpacing(8, after: timeZoneRow)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            amountField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            amountUnderline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale),
            currencyRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            effectiveDatePicker.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            timeZoneRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
        constrainRow(currencyRow, title: currencyTitleLabel, value: currencyValueLabel)
        constrainRow(timeZoneRow, title: timeZoneTitleLabel, value: timeZoneValueLabel)
    }

    private func constrainRow(_ row: UIView, title: UILabel, value: UILabel) {
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            title.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
            title.trailingAnchor.constraint(lessThanOrEqualTo: value.leadingAnchor, constant: -12),
            value.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            value.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: 8),
            value.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -8),
            value.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
    }

    private func configureInteractions() {
        amountField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onAmountChanged?(amountText)
        }, for: .editingChanged)
        amountField.addAction(UIAction { [weak self] _ in
            self?.amountUnderline.backgroundColor = ShiftLedgerColors.accentPrimary
        }, for: .editingDidBegin)
        amountField.addAction(UIAction { [weak self] _ in
            self?.amountUnderline.backgroundColor = ShiftLedgerColors.separator
        }, for: .editingDidEnd)
        effectiveDatePicker.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onEffectiveDateChanged?(effectiveDatePicker.date)
        }, for: .valueChanged)
    }
}
