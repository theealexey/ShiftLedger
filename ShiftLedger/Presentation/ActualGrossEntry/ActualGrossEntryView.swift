import UIKit

final class ActualGrossEntryView: UIView {
    var onAmountChanged: ((String) -> Void)?
    var onCompareTapped: (() -> Void)?

    private let periodLabel = UILabel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let questionLabel = UILabel()
    private let supportingLabel = UILabel()
    private let amountContainer = UIView()
    private let inputStack = UIStackView()
    private let amountLabel = UILabel()
    private let amountRow = UIStackView()
    private let amountTextField = FilledTextField()
    private let currencyLabel = UILabel()
    private let validationLabel = UILabel()
    private let compareButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        configureHierarchy()
        configureLayout()
        configureInteractions()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: ActualGrossEntryView, _) in
            self.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        updateSupportingWrapping()
        super.layoutSubviews()
        guard amountLabel.bounds.width > 1, let text = amountLabel.text, !text.isEmpty else { return }
        let baseFont = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traitCollection)
        // Callout uses the regular system face. Keep its scaled size while managing resizing locally.
        let descriptor = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .regular).fontDescriptor
        let measure = UILabel()
        measure.numberOfLines = 1
        let words = text.split(whereSeparator: { $0.isWhitespace })
        let scale = max(1, traitCollection.displayScale)
        let available = floor(amountLabel.bounds.width * scale) / scale - 1 / scale
        func fits(_ size: CGFloat) -> Bool {
            measure.font = UIFont(descriptor: descriptor, size: size)
            return words.allSatisfy { word in
                measure.text = String(word)
                let width = measure.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)).width
                return ceil(width * scale) / scale <= available
            }
        }
        var upper = baseFont.pointSize
        // Never reduce below the normal body size, or below the requested font at smaller categories.
        var lower = min(upper, UIFont.preferredFont(forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize)
        // Transient zero/narrow layouts must not crash or install a known non-fitting font.
        // Supported viewport widths (320 pt and above) are checked by the hosted layout test.
        guard fits(lower) else { return }
        if fits(upper) {
            lower = upper
        } else {
            for _ in 0..<14 {
                let candidate = (lower + upper) / 2
                if fits(candidate) { lower = candidate } else { upper = candidate }
            }
        }
        let fitted = UIFont(descriptor: descriptor, size: lower)
        if amountLabel.font != fitted { amountLabel.font = fitted }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineBreakStrategy = []
        // Zero inherits the layout manager's factor; a positive threshold overrides it.
        style.hyphenationFactor = 0.001
        style.usesDefaultHyphenation = false
        let attributed = NSAttributedString(string: text, attributes: [
            .font: fitted, .foregroundColor: ShiftLedgerColors.textSecondary, .paragraphStyle: style
        ])
        if amountLabel.attributedText?.isEqual(to: attributed) != true {
            amountLabel.attributedText = attributed
        }
    }

    private func updateSupportingWrapping() {
        guard supportingLabel.bounds.width > 1, let text = supportingLabel.text, !text.isEmpty else { return }
        let preferred = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let base = UIFont.systemFont(ofSize: preferred.pointSize, weight: .regular)
        let probe = UILabel()
        let scale = max(1, traitCollection.displayScale)
        let available = floor(supportingLabel.bounds.width * scale) / scale - 1 / scale
        let words = text.split(whereSeparator: { $0.isWhitespace })
        func fits(_ size: CGFloat) -> Bool {
            probe.font = base.withSize(size)
            return words.allSatisfy { word in
                probe.text = String(word)
                return ceil(probe.sizeThatFits(CGSize(width: 10000, height: 10000)).width * scale) / scale <= available
            }
        }
        var lower = min(17, base.pointSize)
        var upper = base.pointSize
        // Unsupported widths retain the canonical text; never install a known non-fitting font.
        guard fits(lower) else { return }
        if fits(upper) { lower = upper } else {
            for _ in 0..<14 {
                let candidate = (lower + upper) / 2
                if fits(candidate) { lower = candidate } else { upper = candidate }
            }
        }
        let font = base.withSize(lower)
        if supportingLabel.font == font,
           let current = supportingLabel.attributedText, current.string == text,
           current.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == font,
           let style = current.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle,
           style.lineBreakMode == .byWordWrapping, style.lineBreakStrategy.isEmpty,
           style.hyphenationFactor == 0.001, !style.usesDefaultHyphenation { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = []
        paragraph.hyphenationFactor = 0.001
        paragraph.usesDefaultHyphenation = false
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: ShiftLedgerColors.textSecondary, .paragraphStyle: paragraph
        ])
        if supportingLabel.font != font { supportingLabel.font = font }
        if supportingLabel.attributedText?.isEqual(to: attributed) != true {
            supportingLabel.attributedText = attributed
        }
    }

    func render(
        amountText: String,
        currencyCode: String,
        canCompare: Bool,
        validationMessage: String?
    ) {
        if amountTextField.text != amountText {
            amountTextField.text = amountText
        }
        currencyLabel.text = currencyCode
        currencyLabel.accessibilityLabel = currencyCode
        compareButton.isEnabled = canCompare
        validationLabel.text = validationMessage
        validationLabel.isHidden = validationMessage == nil
    }

    func renderPeriod(_ heading: OverviewFormatting.PeriodHeading) {
        periodLabel.text = [heading.date, heading.time].compactMap { $0 }.joined(separator: "\n")
        periodLabel.accessibilityLabel = heading.accessibilityLabel
        periodLabel.isHidden = false
    }

    private func configureAppearance() {
        periodLabel.font = ShiftLedgerTypography.callout
        periodLabel.textColor = ShiftLedgerColors.textSecondary
        periodLabel.adjustsFontForContentSizeCategory = true
        periodLabel.numberOfLines = 0
        periodLabel.lineBreakMode = .byWordWrapping
        periodLabel.accessibilityIdentifier = "actualGrossEntry.period"
        periodLabel.isHidden = true
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "actualGrossEntry.screen"
        scrollView.alwaysBounceVertical = true

        contentStack.axis = .vertical
        contentStack.spacing = 16

        configureLabel(
            questionLabel,
            text: ActualGrossEntryStrings.question,
            font: ShiftLedgerTypography.onboardingQuestion,
            color: ShiftLedgerColors.textPrimary
        )
        questionLabel.accessibilityTraits = .header
        questionLabel.accessibilityIdentifier = "actualGrossEntry.question"

        configureLabel(
            supportingLabel,
            text: ActualGrossEntryStrings.supporting,
            font: ShiftLedgerTypography.body,
            color: ShiftLedgerColors.textSecondary
        )
        supportingLabel.adjustsFontForContentSizeCategory = false
        supportingLabel.lineBreakMode = .byWordWrapping
        supportingLabel.lineBreakStrategy = []
        supportingLabel.accessibilityIdentifier = "actualGrossEntry.supporting"

        amountContainer.backgroundColor = ShiftLedgerColors.surfacePrimary
        amountContainer.layer.cornerCurve = .continuous
        amountContainer.layer.cornerRadius = 18
        amountContainer.accessibilityIdentifier = "actualGrossEntry.amount.container"

        inputStack.axis = .vertical
        inputStack.spacing = 8

        configureLabel(
            amountLabel,
            text: ActualGrossEntryStrings.amount,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.textSecondary
        )
        amountLabel.lineBreakMode = .byWordWrapping
        amountLabel.lineBreakStrategy = []
        amountLabel.adjustsFontForContentSizeCategory = false
        amountLabel.accessibilityIdentifier = "actualGrossEntry.amount.label"

        amountRow.axis = .horizontal
        amountRow.alignment = .firstBaseline
        amountRow.spacing = 12

        amountTextField.font = ShiftLedgerTypography.basePayAmount
        amountTextField.textColor = ShiftLedgerColors.textPrimary
        amountTextField.borderStyle = .none
        amountTextField.keyboardType = .decimalPad
        amountTextField.textAlignment = .natural
        amountTextField.adjustsFontForContentSizeCategory = true
        amountTextField.textContentType = nil
        amountTextField.accessibilityLabel = ActualGrossEntryStrings.amount
        amountTextField.accessibilityIdentifier = "actualGrossEntry.amount.input"

        configureLabel(
            currencyLabel,
            text: nil,
            font: ShiftLedgerTypography.headline,
            color: ShiftLedgerColors.textSecondary
        )
        currencyLabel.numberOfLines = 1
        currencyLabel.accessibilityIdentifier = "actualGrossEntry.currency"
        currencyLabel.setContentHuggingPriority(.required, for: .horizontal)
        currencyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        configureLabel(
            validationLabel,
            text: nil,
            font: ShiftLedgerTypography.callout,
            color: ShiftLedgerColors.statusNegative
        )
        validationLabel.accessibilityIdentifier = "actualGrossEntry.validation"
        validationLabel.isHidden = true

        var configuration = UIButton.Configuration.filled()
        configuration.title = ActualGrossEntryStrings.compare
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = ShiftLedgerColors.accentPrimary
        configuration.baseForegroundColor = ShiftLedgerColors.onAccent
        compareButton.configuration = configuration
        compareButton.titleLabel?.font = ShiftLedgerTypography.button
        compareButton.titleLabel?.adjustsFontForContentSizeCategory = true
        compareButton.accessibilityLabel = ActualGrossEntryStrings.compare
        compareButton.accessibilityIdentifier = "actualGrossEntry.compare"
    }

    private func configureHierarchy() {
        [scrollView, contentView, contentStack, amountContainer, inputStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)

        [questionLabel, supportingLabel, amountContainer, validationLabel, compareButton]
            .forEach(contentStack.addArrangedSubview)
        amountContainer.addSubview(inputStack)
        [amountLabel, amountRow].forEach(inputStack.addArrangedSubview)
        [amountTextField, currencyLabel].forEach(amountRow.addArrangedSubview)

        contentStack.insertArrangedSubview(periodLabel, at: 2)

        contentStack.setCustomSpacing(8, after: questionLabel)
        contentStack.setCustomSpacing(24, after: supportingLabel)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            inputStack.topAnchor.constraint(equalTo: amountContainer.topAnchor, constant: 16),
            inputStack.leadingAnchor.constraint(equalTo: amountContainer.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: amountContainer.trailingAnchor, constant: -16),
            inputStack.bottomAnchor.constraint(equalTo: amountContainer.bottomAnchor, constant: -16),

            amountTextField.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            compareButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func configureInteractions() {
        amountTextField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        compareButton.addAction(UIAction { [weak self] _ in
            self?.onCompareTapped?()
        }, for: .touchUpInside)
    }

    private func configureLabel(
        _ label: UILabel,
        text: String?,
        font: UIFont,
        color: UIColor
    ) {
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    @objc private func amountChanged() {
        onAmountChanged?(amountTextField.text ?? "")
    }

}
