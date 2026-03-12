import Foundation

/// Author biographical metadata stored as JSON on Book.
/// Not a SwiftData @Model — serialized via `authorMetadataJSON`.
struct AuthorMetadata: Codable, Sendable, Hashable {
    let name: String
    let birthYear: Int?
    let deathYear: Int?
    let nationality: String?
    let shortBio: String
    let notableWorks: [String]
    
    var lifespanText: String? {
        switch (birthYear, deathYear) {
        case let (b?, d?): return "\(b)–\(d)"
        case let (b?, nil): return "b. \(b)"
        default: return nil
        }
    }
}
