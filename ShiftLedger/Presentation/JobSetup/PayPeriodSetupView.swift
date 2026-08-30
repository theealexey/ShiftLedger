import UIKit

final class PayPeriodSetupView: UIView {
    var onBackTapped: (() -> Void)?
    var onFrequencySelected: ((PayPeriodFrequency) -> Void)?
    var onAnchorTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let topRow = UIStackView()
    private let backButton = UIButton(type: .system)
    private let stepLabel = UILabel()
    private let progressStack = UIStackView()
    private let progressSegments = (0..<4).map { _ in UIView() }
    private let questionLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsStack = UIStackView()
    private let anchorSection = UIStackView()
    private let anchorTitleLabel = UILabel()
    private let anchorSubtitleLabel = UILabel()
    private let anchorRow = TappableControl()
    private let anchorValueLabel = UILabel()
    private let anchorChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let anchorSeparator = UIView()
    private let continueButton = UIButton(type: .system)

    private let weeklyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.weekly)
    private let biweeklyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.biweekly)
    private let calendarMonthlyControl = FrequencyOptionControl(title: PayPeriodSetupStrings.calendarMonthly)

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureAppearance()
        configureSubviews()
        configureLayout()
        configureInteractions()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func render(frequency: PayPeriodFrequency?, anchorDateText: String?, canContinue: Bool) {
        weeklyControl.isSelected = frequency == .weekly
        biweeklyControl.isSelected = frequency == .biweekly
        calendarMonthlyControl.isSelected = frequency == .calendarMonthly
        let showsAnchor = frequency == .weekly || frequency == .biweekly
        anchorTitleLabel.isHidden = !showsAnchor
        anchorSubtitleLabel.isHidden = !showsAnchor
        anchorRow.isHidden = !showsAnchor
        anchorSeparator.isHidden = !showsAnchor
        anchorValueLabel.text = anchorDateText ?? PayPeriodSetupStrings.anchorChoose
        anchorRow.accessibilityValue = anchorDateText ?? PayPeriodSetupStrings.anchorChoose
        continueButton.isEnabled = canContinue

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.baseForegroundColor = canContinue
            ? ShiftLedgerColors.accentPrimary
            : ShiftLedgerColors.textTertiary
        continueButton.configuration = configuration
    }

    private func configureAppearance() {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = ShiftLedgerColors.textSecondary
        backButton.accessibilityLabel = PayPeriodSetupStrings.back
        backButton.accessibilityTraits = .button

        stepLabel.text = PayPeriodSetupStrings.stepIndicator
        stepLabel.font = ShiftLedgerTypography.caption
        stepLabel.textColor = ShiftLedgerColors.textTertiary
        stepLabel.accessibilityLabel = PayPeriodSetupStrings.stepIndicatorAccessibilityLabel

        progressStack.axis = .horizontal
        progressStack.distribution = .fillEqually
        progressStack.spacing = 3
        progressSegments.forEach { segment in
            segment.backgroundColor = ShiftLedgerColors.separator
            segment.isAccessibilityElement = false
        }
        progressSegments.prefix(2).forEach { $0.backgroundColor = ShiftLedgerColors.accentPrimary }
        progressStack.isAccessibilityElement = false

        questionLabel.text = PayPeriodSetupStrings.title
        questionLabel.font = ShiftLedgerTypography.onboardingQuestion
        questionLabel.textColor = ShiftLedgerColors.textPrimary
        questionLabel.numberOfLines = 0
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.accessibilityTraits = .header

        subtitleLabel.text = PayPeriodSetupStrings.subtitle
        subtitleLabel.font = ShiftLedgerTypography.body
        subtitleLabel.textColor = ShiftLedgerColors.textSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        optionsStack.axis = .vertical
        optionsStack.spacing = 0
        optionsStack.addArrangedSubview(weeklyControl)
        optionsStack.addArrangedSubview(biweeklyControl)
        optionsStack.addArrangedSubview(calendarMonthlyControl)

        anchorSection.axis = .vertical
        anchorSection.spacing = 0
        anchorSection.addArrangedSubview(anchorTitleLabel)
        anchorSection.addArrangedSubview(anchorSubtitleLabel)
        anchorSection.addArrangedSubview(anchorRow)
        anchorSection.addArrangedSubview(anchorSeparator)
        anchorSection.setCustomSpacing(8, after: anchorTitleLabel)
        anchorSection.setCustomSpacing(16, after: anchorSubtitleLabel)

        anchorTitleLabel.text = PayPeriodSetupStrings.anchorTitle
        anchorTitleLabel.font = ShiftLedgerTypography.headline
        anchorTitleLabel.textColor = ShiftLedgerColors.textPrimary
        anchorTitleLabel.numberOfLines = 0
        anchorTitleLabel.adjustsFontForContentSizeCategory = true

        anchorSubtitleLabel.text = PayPeriodSetupStrings.anchorSubtitle
        anchorSubtitleLabel.font = ShiftLedgerTypography.body
        anchorSubtitleLabel.textColor = ShiftLedgerColors.textSecondary
        anchorSubtitleLabel.numberOfLines = 0
        anchorSubtitleLabel.adjustsFontForContentSizeCategory = true

        anchorValueLabel.font = ShiftLedgerTypography.callout
        anchorValueLabel.textColor = ShiftLedgerColors.textPrimary
        anchorValueLabel.numberOfLines = 0
        anchorValueLabel.adjustsFontForContentSizeCategory = true

        anchorChevron.tintColor = ShiftLedgerColors.textTertiary
        anchorChevron.contentMode = .scaleAspectFit
        anchorChevron.isAccessibilityElement = false
        anchorRow.isAccessibilityElement = true
        anchorRow.accessibilityLabel = PayPeriodSetupStrings.anchorChoose
        anchorRow.accessibilityTraits = .button
        anchorSeparator.backgroundColor = ShiftLedgerColors.separator

        var continueConfiguration = UIButton.Configuration.plain()
        continueConfiguration.title = JobSetupStrings.continueTitle
        continueConfiguration.image = UIImage(systemName: "arrow.right")
        continueConfiguration.imagePlacement = .trailing
        continueConfiguration.imagePadding = 8
        continueConfiguration.titleAlignment = .trailing
        continueConfiguration.baseForegroundColor = ShiftLedgerColors.textTertiary
        continueConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        continueConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.button
            return transformedAttributes
        }
        continueButton.configuration = continueConfiguration
        continueButton.contentHorizontalAlignment = .trailing
        continueButton.accessibilityTraits = .button
    }

    private func configureSubviews() {
        [scrollView, contentView, topRow, backButton, stepLabel, progressStack, questionLabel, subtitleLabel, optionsStack, anchorSection, anchorTitleLabel, anchorSubtitleLabel, anchorRow, anchorValueLabel, anchorChevron, anchorSeparator, continueButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.addArrangedSubview(backButton)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(stepLabel)

        anchorRow.addSubview(anchorValueLabel)
        anchorRow.addSubview(anchorChevron)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        [topRow, progressStack, questionLabel, subtitleLabel, optionsStack, anchorSection, continueButton].forEach(contentView.addSubview)
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
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            progressStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 8),
            progressStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressStack.heightAnchor.constraint(equalToConstant: 1),

            questionLabel.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            questionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),

            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            optionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            optionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            anchorRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            anchorValueLabel.leadingAnchor.constraint(equalTo: anchorRow.leadingAnchor),
            anchorValueLabel.topAnchor.constraint(equalTo: anchorRow.topAnchor, constant: 8),
            anchorValueLabel.bottomAnchor.constraint(equalTo: anchorRow.bottomAnchor, constant: -8),
            anchorValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: anchorChevron.leadingAnchor, constant: -12),
            anchorChevron.trailingAnchor.constraint(equalTo: anchorRow.trailingAnchor),
            anchorChevron.centerYAnchor.constraint(equalTo: anchorRow.centerYAnchor),
            anchorChevron.widthAnchor.constraint(equalToConstant: 9),
            anchorChevron.heightAnchor.constraint(equalToConstant: 13),
            anchorSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            anchorSection.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 28),
            anchorSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            anchorSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            continueButton.topAnchor.constraint(greaterThanOrEqualTo: anchorSection.bottomAnchor, constant: 44),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        backButton.addAction(UIAction { [weak self] _ in self?.onBackTapped?() }, for: .primaryActionTriggered)
        weeklyControl.addAction(UIAction { [weak self] _ in self?.onFrequencySelected?(.weekly) }, for: .touchUpInside)
        biweeklyControl.addAction(UIAction { [weak self] _ in self?.onFrequencySelected?(.biweekly) }, for: .touchUpInside)
        calendarMonthlyControl.addAction(UIAction { [weak self] _ in self?.onFrequencySelected?(.calendarMonthly) }, for: .touchUpInside)
        anchorRow.addAction(UIAction { [weak self] _ in self?.onAnchorTapped?() }, for: .touchUpInside)
        continueButton.addAction(UIAction { [weak self] _ in self?.onContinueTapped?() }, for: .primaryActionTriggered)
    }
}

private final class TappableControl: UIControl {
    override func accessibilityActivate() -> Bool {
        sendActions(for: .touchUpInside)
        return true
    }
}

private final class FrequencyOptionControl: UIButton {
    private let optionTitle: String

    override var isSelected: Bool {
        didSet {
            setTitle(isSelected ? "●  \(optionTitle)" : "○  \(optionTitle)", for: .normal)
            setTitleColor(isSelected ? ShiftLedgerColors.accentPrimary : ShiftLedgerColors.textPrimary, for: .normal)
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    init(title: String) {
        optionTitle = title
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        setTitle("○  \(title)", for: .normal)
        setTitleColor(ShiftLedgerColors.textPrimary, for: .normal)
        titleLabel?.font = ShiftLedgerTypography.body
        titleLabel?.numberOfLines = 0
        titleLabel?.adjustsFontForContentSizeCategory = true
        contentHorizontalAlignment = .leading
        contentVerticalAlignment = .center
        configuration = nil
        heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
