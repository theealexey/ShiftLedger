import CoreData
import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct SceneDelegateStartupTests {
    @Test("Startup failure presents a localized retry alert")
    func startupFailurePresentsLocalizedError() async throws {
        var loaderCallCount = 0
        let loader: @MainActor () async throws -> CoreDataStack = {
            loaderCallCount += 1
            throw SceneDelegateTestError.loadFailed
        }
        let sceneDelegate = SceneDelegate(loadCoreDataStack: loader)
        let window = makeWindow()
        sceneDelegate.window = window
        defer { tearDown(window, sceneDelegate: sceneDelegate) }

        let task = sceneDelegate.startStartup()
        await task.value

        #expect(loaderCallCount == 1)
        let loadingViewController = try #require(window.rootViewController)
        let alert = try #require(
            loadingViewController.presentedViewController as? UIAlertController
        )
        #expect(alert.title == String(
            localized: "application.startupError.title",
            table: "Localizable"
        ))
        #expect(alert.message == String(
            localized: "application.startupError.message",
            table: "Localizable"
        ))
        #expect(alert.actions.count == 1)
        #expect(alert.actions.first?.title == String(
            localized: "application.startupError.retry",
            table: "Localizable"
        ))
    }

    @Test("Retry reruns startup and installs onboarding")
    func failedStartupCanRetrySuccessfully() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        var loaderCallCount = 0
        let loader: @MainActor () async throws -> CoreDataStack = {
            loaderCallCount += 1
            if loaderCallCount == 1 {
                throw SceneDelegateTestError.loadFailed
            }
            return stack
        }
        let sceneDelegate = SceneDelegate(loadCoreDataStack: loader)
        let window = makeWindow()
        sceneDelegate.window = window
        defer { tearDown(window, sceneDelegate: sceneDelegate) }

        let firstTask = sceneDelegate.startStartup()
        await firstTask.value
        #expect(loaderCallCount == 1)
        let failedRoot = try #require(window.rootViewController)
        #expect(failedRoot.presentedViewController is UIAlertController)

        let retryTask = sceneDelegate.startStartup()
        await retryTask.value

        #expect(loaderCallCount == 2)
        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        #expect(navigationController.viewControllers.first is JobSetupViewController)
        #expect(navigationController.presentedViewController == nil)
    }

    @Test("Cancelling suspended startup leaves the loading root")
    func cancellingSuspendedStartupDoesNotInstallRootOrError() async throws {
        var enteredContinuation: CheckedContinuation<Void, Never>?
        var cancellationObserved = false
        let loader: @MainActor () async throws -> CoreDataStack = {
            enteredContinuation?.resume()
            enteredContinuation = nil

            do {
                try await Task.sleep(for: .seconds(60))
                throw SceneDelegateTestError.unexpectedLoaderReturn
            } catch is CancellationError {
                cancellationObserved = true
                throw CancellationError()
            }
        }
        let sceneDelegate = SceneDelegate(loadCoreDataStack: loader)
        let window = makeWindow()
        sceneDelegate.window = window
        defer { tearDown(window, sceneDelegate: sceneDelegate) }

        let task = sceneDelegate.startStartup()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            enteredContinuation = continuation
        }
        let loadingViewController = try #require(window.rootViewController)

        sceneDelegate.cancelStartup()
        await task.value

        #expect(cancellationObserved)
        #expect(window.rootViewController === loadingViewController)
        #expect(loadingViewController.presentedViewController == nil)
    }

    private func makeWindow() -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    private func tearDown(_ window: UIWindow, sceneDelegate: SceneDelegate) {
        sceneDelegate.cancelStartup()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerStartupTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func removeTemporaryStoreDirectory(for storeURL: URL, stack: CoreDataStack) {
        let context = stack.viewContext
        context.reset()
        if let coordinator = context.persistentStoreCoordinator {
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }
}

private enum SceneDelegateTestError: Error {
    case loadFailed
    case unexpectedLoaderReturn
}
