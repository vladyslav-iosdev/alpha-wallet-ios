// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import QRCodeReaderViewController

protocol ScanQRCodeCoordinatorDelegate: class {
    func didCancel(in coordinator: ScanQRCodeCoordinator)
    func didScan(result: String, in coordinator: ScanQRCodeCoordinator)
}

final class ScanQRCodeCoordinator: NSObject, Coordinator {
    var coordinators: [Coordinator] = []
    weak var delegate: ScanQRCodeCoordinatorDelegate?

    lazy var qrcodeController: QRCodeReaderViewController = {
        let reader = QRCodeReader(metadataObjectTypes: [AVMetadataObject.ObjectType.qr])

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
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.backWhite(), style: .plain, target: self, action: #selector(dismiss))
        controller.delegate = self
        return controller
    }()
    
    let navigationController: NavigationController
    
    init(navigationController: NavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.viewControllers = [qrcodeController]
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
        delegate?.didCancel(in: self)
    }
}

extension ScanQRCodeCoordinator: QRCodeReaderDelegate {
    
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true)
        delegate?.didCancel(in: self)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        delegate?.didScan(result: result, in: self)
        reader.dismiss(animated: true)
    }
}
