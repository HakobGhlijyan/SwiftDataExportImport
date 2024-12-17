//
//  Transaction.swift
//  SwiftDataExportImport
//
//  Created by Hakob Ghlijyan on 12/17/24.
//

import SwiftUI
import SwiftData
import CryptoKit

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

enum TransactionCategory: String, Codable {
    case income = "Income"
    case expense = "Expense"
}


struct TransactionTransferable: Transferable {
    var transactions: [Transaction]
    var key: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { dataTr in
            let data = try JSONEncoder().encode(dataTr.transactions)
            guard let encryptedData = try AES.GCM.seal(data, using: .key(dataTr.key)).combined else {
                throw EncryptionError.encryptionFailed
            }
            return encryptedData
        }
    }
    
    enum EncryptionError: Error {
        case encryptionFailed
    }
}
