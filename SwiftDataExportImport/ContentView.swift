//
//  ContentView.swift
//  SwiftDataExportImport
//
//  Created by Hakob Ghlijyan on 12/17/24.
//

import SwiftUI
import SwiftData
import CryptoKit

//MARK: - MODEL
@Model
class Transaction: Codable {
    var transactionName: String
    var transactionDate: Date
    var transactionAmount: Double
    var transactionCategoty: TransactionCategory
    
    init(transactionName: String, transactionDate: Date, transactionAmount: Double, transactionCategoty: TransactionCategory) {
        self.transactionName = transactionName
        self.transactionDate = transactionDate
        self.transactionAmount = transactionAmount
        self.transactionCategoty = transactionCategoty
    }
    
    enum CodingKeys: CodingKey {
        case transactionName
        case transactionDate
        case transactionAmount
        case transactionCategoty
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transactionName = try container.decode(String.self, forKey: .transactionName)
        transactionDate = try container.decode(Date.self, forKey: .transactionDate)
        transactionAmount = try container.decode(Double.self, forKey: .transactionAmount)
        transactionCategoty = try container.decode(TransactionCategory.self, forKey: .transactionCategoty)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transactionName, forKey: .transactionName)
        try container.encode(transactionDate, forKey: .transactionDate)
        try container.encode(transactionAmount, forKey: .transactionAmount)
        try container .encode(transactionCategoty, forKey: .transactionCategoty)
    }
}

//MARK: - Transaction Transferable
struct TransactionTransferable: Transferable {
    var transactions: [Transaction]
    var key: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { dataTr in
            //1: - encode
            let data = try JSONEncoder().encode(dataTr.transactions)
            //2: - crypdo data for using key
            guard let encryptedData = try AES.GCM.seal(data, using: .key(dataTr.key)).combined else {
                throw EncryptionError.encryptionFailed
                //Комбинированный элемент, состоящий из одноразового номера, зашифрованных данных и тега аутентификации.
                //Объединенное представление доступно только в том случае, если размер файла AES.GCM.Nonce по умолчанию равен 12 байтам. Структура данных комбинированного представления - это одноразовый номер, зашифрованный текст, затем тег.
            }
            return encryptedData
        }
    }
    
    enum EncryptionError: Error {
        case encryptionFailed
    }
}

//MARK: - KEY DATA FOR SHA256 -> string key convert for data sha256 key
extension SymmetricKey {
    static func key(_ value: String) -> SymmetricKey {
        let keyData = value.data(using: .utf8)!
        let sha256 = SHA256.hash(data: keyData)
        return .init(data: sha256)
    }
}

//MARK: - MODEL CATEGORY
enum TransactionCategory: String, Codable {
    case income = "Income"
    case expense = "Expense"
}

//MARK: - VIEW
struct ContentView: View {
    //MARK: - QUERY
    @Query(sort: [.init(\Transaction.transactionDate, order: .reverse)], animation: .snappy) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    
    //MARK: - View Properties
    @State private var showAlertTF: Bool = false
    @State private var keyTF: String = ""
    
    //MARK: - Exporter Properties
    @State private var exportItem: TransactionTransferable?
    @State private var showFileExporter: Bool = false
    
    //MARK: - Importer Properties
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
            isPresented: $showFileExporter,      // presenter
            item: exportItem,                    // Item for transform
            contentTypes: [.data],               // type -> data
            defaultFilename: "Transactions",     // file name
            onCompletion: { result in            // On export Actions...
                switch result {
                case .success:
                    print("Success")
                case .failure(let error):
                    print("Failure")
                    print(error.localizedDescription)
                }
                
                exportItem = nil
            },
            onCancellation: {                    // On Cancel and error
                exportItem = nil
            }
        )
        .fileImporter(
            isPresented: $showFileImporter,      // presenter
            allowedContentTypes: [.data],        // type -> data
            onCompletion: { result in            // On import Actions...
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
    
    private func exportData() {
        Task.detached(priority: .background) {
            do {
                let container = try ModelContainer(for: Transaction.self) // Make Container
                let context = ModelContext(container)                     // Make Context
                //Не используйте контекст вашей локальной среды просмотра для извлечения объектов данных, это приведет к проблемам с производительностью. Вместо этого используйте отдельный контейнер модели для извлечения всех связанных объектов из модели данных.
                
//                let descriptor = FetchDescriptor(sortBy: <#T##[SortDescriptor<PersistentModel>]#>)
                let descriptor = FetchDescriptor(sortBy: [.init(\Transaction.transactionDate, order: .reverse)])
                // Make Descriptor for exported , use model sort and reverrs order for saving
                
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
                // START - получать доступ к ресурсу, защищенному с точки зрения безопасности
                guard url.startAccessingSecurityScopedResource()  else { return }
                
                let container = try ModelContainer(for: Transaction.self) // Make Container
                let context = ModelContext(container)                     // Make Context
                
                // Data for use by URL -> POLUSHENIE PO URL DATA S CRYPTO ZAKADIROVANIM VIDE
                let encryptedData = try Data(contentsOf: url)
                // Data decrypte -> OTKRITIE ETOGO FILE PO KEY VVEDENOMU V TEXTFIELD I DECODIROVANIE
                let decryptedData = try AES.GCM.open(.init(combined: encryptedData), using: .key(keyTF))
                
                // JSON DECODER -> decodirovanie poluchanix danix uje otkritix s pomochyu key , v data v vide model masiva
                let allTransactions = try JSONDecoder().decode([Transaction].self, from: decryptedData)
                
                print(allTransactions.count)
                
                //For in V VEM MASIVE , INSERT V CONTEXT
                for transaction in allTransactions {
                    context.insert(transaction)
                }
                
                //SAVE
                try context.save()
                
                keyTF = ""
                
                url.stopAccessingSecurityScopedResource()
                // END - получать доступ к ресурсу, защищенному с точки зрения безопасности
            } catch {
                print(error.localizedDescription)
                await MainActor.run {
                    keyTF = ""
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
