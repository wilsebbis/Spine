@preconcurrency import Foundation
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

// MARK: - EPUB Parser
// Handles the complete pipeline: unzip → parse OPF → parse TOC → load spine content.
// Designed to handle Gutenberg EPUB inconsistencies gracefully.
// This is a plain final class (not an actor) because all work is synchronous.
// The caller (IngestionPipeline) is @MainActor and calls this via Task.

final class EPUBParser: Sendable {
    
    enum ParseError: LocalizedError, Sendable {
        case fileNotFound(String)
        case unzipFailed(String)
        case containerNotFound
        case opfNotFound
        case invalidOPF
        case noSpineItems
        case contentLoadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path): return "EPUB file not found: \(path)"
            case .unzipFailed(let reason): return "Failed to unzip EPUB: \(reason)"
            case .containerNotFound: return "META-INF/container.xml not found"
            case .opfNotFound: return "OPF package document not found"
            case .invalidOPF: return "Could not parse OPF package document"
            case .noSpineItems: return "No readable spine items found"
            case .contentLoadFailed(let href): return "Failed to load content: \(href)"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Parse an EPUB file at the given URL.
    /// Returns a fully parsed EPUB with extracted chapters.
    /// This is a synchronous, thread-safe operation.
    nonisolated func parse(epubURL: URL) throws -> ParsedEPUB {
        let fm = FileManager.default
        
        // 1. Unzip to temp directory
        let extractDir = try unzipEPUB(at: epubURL, fileManager: fm)
        
        defer {
            try? fm.removeItem(at: extractDir)
        }
        
        // 2. Find OPF path from container.xml
        let opfPath = try findOPFPath(in: extractDir, fileManager: fm)
        let opfURL = extractDir.appendingPathComponent(opfPath)
        let opfDir = opfURL.deletingLastPathComponent()
        
        // 3. Parse OPF
        let opfData = try Data(contentsOf: opfURL)
        let (metadata, manifest, spineRefs) = OPFParser.parseOPF(data: opfData)
        
        // 4. Build spine items from manifest
        let spineItems = buildSpine(from: spineRefs, manifest: manifest)
        guard !spineItems.isEmpty else { throw ParseError.noSpineItems }
        
        // 5. Parse table of contents (NCX or nav)
        let toc = parseTOC(manifest: manifest, opfDir: opfDir)
        
        // 6. Extract chapters from spine
        let chapters = extractChapters(
            spineItems: spineItems,
            toc: toc,
            opfDir: opfDir
        )
        
        // 7. Extract cover image if present
        var finalMetadata = metadata
        if let coverHref = findCoverHref(metadata: metadata, manifest: manifest) {
            finalMetadata.coverImageHref = coverHref
        }
        
        return ParsedEPUB(
            metadata: finalMetadata,
            spine: spineItems,
            tableOfContents: toc,
            chapters: chapters
        )
    }
    
    /// Extract cover image data from the EPUB at the given URL.
    nonisolated func extractCoverImage(epubURL: URL) throws -> Data? {
        let fm = FileManager.default
        let extractDir = try unzipEPUB(at: epubURL, fileManager: fm)
        defer { try? fm.removeItem(at: extractDir) }
        
        let opfPath = try findOPFPath(in: extractDir, fileManager: fm)
        let opfURL = extractDir.appendingPathComponent(opfPath)
        let opfDir = opfURL.deletingLastPathComponent()
        
        let opfData = try Data(contentsOf: opfURL)
        let (metadata, manifest, _) = OPFParser.parseOPF(data: opfData)
        
        if let coverHref = findCoverHref(metadata: metadata, manifest: manifest) {
            let coverURL = opfDir.appendingPathComponent(coverHref)
            return try? Data(contentsOf: coverURL)
        }
        return nil
    }
    
    // MARK: - Unzip
    
    private nonisolated func unzipEPUB(at url: URL, fileManager fm: FileManager) throws -> URL {
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("SpineEPUB_\(UUID().uuidString)")
        
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        #if canImport(ZIPFoundation)
        do {
            try fm.unzipItem(at: url, to: tempDir)
        } catch {
            throw ParseError.unzipFailed(error.localizedDescription)
        }
        return tempDir
        #else
        throw ParseError.unzipFailed(
            "ZIPFoundation is not linked. Add via File → Add Package Dependencies → https://github.com/weichsel/ZIPFoundation.git"
        )
        #endif
    }
    
