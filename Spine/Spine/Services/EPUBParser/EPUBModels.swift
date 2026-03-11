import Foundation

// MARK: - EPUB Parse Models
// Internal representations used during EPUB parsing, before persisting to SwiftData.

/// The result of parsing an EPUB file.
struct ParsedEPUB: Sendable {
    let metadata: EPUBMetadata
    let spine: [SpineItem]
    let tableOfContents: [TOCEntry]
    let chapters: [ParsedChapter]
}

/// Metadata extracted from the OPF package document.
struct EPUBMetadata: Sendable {
    var title: String = "Untitled"
    var author: String = "Unknown Author"
    var description: String = ""
    var language: String = "en"
    var identifier: String = ""
    var coverImageHref: String?
    var rawMetadata: [String: String] = [:]
}

/// A single item in the EPUB spine (reading order).
struct SpineItem: Sendable {
    let id: String
    let href: String
    let mediaType: String
    let linear: Bool
}

/// A table-of-contents entry parsed from NCX or nav document.
struct TOCEntry: Sendable {
    let title: String
    let href: String
    let children: [TOCEntry]
    let playOrder: Int?
}

/// A chapter extracted and normalized from the EPUB content.
struct ParsedChapter: Sendable {
    let ordinal: Int
    let title: String
    let sourceHref: String
    let plainText: String
    let htmlContent: String
    let wordCount: Int
}

/// Represents a manifest item from the OPF.
struct ManifestItem: Sendable {
    let id: String
    let href: String
    let mediaType: String
    let properties: String?
}
