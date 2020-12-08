// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol WalletCoordinatorDelegate: class {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator)
    func didCancel(in coordinator: WalletCoordinator)
}

class WalletCoordinator: Coordinator {
    private let config: Config 
    private var keystore: Keystore
    private weak var importWalletViewController: ImportWalletViewController?
    private let analyticsCoordinator: AnalyticsCoordinator?
    private lazy var backBarButton = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))

    let navigationController: UINavigationController
    weak var delegate: WalletCoordinatorDelegate?
    var coordinators: [Coordinator] = []

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

    func start(_ entryPoint: WalletEntryPoint) {
        switch entryPoint {
        case .importWallet:
            let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = backBarButton

            importWalletViewController = controller

            navigationController.pushViewController(controller, animated: true)
        case .watchWallet(let address):
            let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = backBarButton
            controller.watchAddressTextField.value = address?.eip55String ?? ""
            controller.showWatchTab()
            importWalletViewController = controller

            navigationController.pushViewController(controller, animated: true)
        case .createInstantWallet:
            createInstantWallet()
        }
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    func createInitialWalletIfMissing() {
        if !keystore.hasWallets {
            switch keystore.createAccount() {
            case .success(let account):
                keystore.recentlyUsedWallet = Wallet(type: WalletType.real(account))
            case .failure:
                //TODO handle initial wallet creation error. App can't be used!
                break
            }
        }
    }

    //TODO Rename this is create in both settings and new install
    func createInstantWallet() {
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        keystore.createAccount { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case .success(let account):
                let wallet = Wallet(type: WalletType.real(account))
                //Bit of delay to wait for the UI animation to almost finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    WhereIsWalletAddressFoundOverlayView.show()
                }
                strongSelf.delegate?.didFinish(with: wallet, in: strongSelf)
            case .failure(let error):
                //TODO this wouldn't work since navigationController isn't shown anymore
                strongSelf.navigationController.displayError(error: error)
            }
            strongSelf.navigationController.hideLoading(animated: false)
        }
    }

    @objc private func dismiss() {
        guard let delegate = self.delegate else { return }

        delegate.didCancel(in: self)
    }

    //TODO Rename this is import in both settings and new install
    func didCreateAccount(account: Wallet) {
        guard let delegate = delegate else { return }

        delegate.didFinish(with: account, in: self)
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SuccessOverlayView.show()
        }
    }
}

extension WalletCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)

        importWalletViewController?.didScanQRCode(result)
    }

}

extension WalletCoordinator: ImportWalletViewControllerDelegate {

    func openQRCode(in controller: ImportWalletViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }
        let coordinator = ScanQRCodeCoordinator(navigationController: navigationController, account: keystore.recentlyUsedWallet, server: config.server)
        coordinator.delegate = self

        addCoordinator(coordinator)
        coordinator.start()
    }

    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address)
        didCreateAccount(account: account)
    }
}