    // MARK: - Container.xml
    
    private nonisolated func findOPFPath(in extractDir: URL, fileManager fm: FileManager) throws -> String {
        let containerURL = extractDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        
        guard fm.fileExists(atPath: containerURL.path) else {
            throw ParseError.containerNotFound
        }
        
        let data = try Data(contentsOf: containerURL)
        
        // Parse container.xml using simple string search (avoids NSObject/MainActor issues)
        let xmlString = String(data: data, encoding: .utf8) ?? ""
        guard let opfPath = extractRootfilePath(from: xmlString) else {
            throw ParseError.opfNotFound
        }
        
        return opfPath
    }
    
    /// Extract full-path attribute from container.xml rootfile element using regex.
    private nonisolated func extractRootfilePath(from xml: String) -> String? {
        // Match: <rootfile full-path="..." .../>
        guard let regex = try? NSRegularExpression(
            pattern: #"<rootfile[^>]+full-path\s*=\s*"([^"]+)""#,
            options: .caseInsensitive
        ) else { return nil }
        
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let pathRange = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        return String(xml[pathRange])
    }
    
    // MARK: - Spine Building
    
    private nonisolated func buildSpine(from refs: [String], manifest: [String: ManifestItem]) -> [SpineItem] {
        return refs.compactMap { idref in
            guard let item = manifest[idref] else { return nil }
            return SpineItem(
                id: item.id,
                href: item.href,
                mediaType: item.mediaType,
                linear: true
            )
        }
    }
    
    // MARK: - TOC Parsing
    
    private nonisolated func parseTOC(manifest: [String: ManifestItem], opfDir: URL) -> [TOCEntry] {
        // Try NCX first (EPUB 2), then nav document (EPUB 3)
        if let ncxItem = manifest.values.first(where: { $0.mediaType == "application/x-dtbncx+xml" }) {
            let ncxURL = opfDir.appendingPathComponent(ncxItem.href)
            if let data = try? Data(contentsOf: ncxURL),
               let xml = String(data: data, encoding: .utf8) {
                return NCXStringParser.parse(xml: xml)
            }
        }
        
        // EPUB 3 nav document
        if let navItem = manifest.values.first(where: { $0.properties?.contains("nav") == true }) {
            let navURL = opfDir.appendingPathComponent(navItem.href)
            if let data = try? Data(contentsOf: navURL),
               let xml = String(data: data, encoding: .utf8) {
                return NavStringParser.parse(xml: xml)
            }
        }
        
        return []
    }
    
    // MARK: - Chapter Extraction
    
    private nonisolated func extractChapters(
        spineItems: [SpineItem],
        toc: [TOCEntry],
        opfDir: URL
    ) -> [ParsedChapter] {
        let normalizer = ContentNormalizer()
        let tocMap = buildTOCMap(from: toc)
        var chapters: [ParsedChapter] = []
        var ordinal = 0
        
        for item in spineItems {
            let contentURL = opfDir.appendingPathComponent(item.href)
            guard let data = try? Data(contentsOf: contentURL),
                  let html = String(data: data, encoding: .utf8) else {
                continue
            }
            
            let normalized = normalizer.normalize(html: html)
            let plainText = normalizer.extractPlainText(from: html)
            let wc = normalizer.wordCount(of: plainText)
            
            guard wc > 50 else { continue }
            
            let baseHref = item.href.components(separatedBy: "#").first ?? item.href
            let title = tocMap[baseHref] ?? "Chapter \(ordinal + 1)"
            
            chapters.append(ParsedChapter(
                ordinal: ordinal,
                title: title,
                sourceHref: item.href,
                plainText: plainText,
                htmlContent: normalized,
                wordCount: wc
            ))
            
            ordinal += 1
        }
        
        return chapters
    }
    
