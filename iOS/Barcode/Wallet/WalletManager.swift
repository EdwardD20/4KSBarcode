//
//  Barcode/Wallet/WalletManager.swift
//
//  Created by Ed Danley on 4/22/26.
//

import PassKit
import UIKit

final class WalletManager {

    static let shared = WalletManager()

    private init() { } // init

    func presentPass(from data: Data, in viewController: UIViewController) throws {
        let pass = try PKPass(data: data)

        guard let addVC = PKAddPassesViewController(pass: pass) else {
            throw NSError(domain: "WalletError", code: 1)
        }

        viewController.present(addVC, animated: true)
    } // func presentPass

} // class WalletManager
