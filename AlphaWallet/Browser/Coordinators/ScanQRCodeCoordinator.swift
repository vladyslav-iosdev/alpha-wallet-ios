// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import QRCodeReaderViewController

protocol ScanQRCodeCoordinatorDelegate: class {
    func didCancel(in coordinator: ScanQRCodeCoordinator)
    func didScan(result: String, in coordinator: ScanQRCodeCoordinator)
}

protocol ScanQRCodeCoordinatorResolutionDelegate: class {
    func coordinator(_ coordinator: ScanQRCodeCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction)
    func coordinator(_ coordinator: ScanQRCodeCoordinator, didResolveWalletConnectURL url: WCURL)
    func coordinator(_ coordinator: ScanQRCodeCoordinator, didResolveString value: String)
    func coordinator(_ coordinator: ScanQRCodeCoordinator, didResolveURL url: URL)
}

enum ScanQRCodeAction: CaseIterable {
    case sendToAddress
    case addCustomToken
    case watchWallet

    var title: String {
        switch self {
        case .sendToAddress:
            return R.string.localizable.qrCodeSendToAddressTitle()
        case .addCustomToken:
            return R.string.localizable.qrCodeAddCustomTokenTitle()
        case .watchWallet:
            return R.string.localizable.qrCodeWatchWalletTitle()
        }
    }
}

typealias WCURL = String

private enum ScanQRCodeResolution {
    case address(AlphaWallet.Address)
    case walletConnect(WCURL)
    case other(String)
    case url(URL)

    init(rawValue: String) {
        if let address = AlphaWallet.Address(string: rawValue) {
            self = .address(address)
        } else if rawValue.hasPrefix("wc:") {
            self = .walletConnect(rawValue)
        } else if let url = URL(string: rawValue) {
            self = .url(url)
        } else {
            self = .other(rawValue)
        }
    }
}

final class ScanQRCodeCoordinator: NSObject, Coordinator {
    private lazy var navigationController = UINavigationController(rootViewController: qrcodeController)
    private let parentNavigationController: UINavigationController
    private let shouldDissmissAfterScan: Bool
    //NOTE: We use flag to prevent camera view stuck when stop scan session, important for actions that can be canceled scan URL/WalletAddress
    private var skipResolvedCodes: Bool = false
    private lazy var reader = QRCodeReader(metadataObjectTypes: [AVMetadataObject.ObjectType.qr])
    private lazy var qrcodeController: QRCodeReaderViewController = {
        let controller = QRCodeReaderViewController(
            cancelButtonTitle: nil,
            codeReader: reader,
            startScanningAtLoad: true,
            showSwitchCameraButton: false,
            showTorchButton: true,
            chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos(),
            bordersColor: Colors.qrCodeRectBorders,
            messageText: R.string.localizable.qrCodeTitle(),
            torchTitle: R.string.localizable.light(),
            torchImage: R.image.light(),
            chooseFromPhotoLibraryButtonImage: R.image.browse()
        )
        controller.delegate = self
        controller.title = R.string.localizable.browserScanQRCodeTitle()
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismiss))
        controller.delegate = self

        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: ScanQRCodeCoordinatorDelegate?
    weak var resolutionDelegate: ScanQRCodeCoordinatorResolutionDelegate?

    init(navigationController: UINavigationController, shouldDissmissAfterScan: Bool = true) {
        self.parentNavigationController = navigationController
        self.shouldDissmissAfterScan = shouldDissmissAfterScan
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        parentNavigationController.present(navigationController, animated: true)
    }

    @objc func dismiss() {
        stopScannerAndDissmiss {
            self.delegate?.didCancel(in: self)
        }
    }

    func resolveScanResult(_ rawValue: String) {
        guard let delegate = resolutionDelegate else { return }

        switch ScanQRCodeResolution(rawValue: rawValue) {
        case .address(let address):
            showDidScanWalletAddress(completion: { action in
                self.stopScannerAndDissmiss {
                    delegate.coordinator(self, didResolveAddress: address, action: action)
                }
            }, cancelCompletion: {
                self.skipResolvedCodes = false
            })
        case .other(let value):
            self.stopScannerAndDissmiss {
                delegate.coordinator(self, didResolveString: value)
            }
        case .walletConnect(let url):
            self.stopScannerAndDissmiss {
                delegate.coordinator(self, didResolveWalletConnectURL: url)
            }
        case .url(let url):
            showOpenURL(completion: {
                self.stopScannerAndDissmiss {
                    delegate.coordinator(self, didResolveURL: url)
                }
            }, cancelCompletion: {
                //NOTE: we need to reset flat to false to make shure that next detected QR code will be handled
                self.skipResolvedCodes = false
            })
        }
    }

    private func showDidScanWalletAddress(completion: @escaping (ScanQRCodeAction) -> Void, cancelCompletion: @escaping () -> Void) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: preferredStyle)

        for action in ScanQRCodeAction.allCases {
            let alertAction = UIAlertAction(title: action.title, style: .default) { _ in
                completion(action)
            }

            controller.addAction(alertAction)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            cancelCompletion()
        }

        controller.addAction(cancelAction)

        controller.makePresentationFullScreenForiOS13Migration()

        navigationController.present(controller, animated: true)
    }

    private func showOpenURL(completion: @escaping () -> Void, cancelCompletion: @escaping () -> Void) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: preferredStyle)

        let alertAction = UIAlertAction(title: R.string.localizable.qrCodeOpenInBrowserTitle(), style: .default) { _ in
            completion()
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            cancelCompletion()
        }

        controller.addAction(alertAction)
        controller.addAction(cancelAction)

        controller.makePresentationFullScreenForiOS13Migration()

        navigationController.present(controller, animated: true)
    }

    private func stopScannerAndDissmiss(completion: @escaping () -> Void) {
        reader.stopScanning()

        navigationController.dismiss(animated: true, completion: completion)
    }
}

extension ScanQRCodeCoordinator: QRCodeReaderDelegate {

    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        stopScannerAndDissmiss {
            self.delegate?.didCancel(in: self)
        }
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        guard !skipResolvedCodes else { return }

        if shouldDissmissAfterScan {
            stopScannerAndDissmiss {
                self.delegate?.didScan(result: result, in: self)
            }
        } else {
            skipResolvedCodes = true
            delegate?.didScan(result: result, in: self)
        }
    }
}

extension UIBarButtonItem {
    
    static func cancelBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .cancel, target: target, action: selector)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }
}
