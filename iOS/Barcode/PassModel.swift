//
//  Barcode/PassModel.swift
//
//  Created by Ed Danley on 4/24/26.
//


import Foundation
import UIKit
import SwiftUI
import Combine

final class PassModel: ObservableObject {
    @Published var clientId: String?
    // logo and icon will use bundled images if available
    @Published var Icon: UIImage?
    @Published var Logo: UIImage?

    private static let clientKey = "pass_model_clientId"

    static func load() -> PassModel {
        let m = PassModel()
        m.clientId = UserDefaults.standard.string(forKey: clientKey)

        // Load bundled images (fall back to nil)
        if m.Logo == nil {
            if let path = Bundle.main.path(forResource: "Logo", ofType: "png"),
               let img = UIImage(contentsOfFile: path) {
                m.Logo = img
            } else if let img = UIImage(named: "Logo") {
                m.Logo = img
            }
        }
        if m.Icon == nil {
            if let path = Bundle.main.path(forResource: "Icon", ofType: "png"),
               let img = UIImage(contentsOfFile: path) {
                m.Icon = img
            } else if let img = UIImage(named: "Icon") {
                m.Icon = img
            }
        }

        return m
    }

    func save() {
        UserDefaults.standard.setValue(clientId, forKey: Self.clientKey)
    }
}
