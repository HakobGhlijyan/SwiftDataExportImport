//
//  ContentView.swift
//  SwiftDataExportImport
//
//  Created by Hakob Ghlijyan on 12/17/24.
//

import SwiftUI
import SwiftData
import CryptoKit

struct ContentView: View {
    @Query(sort: [.init(\Transaction.transactionDate, order: .reverse)], animation: .snappy) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    //View Properties
    @State private var showAlertTF: Bool = false
    @State private var keyTF: String = ""
    
    //Exporter Properties
    @State private var exportItem: TransactionTransferable?
    @State private var showFileExporter: Bool = false
    
    //Importer Properties
    @State private var showFileImporter: Bool = false
    @State private var importedURL: URL?
        
    var body: some View {
        NavigationStack {
            List(transactions) {
                Text($0.transactionName)
            }
            .navigationTitle("Tramsations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAlertTF.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter.toggle()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        //Dummy Data
                        let transaction = Transaction(
                            transactionName: "Dummy Transaction \(Date.now)",
                            transactionDate: .now,
                            transactionAmount: 1299.99,
                            transactionCategoty: .expense
                        )
                        modelContext.insert(transaction)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .alert("Enter Key", isPresented: $showAlertTF) {
            TextField("Enter Key", text: $keyTF)
                .autocorrectionDisabled()
            
            Button("Cancel", role: .cancel) {
                keyTF = ""
                importedURL = nil
            }
            
            Button(importedURL != nil ? "Import" : "Export") {
                if importedURL != nil {
                    importData()
                } else {
                    exportData()
                }
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            item: exportItem,
            contentTypes: [.data],
            defaultFilename: "Transactions",
            onCompletion: { result in
                switch result {
                case .success:
                    print("Success")
                case .failure(let error):
                    print("Failure")
                    print(error.localizedDescription)
                }
                exportItem = nil
            },
            onCancellation: {
                exportItem = nil
            }
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            onCompletion: { result in
                switch result {
                case .success(let url):
                    importedURL = url
                    showAlertTF.toggle()
                case .failure(let error):
                    print("Failure")
                    print(error.localizedDescription)
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}

extension ContentView {
    private func exportData() {
        Task.detached(priority: .background) {
            do {
                let container = try ModelContainer(for: Transaction.self)
                let context = ModelContext(container)
                let descriptor = FetchDescriptor(sortBy: [.init(\Transaction.transactionDate, order: .reverse)])
                let allObjects = try context.fetch(descriptor)
                let exportItem = await TransactionTransferable(transactions: allObjects, key: keyTF)
                await MainActor.run {
                    self.exportItem = exportItem
                    showFileExporter = true
                    keyTF = ""
                }
            } catch {
                print(error.localizedDescription)
                await MainActor.run {
                    keyTF = ""
                }
            }
        }
    }
    
    private func importData() {
        guard let url = importedURL else { return }
        Task(priority: .background) {
            do {
                guard url.startAccessingSecurityScopedResource()  else { return }
                let container = try ModelContainer(for: Transaction.self)
                let context = ModelContext(container)
                
                let encryptedData = try Data(contentsOf: url)
                let decryptedData = try AES.GCM.open(.init(combined: encryptedData), using: .key(keyTF))
                
                let allTransactions = try JSONDecoder().decode([Transaction].self, from: decryptedData)

                for transaction in allTransactions {
                    context.insert(transaction)
                }
                try context.save()
                keyTF = ""
                
                url.stopAccessingSecurityScopedResource()
            } catch {
                print(error.localizedDescription)
                await MainActor.run {
                    keyTF = ""
                }
            }
        }
    }
}
