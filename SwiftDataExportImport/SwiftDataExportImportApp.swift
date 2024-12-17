//
//  SwiftDataExportImportApp.swift
//  SwiftDataExportImport
//
//  Created by Hakob Ghlijyan on 12/17/24.
//

import SwiftUI

@main
struct SwiftDataExportImportApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Transaction.self)
        }
    }
}
