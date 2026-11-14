import LocalAuthentication
import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct AppLockTests {
    @Test func preferenceRequiresAuthenticationAndSurvivesRecreation() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        #expect(!fixture.lock.isEnabled)
        fixture.lock.didBecomeActive()
        fixture.lock.requestPreference(true) { _ in }
        await fixture.authentication.complete(.failure(LAError(.userCancel)))
        await fixture.waitForCompletion()
        #expect(!fixture.lock.isEnabled)

        fixture.lock.requestPreference(true) { _ in }
        await fixture.authentication.complete(.success(true))
        await fixture.waitForCompletion()
        #expect(fixture.lock.isEnabled)
        let relaunched = AppLockController(window: fixture.window, defaults: fixture.defaults, preferenceDomain: fixture.name)
        #expect(relaunched.isLocked)

        fixture.lock.requestPreference(false) { _ in }
        await fixture.authentication.complete(.failure(LAError(.userCancel)))
        await fixture.waitForCompletion()
        #expect(fixture.lock.isEnabled)
        fixture.lock.requestPreference(false) { _ in }
        await fixture.authentication.complete(.success(true))
        await fixture.waitForCompletion()
        #expect(!fixture.lock.isEnabled)
    }

    @Test func backgroundInvalidatesAttemptAndKeepsContentCovered() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.defaults.set(true, forKey: "appLock.enabled")
        fixture.lock.didEnterBackground()
        #expect(DeviceOwnerAuthentication.policy == .deviceOwnerAuthentication)
        #expect(fixture.lock.isLocked)
        fixture.lock.rootDidChange()
        let shield = try #require(fixture.window.subviews.last)
        #expect(shield.accessibilityIdentifier == "appLock.shield")
        #expect(shield.accessibilityViewIsModal)
        #expect(shield.isUserInteractionEnabled)
        #expect(fixture.window.rootViewController?.view.accessibilityElementsHidden == true)

        fixture.lock.didBecomeActive()
        fixture.lock.retry()
        await fixture.authentication.waitForRequest()
        #expect(fixture.authentication.requests == 1)
        fixture.lock.willResignActive()
        fixture.lock.didEnterBackground()
        #expect(fixture.authentication.invalidations == 1)
        await fixture.authentication.complete(.success(true))
        #expect(fixture.lock.isLocked)

        fixture.lock.didBecomeActive()
        await fixture.authentication.complete(.failure(LAError(.authenticationFailed)))
        await fixture.waitForCompletion()
        #expect(fixture.lock.isLocked)
        #expect(shield.superview === fixture.window)

        fixture.lock.retry()
        await fixture.authentication.complete(.success(true))
        await fixture.waitForCompletion()
        #expect(!fixture.lock.isLocked)
        #expect(shield.superview == nil)
        #expect(fixture.window.rootViewController?.view.accessibilityElementsHidden == false)
    }

    @Test func argumentDomainCannotOverrideSavedProtection() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let argumentDomain = fixture.defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { fixture.defaults.setVolatileDomain(argumentDomain, forName: UserDefaults.argumentDomain) }

        fixture.defaults.set(true, forKey: "appLock.enabled")
        fixture.defaults.setVolatileDomain(["appLock.enabled": false], forName: UserDefaults.argumentDomain)
        #expect(!fixture.defaults.bool(forKey: "appLock.enabled"))
        let relaunched = AppLockController(window: fixture.window, defaults: fixture.defaults,
                                           preferenceDomain: fixture.name)
        #expect(relaunched.isEnabled)
        #expect(relaunched.isLocked)
    }

    @Test func transientInactivityKeepsSuccessCoveredUntilActive() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.defaults.set(true, forKey: "appLock.enabled")
        fixture.lock.didEnterBackground()
        fixture.lock.didBecomeActive()
        fixture.lock.didBecomeActive()
        await fixture.authentication.waitForRequest()
        fixture.lock.willResignActive()
        await fixture.authentication.complete(.success(true))
        await fixture.waitForCompletion()
        #expect(!fixture.lock.isLocked)
        #expect(fixture.authentication.invalidations == 0)
        #expect(fixture.window.subviews.last?.accessibilityIdentifier == "appLock.shield")
        fixture.lock.didBecomeActive()
        fixture.lock.didBecomeActive()
        #expect(fixture.authentication.requests == 1)
        #expect(fixture.window.rootViewController?.view.accessibilityElementsHidden == false)
    }

    @Test func backgroundCancellationAndForegroundCancellationRequireExplicitRetry() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.authentication.completeOnInvalidation = true
        fixture.defaults.set(true, forKey: "appLock.enabled")
        fixture.lock.didEnterBackground()
        fixture.lock.didBecomeActive()
        await fixture.authentication.waitForRequest()
        fixture.lock.didEnterBackground()
        #expect(fixture.authentication.invalidations == 1)
        fixture.lock.didBecomeActive()
        fixture.lock.didBecomeActive()
        await fixture.authentication.complete(.failure(LAError(.userCancel)))
        await fixture.waitForCompletion()
        fixture.lock.didBecomeActive()
        #expect(fixture.lock.isLocked)
        #expect(fixture.authentication.requests == 2)
        let shield = try #require(fixture.window.subviews.last as? AppLockShieldView)
        #expect(shield.retry.isEnabled)
        shield.retry.sendActions(for: .primaryActionTriggered)
        await fixture.authentication.complete(.success(true))
        await fixture.waitForCompletion()
        #expect(fixture.authentication.requests == 3)
        #expect(!fixture.lock.isLocked)
    }

    @Test func settingsSwitchTracksCommittedPreferenceAndRejectsDuplicates() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.lock.didBecomeActive()
        let settings = SettingsViewController(model: .init(currency: "EUR", timeZone: "UTC",
                                                           version: nil, rateActionTitle: "Rates"),
                                              appLock: fixture.lock)
        settings.loadViewIfNeeded()
        let control = try #require(findSwitch(in: settings.view))
        #expect(control.accessibilityIdentifier == "settings.appLock")
        for (requested, result, persisted) in [
            (true, Result<Bool, any Error>.failure(LAError(.userCancel)), false),
            (true, .success(true), true),
            (false, .failure(LAError(.authenticationFailed)), true),
            (false, .failure(LAError(.userCancel)), true),
            (false, .success(true), false)
        ] {
            control.isOn = requested
            control.sendActions(for: .valueChanged)
            #expect(control.isOn != requested)
            #expect(!control.isEnabled)
            let previousRequests = fixture.authentication.requests
            fixture.lock.requestPreference(requested) { _ in Issue.record("Duplicate request completed") }
            await fixture.authentication.complete(result)
            await fixture.waitForCompletion()
            #expect(fixture.authentication.requests == previousRequests + 1)
            #expect(fixture.lock.isEnabled == persisted)
            #expect(control.isOn == persisted)
            #expect(control.isEnabled)
        }
    }

    @Test func russianShieldFitsNarrowAccessibilityWidth() {
        let parent = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 380))
        window.rootViewController = parent
        window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        parent.view.frame = window.bounds
        let shield = AppLockShieldView()
        shield.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        shield.frame = parent.view.bounds
        shield.setMessage("Проверка владельца недоступна. Установите код-пароль устройства в настройках и повторите попытку.")
        var configuration = shield.retry.configuration
        configuration?.title = "Разблокировать"
        shield.retry.configuration = configuration
        parent.view.addSubview(shield)
        window.layoutIfNeeded()
        shield.layoutIfNeeded()

        #expect(shield.traitCollection.preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge)
        for view in [shield.heading, shield.message, shield.retry] {
            let frame = view.convert(view.bounds, to: shield)
            #expect(frame.minX >= 24)
            #expect(frame.maxX <= 296)
            #expect(frame.width > 0)
        }
        #expect(shield.message.bounds.height > shield.message.font.lineHeight)
        #expect(shield.retry.bounds.height >= 44)
    }

    private func findSwitch(in view: UIView) -> UISwitch? {
        if let control = view as? UISwitch { return control }
        return view.subviews.lazy.compactMap { findSwitch(in: $0) }.first
    }

    @MainActor
    private final class Fixture {
        let name = "AppLockTests.\(UUID())"
        let defaults: UserDefaults
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let authentication = AuthenticationStub()
        let lock: AppLockController

        init() throws {
            defaults = try #require(UserDefaults(suiteName: name))
            let authentication = self.authentication
            window.rootViewController = UIViewController()
            window.rootViewController?.loadViewIfNeeded()
            lock = AppLockController(window: window, defaults: defaults, preferenceDomain: name, makeAuthentication: { authentication })
        }

        func cleanUp() { defaults.removePersistentDomain(forName: name) }

        func waitForCompletion() async {
            for _ in 0..<100 where lock.isAuthenticating { await Task.yield() }
            #expect(!lock.isAuthenticating)
        }
    }

    @MainActor
    private final class AuthenticationStub: DeviceOwnerAuthenticating {
        var method: LABiometryType { .faceID }
        private(set) var requests = 0
        private(set) var invalidations = 0
        var completeOnInvalidation = false
        private var continuation: CheckedContinuation<Bool, any Error>?

        func authenticate(reason: String) async throws -> Bool {
            requests += 1
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }

        func invalidate() {
            invalidations += 1
            guard completeOnInvalidation else { return }
            let pending = continuation
            continuation = nil
            pending?.resume(throwing: LAError(.appCancel))
        }

        func waitForRequest() async {
            for _ in 0..<100 where continuation == nil { await Task.yield() }
            #expect(continuation != nil)
        }

        func complete(_ result: Result<Bool, any Error>) async {
            await waitForRequest()
            let pending = continuation
            continuation = nil
            pending?.resume(with: result)
            await Task.yield()
        }
    }
}
