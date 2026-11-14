import UIKit

enum SettingsStrings {
    static var title: String { String(localized: "settings.title") }
    static var job: String { String(localized: "settings.job") }
    static var rates: String { String(localized: "settings.rates") }
    static var archive: String { String(localized: "settings.archive") }
    static var archivedJobs: String { String(localized: "archive.jobs.title") }
    static var app: String { String(localized: "settings.app") }
    static var version: String { String(localized: "settings.version") }
}

struct SettingsPresentation {
    let currency: String
    let timeZone: String
    let version: String?
    let rateActionTitle: String
}

final class SettingsViewController: UIViewController {
    var onArchivedJobs: (() -> Void)?
    var onRates: (() -> Void)?
    var onWillAppear: (() -> Void)?
    private let model: SettingsPresentation

    init(model: SettingsPresentation) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let settingsView = SettingsView(model: model)
        settingsView.ratesButton.addAction(UIAction { [weak self] _ in
            self?.onRates?()
        }, for: .primaryActionTriggered)
        settingsView.archivedJobsButton.addAction(UIAction { [weak self] _ in
            self?.onArchivedJobs?()
        }, for: .primaryActionTriggered)
        view = settingsView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = SettingsStrings.title
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onWillAppear?()
    }

    func updateRatesTitle(_ title: String) {
        guard let settingsView = view as? SettingsView,
              var configuration = settingsView.ratesButton.configuration else { return }
        configuration.title = title
        settingsView.ratesButton.configuration = configuration
    }
}

private final class SettingsView: UIView {
    let ratesButton = UIButton(type: .system)
    let archivedJobsButton = UIButton(type: .system)
    private let sections = UIStackView()

    init(model: SettingsPresentation) {
        super.init(frame: .zero)
        backgroundColor = ShiftLedgerColors.backgroundPrimary
        accessibilityIdentifier = "settings.screen"
        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "settings.scroll"
        addSubview(scroll)
        scroll.addSubview(sections)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        sections.translatesAutoresizingMaskIntoConstraints = false
        sections.axis = .vertical
        sections.spacing = 24
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            sections.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            sections.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            sections.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            sections.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            sections.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        addSection(SettingsStrings.job, rows: [
            info(String(localized: "jobSetup.review.currency"), value: model.currency, id: "currency"),
            info(String(localized: "jobSetup.review.timeZone"), value: model.timeZone, id: "timeZone")
        ])

        configureNavigationRow(ratesButton, title: model.rateActionTitle, identifier: "settings.rates")
        addSection(SettingsStrings.rates, rows: [ratesButton])
        configureNavigationRow(archivedJobsButton, title: SettingsStrings.archivedJobs, identifier: "settings.archivedJobs")
        addSection(SettingsStrings.archive, rows: [archivedJobsButton])

        if let version = model.version, !version.isEmpty {
            addSection(SettingsStrings.app, rows: [
                info(SettingsStrings.version, value: version, id: "version")
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func configureNavigationRow(_ button: UIButton, title: String, identifier: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: "chevron.forward")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        configuration.titleAlignment = .leading
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        configuration.baseForegroundColor = ShiftLedgerColors.accentPrimary
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityIdentifier = identifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func addSection(_ title: String, rows: [UIView]) {
        let heading = label(title, style: .headline, color: ShiftLedgerColors.textPrimary)
        heading.accessibilityTraits.insert(.header)
        let card = UIStackView(arrangedSubviews: rows)
        card.axis = .vertical
        card.spacing = 16
        card.backgroundColor = ShiftLedgerColors.surfacePrimary
        card.layer.cornerRadius = 16
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        let group = UIStackView(arrangedSubviews: [heading, card])
        group.axis = .vertical
        group.spacing = 8
        sections.addArrangedSubview(group)
    }

    private func info(_ title: String, value: String, id: String) -> UIView {
        let caption = label(title, style: .subheadline, color: ShiftLedgerColors.textSecondary)
        let detail = label(value, style: .body, color: ShiftLedgerColors.textPrimary)
        let row = UIStackView(arrangedSubviews: [caption, detail])
        row.axis = .vertical
        row.spacing = 4
        row.isAccessibilityElement = true
        row.accessibilityIdentifier = "settings.\(id)"
        row.accessibilityLabel = title
        row.accessibilityValue = value
        row.accessibilityTraits = .staticText
        return row
    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }
}
