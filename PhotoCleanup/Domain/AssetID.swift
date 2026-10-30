import Foundation

nonisolated struct AssetID: Hashable, Sendable, Codable, CodingKeyRepresentable, Identifiable {
    let rawValue: String

    var id: AssetID { self }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var codingKey: any CodingKey { Key(stringValue: rawValue) }

    init?<T: CodingKey>(codingKey: T) {
        rawValue = codingKey.stringValue
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
