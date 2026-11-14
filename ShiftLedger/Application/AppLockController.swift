import LocalAuthentication
import UIKit

@MainActor
protocol DeviceOwnerAuthenticating: AnyObject {
    var method: LABiometryType { get }
    func authenticate(reason: String) async throws -> Bool
    func invalidate()
}

@MainActor
final class DeviceOwnerAuthentication: DeviceOwnerAuthenticating {
    static let policy: LAPolicy = .deviceOwnerAuthentication
    private let context = LAContext()

    var method: LABiometryType {
        _ = context.canEvaluatePolicy(Self.policy, error: nil)
        return context.biometryType
    }

    func authenticate(reason: String) async throws -> Bool {
        var error: NSError?
        guard context.canEvaluatePolicy(Self.policy, error: &error) else {
            throw error ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await context.evaluatePolicy(Self.policy, localizedReason: reason)
    }

    func invalidate() { context.invalidate() }
}

@MainActor
final class AppLockController {
    private static let preferenceKey = "appLock.enabled"
    private let defaults: UserDefaults
    private let preferenceDomain: String
    private weak var window: UIWindow?
    private let makeAuthentication: () -> any DeviceOwnerAuthenticating
    private let shield = AppLockShieldView()
    private weak var protectedView: UIView?
    private var previousAccessibilityHidden = false
    private var active = false
    private var needsAutomaticAttempt = true
    private var attempt: (id: UUID, authentication: any DeviceOwnerAuthenticating, task: Task<Void, Never>)?
    private(set) var isLocked: Bool
    var onChange: (() -> Void)?

    init(window: UIWindow, defaults: UserDefaults = .standard,
         preferenceDomain: String = Bundle.main.bundleIdentifier ?? "com.alexeywestergaard.ShiftLedger",
         makeAuthentication: @escaping () -> any DeviceOwnerAuthenticating = { DeviceOwnerAuthentication() }) {
        self.window = window
        self.defaults = defaults
        self.preferenceDomain = preferenceDomain
        self.makeAuthentication = makeAuthentication
        isLocked = Self.readPreference(defaults, domain: preferenceDomain)
        shield.retry.addAction(UIAction { [weak self] _ in self?.retry() }, for: .primaryActionTriggered)
    }

    var isEnabled: Bool { Self.readPreference(defaults, domain: preferenceDomain) }

    private static func readPreference(_ defaults: UserDefaults, domain: String) -> Bool {
        // Authentication decisions must ignore volatile domains, including launch arguments.
        defaults.persistentDomain(forName: domain)?[preferenceKey] as? Bool ?? false
    }
    var isAuthenticating: Bool { attempt != nil }

    var methodTitle: String {
        let authentication = makeAuthentication()
        defer { authentication.invalidate() }
        switch authentication.method {
        case .faceID: return String(localized: "appLock.faceID")
        case .touchID: return String(localized: "appLock.touchID")
        default: return String(localized: "appLock.deviceOwner")
        }
    }

    func didBecomeActive() {
        active = true
        updateShield()
        if needsAutomaticAttempt && isLocked {
            needsAutomaticAttempt = false
            retry()
        }
    }

    func willResignActive() {
        active = false
        updateShield()
    }

    func didEnterBackground() {
        active = false
        isLocked = isEnabled
        needsAutomaticAttempt = true
        let cancelled = attempt
        attempt = nil
        cancelled?.authentication.invalidate()
        cancelled?.task.cancel()
        updateShield()
        onChange?()
    }

    func rootDidChange() { updateShield() }

    func retry() {
        guard isLocked else { return }
        authenticate { [weak self] success, message in
            guard let self else { return }
            if success { self.isLocked = false }
            self.shield.setMessage(message)
        }
    }

    func requestPreference(_ enabled: Bool, report: @escaping (String?) -> Void) {
        guard !isLocked, enabled != isEnabled else { return }
        authenticate { [weak self] success, message in
            guard let self else { return }
            if success { self.defaults.set(enabled, forKey: Self.preferenceKey) }
            report(message)
        }
    }

    private func authenticate(completion: @escaping (Bool, String?) -> Void) {
        guard active, attempt == nil else { return }
        let id = UUID()
        let authentication = makeAuthentication()
        let task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let success: Bool
            var message: String?
            do {
                success = try await authentication.authenticate(reason: String(localized: "appLock.reason"))
                if !success { message = String(localized: "appLock.failure") }
            } catch {
                success = false
                switch (error as? LAError)?.code {
                case .userCancel, .systemCancel, .appCancel:
                    break
                case .passcodeNotSet, .biometryNotAvailable, .notInteractive:
                    message = String(localized: "appLock.unavailable")
                default:
                    message = String(localized: "appLock.failure")
                }
            }
            guard let self, !Task.isCancelled, self.attempt?.id == id else { return }
            self.attempt = nil
            completion(success, message)
            self.updateShield()
            self.onChange?()
        }
        attempt = (id, authentication, task)
        shield.setMessage(nil)
        updateShield()
        onChange?()
    }

    private func updateShield() {
        guard let window else { return }
        let cover = isEnabled && (isLocked || !active)
        shield.retry.isEnabled = active && isLocked && !isAuthenticating
        if cover {
            let root = window.rootViewController?.view
            if protectedView !== root {
                protectedView?.accessibilityElementsHidden = previousAccessibilityHidden
                protectedView = root
                previousAccessibilityHidden = root?.accessibilityElementsHidden ?? false
            }
            root?.accessibilityElementsHidden = true
            if shield.superview == nil {
                shield.frame = window.bounds
                shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                window.addSubview(shield)
                UIAccessibility.post(notification: .screenChanged, argument: shield.heading)
            }
            window.bringSubviewToFront(shield)
        } else {
            protectedView?.accessibilityElementsHidden = previousAccessibilityHidden
            protectedView = nil
            if shield.superview != nil {
                shield.removeFromSuperview()
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
        }
    }
}

final class AppLockShieldView: UIView {
    let heading = UILabel()
    let retry = UIButton(type: .system)
    let message = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        accessibilityViewIsModal = true
        accessibilityIdentifier = "appLock.shield"
        isOpaque = true
        heading.text = "ShiftLedger"
        heading.accessibilityTraits.insert(.header)
        heading.font = .preferredFont(forTextStyle: .largeTitle)
        message.font = .preferredFont(forTextStyle: .body)
        for label in [heading, message] {
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        var button = UIButton.Configuration.filled()
        button.title = String(localized: "appLock.retry")
        retry.configuration = button
        retry.titleLabel?.adjustsFontForContentSizeCategory = true
        retry.accessibilityIdentifier = "appLock.retry"
        retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        setMessage(nil)

        let scroll = UIScrollView()
        let stack = UIStackView(arrangedSubviews: [heading, message, retry])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        addSubview(scroll)
        scroll.addSubview(stack)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            retry.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    func setMessage(_ text: String?) {
        message.text = text ?? String(localized: "appLock.locked")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
