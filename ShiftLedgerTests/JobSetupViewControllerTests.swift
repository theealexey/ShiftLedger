import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct JobSetupViewControllerTests {
    @Test("Step 1 restores navigation bar state across its lifecycle")
    func navigationBarVisibilityFollowsLifecycle() {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: "USD",
            initialTimeZoneIdentifier: "Europe/Stockholm"
        )
        let viewController = JobSetupViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        navigationController.loadViewIfNeeded()

        viewController.viewWillAppear(false)
        #expect(navigationController.isNavigationBarHidden)

        viewController.viewWillDisappear(false)
        #expect(navigationController.isNavigationBarHidden == false)

        viewController.viewWillAppear(false)
        #expect(navigationController.isNavigationBarHidden)
    }
}