    private nonisolated func buildTOCMap(from entries: [TOCEntry]) -> [String: String] {
        var map: [String: String] = [:]
        func flatten(_ entries: [TOCEntry]) {
            for entry in entries {
                let baseHref = entry.href.components(separatedBy: "#").first ?? entry.href
                map[baseHref] = entry.title
                flatten(entry.children)
            }
        }
        flatten(entries)
        return map
    }
    
    // MARK: - Cover Detection
    
    private nonisolated func findCoverHref(metadata: EPUBMetadata, manifest: [String: ManifestItem]) -> String? {
        if let coverID = metadata.rawMetadata["cover"],
           let coverItem = manifest[coverID] {
            return coverItem.href
        }
        if let coverItem = manifest.values.first(where: {
            $0.properties?.contains("cover-image") == true
        }) {
            return coverItem.href
        }
        if let coverItem = manifest.values.first(where: {
            $0.id.lowercased().contains("cover") &&
            $0.mediaType.starts(with: "image/")
        }) {
            return coverItem.href
        }
        return nil
    }
}

// MARK: - OPF Parser (regex-based, no NSObject)
// Avoids XMLParserDelegate / NSObject which are @MainActor in Swift 6.

private enum OPFParser {
    
    struct OPFResult {
        var metadata: EPUBMetadata
        var manifest: [String: ManifestItem]
        var spineRefs: [String]
    }
    
    static func parseOPF(data: Data) -> (EPUBMetadata, [String: ManifestItem], [String]) {
        let xml = String(data: data, encoding: .utf8) ?? ""
        var metadata = EPUBMetadata()
        var manifest: [String: ManifestItem] = [:]
        var spineRefs: [String] = []
        
        // Parse metadata
        metadata.title = extractTag("dc:title", from: xml) ?? extractTag("title", from: xml) ?? "Untitled"
        metadata.author = extractTag("dc:creator", from: xml) ?? extractTag("creator", from: xml) ?? "Unknown Author"
        metadata.description = extractTag("dc:description", from: xml) ?? extractTag("description", from: xml) ?? ""
        metadata.language = extractTag("dc:language", from: xml) ?? extractTag("language", from: xml) ?? "en"
        metadata.identifier = extractTag("dc:identifier", from: xml) ?? extractTag("identifier", from: xml) ?? ""
        
        // Parse meta cover
        if let coverMatch = matchPattern(#"<meta\s+name\s*=\s*"cover"\s+content\s*=\s*"([^"]+)""#, in: xml) {
            metadata.rawMetadata["cover"] = coverMatch
        } else if let coverMatch = matchPattern(#"<meta\s+content\s*=\s*"([^"]+)"\s+name\s*=\s*"cover""#, in: xml) {
            metadata.rawMetadata["cover"] = coverMatch
        }
        
        // Parse manifest items
        let itemPattern = #"<item\s+([^>]+)/?\s*>"#
        if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            let matches = itemRegex.matches(in: xml, range: range)
            for match in matches {
                if let attrRange = Range(match.range(at: 1), in: xml) {
                    let attrs = String(xml[attrRange])
                    if let id = extractAttr("id", from: attrs),
                       let href = extractAttr("href", from: attrs),
                       let mediaType = extractAttr("media-type", from: attrs) {
                        let properties = extractAttr("properties", from: attrs)
                        manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
                    }
                }
            }
        }
        
        // Parse spine itemrefs
        let itemrefPattern = #"<itemref\s+([^>]+)/?\s*>"#
        if let itemrefRegex = try? NSRegularExpression(pattern: itemrefPattern, options: .caseInsensitive) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            let matches = itemrefRegex.matches(in: xml, range: range)
            for match in matches {
                if let attrRange = Range(match.range(at: 1), in: xml) {
                    let attrs = String(xml[attrRange])
                    if let idref = extractAttr("idref", from: attrs) {
                        let linear = extractAttr("linear", from: attrs)
                        if linear != "no" {
                            spineRefs.append(idref)
                        }
                    }
                }
            }
        }
        
        return (metadata, manifest, spineRefs)
    }
    
    private static func extractTag(_ tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)[^>]*>([^<]+)</\(tag)>"
        return matchPattern(pattern, in: xml)
    }
    
    private static func extractAttr(_ attr: String, from text: String) -> String? {
        let pattern = #"\#(attr)\s*=\s*"([^"]*)""#
        return matchPattern(pattern, in: text)
    }
    
    private static func matchPattern(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[captureRange])
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - NCX String Parser (no NSObject)

