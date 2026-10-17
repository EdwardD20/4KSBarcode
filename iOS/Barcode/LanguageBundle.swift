//
//  Barcode/LanguageBundle.swift
//
//  Created by Ed Danley on 4/24/26.
//

import Foundation

// Create a helper to load from the correct .lproj bundle
class LanguageBundle {
    static var current: Bundle = Bundle.main
    
    static func set(_ languageCode: String) {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            current = bundle
        } else {
            current = Bundle.main
        } // if let path
    } // func set
} // class LanguageBundle

extension String {
    func localized() -> String {
        LanguageBundle.current.localizedString(forKey: self, value: self, table: nil)
    } // func localized
} // extension String
