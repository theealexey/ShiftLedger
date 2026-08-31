import UIKit

final class AddShiftView: UIView {
    var onStartTapped: (() -> Void)?
    var onEndTapped: (() -> Void)?
    var onBreakStartTapped: (() -> Void)?
    var onBreakEndTapped: (() -> Void)?
    var onBreakEnabledChanged: ((Bool) -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stack = UIStackView()
    private let breakStack = UIStackView()
    private let startRow = AddShiftDateRow(title: AddShiftStrings.start)
    private let endRow = AddShiftDateRow(title: AddShiftStrings.end)
    private let timeZoneLabel = UILabel()
    private let breakSwitchRow = AddShiftSwitchRow(title: AddShiftStrings.unpaidBreak)
    private let breakStartRow = AddShiftDateRow(title: AddShiftStrings.breakStart)
    private let breakEndRow = AddShiftDateRow(title: AddShiftStrings.breakEnd)
    private let validationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(
        startText: String?,
        startAccessibilityText: String?,
        endText: String?,
        endAccessibilityText: String?,
        timeZoneText: String,
        breakEnabled: Bool,
        breakStartText: String?,
        breakStartAccessibilityText: String?,
        breakEndText: String?,
        breakEndAccessibilityText: String?,
        validationMessage: String?
    ) {
        startRow.setValue(startText ?? AddShiftStrings.select, accessibilityValue: startAccessibilityText)
        endRow.setValue(endText ?? AddShiftStrings.select, accessibilityValue: endAccessibilityText)
        timeZoneLabel.text = timeZoneText
        breakSwitchRow.isOn = breakEnabled
        breakStartRow.setValue(breakStartText ?? AddShiftStrings.select, accessibilityValue: breakStartAccessibilityText)
        breakEndRow.setValue(breakEndText ?? AddShiftStrings.select, accessibilityValue: breakEndAccessibilityText)
        breakStack.isHidden = !breakEnabled
        validationLabel.text = validationMessage
        validationLabel.isHidden = validationMessage == nil
        setNeedsLayout()
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true

        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        breakStack.axis = .vertical
        breakStack.alignment = .fill
        breakStack.distribution = .fill
        breakStack.spacing = 0

        timeZoneLabel.font = ShiftLedgerTypography.caption
        timeZoneLabel.textColor = ShiftLedgerColors.textSecondary
        timeZoneLabel.numberOfLines = 0
        timeZoneLabel.adjustsFontForContentSizeCategory = true

        validationLabel.font = ShiftLedgerTypography.caption
        validationLabel.textColor = ShiftLedgerColors.statusNegative
        validationLabel.numberOfLines = 0
        validationLabel.adjustsFontForContentSizeCategory = true
        validationLabel.isHidden = true
    }

    private func configureHierarchy() {
        [scrollView, contentView, stack, timeZoneLabel, validationLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stack)
        stack.addArrangedSubview(startRow)
        stack.addArrangedSubview(endRow)
        stack.addArrangedSubview(timeZoneLabel)
        stack.addArrangedSubview(breakSwitchRow)
        stack.addArrangedSubview(breakStack)
        stack.addArrangedSubview(validationLabel)
        breakStack.addArrangedSubview(breakStartRow)
        breakStack.addArrangedSubview(breakEndRow)
        stack.setCustomSpacing(8, after: endRow)
        stack.setCustomSpacing(16, after: timeZoneLabel)
        stack.setCustomSpacing(8, after: breakSwitchRow)
        stack.setCustomSpacing(12, after: breakStack)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func configureInteractions() {
        startRow.addAction(UIAction { [weak self] _ in self?.onStartTapped?() }, for: .touchUpInside)
        endRow.addAction(UIAction { [weak self] _ in self?.onEndTapped?() }, for: .touchUpInside)
        breakStartRow.addAction(UIAction { [weak self] _ in self?.onBreakStartTapped?() }, for: .touchUpInside)
        breakEndRow.addAction(UIAction { [weak self] _ in self?.onBreakEndTapped?() }, for: .touchUpInside)
        breakSwitchRow.onChanged = { [weak self] isOn in self?.onBreakEnabledChanged?(isOn) }
    }
}

private final class AddShiftDateRow: UIControl {
    private let titleLabel: UILabel
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separator = AddShiftSeparator()

    init(title: String) {
        titleLabel = UILabel()
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ShiftLedgerTypography.body
        titleLabel.textColor = ShiftLedgerColors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true
        valueLabel.font = ShiftLedgerTypography.callout
        valueLabel.textColor = ShiftLedgerColors.textSecondary
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.textAlignment = .right
        chevron.tintColor = ShiftLedgerColors.textTertiary
        chevron.isAccessibilityElement = false
        [titleLabel, valueLabel, chevron, separator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            valueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -12),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 9),
            chevron.heightAnchor.constraint(equalToConstant: 13),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func setValue(_ value: String, accessibilityValue: String?) {
        valueLabel.text = value
        valueLabel.textColor = value == AddShiftStrings.select ? ShiftLedgerColors.textTertiary : ShiftLedgerColors.textSecondary
        self.accessibilityValue = accessibilityValue ?? value
    }
}

private final class AddShiftSwitchRow: UIControl {
    private let titleLabel = UILabel()
    private let toggle = UISwitch()
    private let separator = AddShiftSeparator()
    var onChanged: ((Bool) -> Void)?
    var isOn: Bool { get { toggle.isOn } set { toggle.setOn(newValue, animated: false) } }

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ShiftLedgerTypography.body
        titleLabel.textColor = ShiftLedgerColors.textPrimary
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        toggle.onTintColor = ShiftLedgerColors.accentPrimary
        toggle.accessibilityLabel = title
        toggle.addAction(UIAction { [weak self] _ in self?.onChanged?(self?.toggle.isOn ?? false) }, for: .valueChanged)
        isAccessibilityElement = false
        [titleLabel, toggle, separator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

private final class AddShiftSeparator: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = ShiftLedgerColors.separator
        heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