private enum NCXStringParser {
    static func parse(xml: String) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        // Extract navPoints with their content - using start position pattern
        let textPattern = #"<text>\s*([^<]+?)\s*</text>"#
        let srcPattern = #"<content\s+src\s*=\s*"([^"]+)""#
        let orderPattern = #"playOrder\s*=\s*"(\d+)""#
        
        // Find all navPoint start tags
        let navPointStartPattern = #"<navPoint[^>]*>"#
        
        guard let startRegex = try? NSRegularExpression(pattern: navPointStartPattern, options: .caseInsensitive),
              let textRegex = try? NSRegularExpression(pattern: textPattern, options: .caseInsensitive),
              let srcRegex = try? NSRegularExpression(pattern: srcPattern, options: .caseInsensitive),
              let orderRegex = try? NSRegularExpression(pattern: orderPattern, options: .caseInsensitive) else {
            return entries
        }
        
        // Find all navPoint start positions
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let startMatches = startRegex.matches(in: xml, range: range)
        
        for (i, startMatch) in startMatches.enumerated() {
            let searchStart = startMatch.range.location
            let searchEnd = (i + 1 < startMatches.count) ? startMatches[i + 1].range.location : (range.length)
            let searchRange = NSRange(location: searchStart, length: searchEnd - searchStart)
            
            var title = ""
            var href = ""
            var playOrder: Int? = nil
            
            // Extract text
            if let textMatch = textRegex.firstMatch(in: xml, range: searchRange),
               let textRange = Range(textMatch.range(at: 1), in: xml) {
                title = String(xml[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract src
            if let srcMatch = srcRegex.firstMatch(in: xml, range: searchRange),
               let srcRange = Range(srcMatch.range(at: 1), in: xml) {
                href = String(xml[srcRange])
            }
            
            // Extract playOrder from the navPoint tag itself
            let tagRange = startMatch.range
            if let orderMatch = orderRegex.firstMatch(in: xml, range: tagRange),
               let orderRange = Range(orderMatch.range(at: 1), in: xml) {
                playOrder = Int(String(xml[orderRange]))
            }
            
            if !title.isEmpty && !href.isEmpty {
                entries.append(TOCEntry(
                    title: title,
                    href: href,
                    children: [],
                    playOrder: playOrder
                ))
            }
        }
        
        return entries
    }
}

// MARK: - Nav Document String Parser (no NSObject)

private enum NavStringParser {
    static func parse(xml: String) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        
        // Find the nav[epub:type="toc"] section
        let navPattern = #"<nav[^>]*epub:type\s*=\s*"toc"[^>]*>[\s\S]*?</nav>"#
        guard let navRegex = try? NSRegularExpression(pattern: navPattern, options: .caseInsensitive) else {
            return entries
        }
        
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let navMatch = navRegex.firstMatch(in: xml, range: range),
              let navRange = Range(navMatch.range, in: xml) else {
            return entries
        }
        
        let navContent = String(xml[navRange])
        
        // Extract all <a href="...">title</a> from the nav
        let linkPattern = #"<a\s+href\s*=\s*"([^"]+)"[^>]*>([^<]+)</a>"#
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) else {
            return entries
        }
        
        let navNSRange = NSRange(navContent.startIndex..<navContent.endIndex, in: navContent)
        let linkMatches = linkRegex.matches(in: navContent, range: navNSRange)
        
        for (i, match) in linkMatches.enumerated() {
            if let hrefRange = Range(match.range(at: 1), in: navContent),
               let titleRange = Range(match.range(at: 2), in: navContent) {
                let href = String(navContent[hrefRange])
                let title = String(navContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !title.isEmpty {
                    entries.append(TOCEntry(
                        title: title,
                        href: href,
                        children: [],
                        playOrder: i + 1
                    ))
                }
            }
        }
        
        return entries
    }
}
