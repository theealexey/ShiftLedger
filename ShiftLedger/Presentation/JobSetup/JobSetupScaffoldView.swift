import UIKit

final class JobSetupScaffoldView: UIView {
    private enum Layout {
        static let contentInset: CGFloat = 24
        static let safeAreaTopInset: CGFloat = 20
        static let headerToProgress: CGFloat = 12
        static let progressSegmentGap: CGFloat = 3
        static let actionBottomInset: CGFloat = 44
        static let scrollToActionGap: CGFloat = 16
    }

    let contentView = UIView()
    let continueButton = UIButton(type: .system)

    var onBackTapped: (() -> Void)?
    var onContinueTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let topRow = UIStackView()
    private let topRowSpacer = UIView()
    private let brandLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let stepLabel = UILabel()
    private let progressStack = UIStackView()
    private let progressSegments = (0..<3).map { _ in UIView() }
    private let showsBrand: Bool

    init(
        brandText: String?,
        stepIndicator: String,
        stepAccessibilityLabel: String,
        activeStep: Int,
        backAccessibilityLabel: String? = nil,
        continueTitle: String = JobSetupStrings.continueTitle
    ) {
        showsBrand = brandText != nil
        super.init(frame: .zero)

        configureAppearance(
            brandText: brandText,
            stepIndicator: stepIndicator,
            stepAccessibilityLabel: stepAccessibilityLabel,
            activeStep: activeStep,
            backAccessibilityLabel: backAccessibilityLabel,
            continueTitle: continueTitle
        )
        configureSubviews()
        configureLayout()
        configureInteractions()
        configureTraitChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setContinueEnabled(_ enabled: Bool) {
        continueButton.isEnabled = enabled

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.baseForegroundColor = enabled
            ? ShiftLedgerColors.accentPrimary
            : ShiftLedgerColors.textTertiary
        continueButton.configuration = configuration
    }

    var progressBottomAnchor: NSLayoutYAxisAnchor {
        progressStack.bottomAnchor
    }

    private func configureAppearance(
        brandText: String?,
        stepIndicator: String,
        stepAccessibilityLabel: String,
        activeStep: Int,
        backAccessibilityLabel: String?,
        continueTitle: String
    ) {
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        brandLabel.text = brandText
        brandLabel.font = ShiftLedgerTypography.caption
        brandLabel.textColor = ShiftLedgerColors.accentPrimary
        brandLabel.numberOfLines = 1
        brandLabel.adjustsFontForContentSizeCategory = true
        brandLabel.isAccessibilityElement = false

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = ShiftLedgerColors.textSecondary
        backButton.accessibilityLabel = backAccessibilityLabel
        backButton.accessibilityTraits = .button

        stepLabel.text = stepIndicator
        stepLabel.font = ShiftLedgerTypography.caption
        stepLabel.textColor = ShiftLedgerColors.textTertiary
        stepLabel.adjustsFontForContentSizeCategory = true
        stepLabel.accessibilityLabel = stepAccessibilityLabel

        progressStack.axis = .horizontal
        progressStack.alignment = .fill
        progressStack.distribution = .fillEqually
        progressStack.spacing = Layout.progressSegmentGap
        progressStack.isAccessibilityElement = false
        for (index, segment) in progressSegments.enumerated() {
            segment.backgroundColor = index < activeStep
                ? ShiftLedgerColors.accentPrimary
                : ShiftLedgerColors.separator
            segment.isAccessibilityElement = false
        }

        var continueConfiguration = UIButton.Configuration.plain()
        continueConfiguration.title = continueTitle
        continueConfiguration.image = UIImage(systemName: "arrow.right")
        continueConfiguration.imagePlacement = .trailing
        continueConfiguration.imagePadding = 8
        continueConfiguration.titleAlignment = .trailing
        continueConfiguration.baseForegroundColor = ShiftLedgerColors.textTertiary
        continueConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 0,
            bottom: 10,
            trailing: 0
        )
        continueConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var transformedAttributes = attributes
            transformedAttributes.font = ShiftLedgerTypography.button
            return transformedAttributes
        }
        continueButton.configuration = continueConfiguration
        continueButton.contentHorizontalAlignment = .trailing
        continueButton.titleLabel?.numberOfLines = 0
        continueButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }

    private func configureSubviews() {
        [
            scrollView,
            contentView,
            topRow,
            topRowSpacer,
            brandLabel,
            backButton,
            stepLabel,
            progressStack,
            continueButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.distribution = .fill
        if showsBrand {
            topRow.addArrangedSubview(brandLabel)
        } else {
            topRow.addArrangedSubview(backButton)
        }
        topRow.addArrangedSubview(topRowSpacer)
        topRow.addArrangedSubview(stepLabel)

        progressSegments.forEach(progressStack.addArrangedSubview)

        addSubview(scrollView)
        scrollView.addSubview(contentView)
        [topRow, progressStack].forEach(contentView.addSubview)
        addSubview(continueButton)

        topRowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stepLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        brandLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -Layout.scrollToActionGap),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.safeAreaTopInset),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            progressStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: Layout.headerToProgress),
            progressStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            progressStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            progressStack.heightAnchor.constraint(equalToConstant: 1),

            continueButton.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: Layout.contentInset),
            continueButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Layout.contentInset),
            continueButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Layout.actionBottomInset),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func configureInteractions() {
        guard showsBrand == false else {
            continueButton.addAction(UIAction { [weak self] _ in self?.onContinueTapped?() }, for: .primaryActionTriggered)
            return
        }

        backButton.addAction(UIAction { [weak self] _ in self?.onBackTapped?() }, for: .primaryActionTriggered)
        continueButton.addAction(UIAction { [weak self] _ in self?.onContinueTapped?() }, for: .primaryActionTriggered)
    }

    private func configureTraitChanges() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: JobSetupScaffoldView, _) in
            self.updateDynamicTypeLayout()
        }
        updateDynamicTypeLayout()
    }

    private func updateDynamicTypeLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        topRow.axis = usesAccessibilityLayout ? .vertical : .horizontal
        topRow.alignment = usesAccessibilityLayout ? .fill : .center
        topRow.spacing = usesAccessibilityLayout ? 8 : 12
        topRowSpacer.isHidden = usesAccessibilityLayout
        brandLabel.numberOfLines = usesAccessibilityLayout ? 0 : 1
        stepLabel.textAlignment = usesAccessibilityLayout ? .right : .natural

        guard var configuration = continueButton.configuration else {
            return
        }

        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        continueButton.configuration = configuration
    }

}
