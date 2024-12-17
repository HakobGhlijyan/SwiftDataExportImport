//
//  Data+Extension.swift
//  SwiftDataExportImport
//
//  Created by Hakob Ghlijyan on 12/17/24.
//

import SwiftUI
import CryptoKit

extension SymmetricKey {
    static func key(_ value: String) -> SymmetricKey {
        let keyData = value.data(using: .utf8)!
        let sha256 = SHA256.hash(data: keyData)
        return .init(data: sha256)
    }
}
