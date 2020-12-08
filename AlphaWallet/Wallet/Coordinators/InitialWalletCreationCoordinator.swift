// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol InitialWalletCreationCoordinatorDelegate: class {
    func didCancel(in coordinator: InitialWalletCreationCoordinator)
    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator)
}

class InitialWalletCreationCoordinator: Coordinator {
    private let keystore: Keystore
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator?

    lazy var navigationControllerToPresent: UINavigationController = {
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.isTranslucent = false
        navigationController.makePresentationFullScreenForiOS13Migration()

        return navigationController
    }()

    private lazy var controller: CreateInitialWalletViewController = {
        let controller = CreateInitialWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        controller.delegate = self
        controller.configure()

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: InitialWalletCreationCoordinatorDelegate?

    init(
        config: Config,
        navigationController: UINavigationController,
        keystore: Keystore,
        analyticsCoordinator: AnalyticsCoordinator?
    ) {

        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        navigationController.present(navigationControllerToPresent, animated: true)
    }

    private func showCreateWallet(entryPoint: WalletEntryPoint) {
        let coordinator = WalletCoordinator(config: config, navigationController: navigationControllerToPresent, keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start(entryPoint)

        addCoordinator(coordinator)
    }
}

extension InitialWalletCreationCoordinator: CreateInitialWalletViewControllerDelegate {

    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController) {
        showCreateWallet(entryPoint: .createInstantWallet)
    }

    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController) {
        showCreateWallet(entryPoint: .watchWallet(address: nil))
    }

    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController) {
        showCreateWallet(entryPoint: .importWallet)
    }
}

extension InitialWalletCreationCoordinator: WalletCoordinatorDelegate {

    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        delegate?.didAddAccount(account, in: self)

        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) { 
        coordinator.navigationController.popViewController(animated: true)

        removeCoordinator(coordinator)
    }
}
