import Foundation

struct Receipt: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let receiptDate: String?
    let ocrStatus: String
    let storagePath: String?
    let imageUrl: String?
    let notes: String?
    let createdAt: String
}

struct ReceiptList: Codable {
    let receipts: [Receipt]
    let total: Int
}

struct UpdateDateRequest: Encodable {
    let receiptDate: String

    enum CodingKeys: String, CodingKey {
        case receiptDate = "receipt_date"
    }
}
