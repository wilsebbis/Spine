import Foundation

// MARK: - LibriVox Service
// Queries the LibriVox API to find audiobook versions of books,
// and parses RSS feeds to get per-chapter MP3 URLs.

struct LibriVoxService {
    
    // MARK: - API Models
    
    struct LibriVoxResult: Codable {
        let id: String
        let title: String
        let numSections: String
        let totaltime: String
        let totaltimesecs: Int
        let urlZipFile: String
        let urlRss: String
        let urlLibrivox: String
        let authors: [LibriVoxAuthor]
        
        enum CodingKeys: String, CodingKey {
            case id, title, totaltime, totaltimesecs, authors
            case numSections = "num_sections"
            case urlZipFile = "url_zip_file"
            case urlRss = "url_rss"
            case urlLibrivox = "url_librivox"
        }
    }
    
    struct LibriVoxAuthor: Codable {
        let id: String
        let firstName: String
        let lastName: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case firstName = "first_name"
            case lastName = "last_name"
        }
    }
    
    struct LibriVoxAPIResponse: Codable {
        let books: [LibriVoxResult]
    }
    
    struct RSSChapter {
        let title: String
        let mp3URL: String
        let durationSeconds: Int
    }
    
    // MARK: - Search
    
    /// Search LibriVox for audiobook versions of a book by title.
    static func search(title: String) async throws -> [LibriVoxResult] {
        let query = title
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        
        guard let url = URL(string: "https://librivox.org/api/feed/audiobooks?title=\(query)&format=json") else {
            throw LibriVoxError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LibriVoxError.apiError
        }
        
        let apiResponse = try JSONDecoder().decode(LibriVoxAPIResponse.self, from: data)
        return apiResponse.books
    }
    
    /// Find the best LibriVox match for a book title.
    /// Returns the most popular version (most sections = most complete).
    static func findBestMatch(title: String) async -> LibriVoxResult? {
        guard let results = try? await search(title: title) else { return nil }
        
        // Prefer the version with the most sections (usually the most complete)
        return results
            .sorted { (Int($0.numSections) ?? 0) > (Int($1.numSections) ?? 0) }
            .first
    }
    
    // MARK: - RSS Parsing
    
    /// Parse LibriVox RSS feed to get individual chapter MP3 URLs.
    static func fetchChapters(rssURL: String) async throws -> [RSSChapter] {
        guard let url = URL(string: rssURL) else {
            throw LibriVoxError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LibriVoxError.apiError
        }
        
        // Parse RSS XML
        let parser = RSSParser()
        return parser.parse(data: data)
    }
    
    // MARK: - Errors
    
    enum LibriVoxError: LocalizedError {
        case invalidURL
        case apiError
        case noResults
        case rssParseFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid LibriVox URL"
            case .apiError: return "LibriVox API error"
            case .noResults: return "No audiobook found"
            case .rssParseFailed: return "Failed to parse RSS feed"
            }
        }
    }
}

// MARK: - Simple RSS Parser for LibriVox

private class RSSParser: NSObject, XMLParserDelegate {
    private var chapters: [LibriVoxService.RSSChapter] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentEnclosureURL = ""
    private var currentDuration = ""
    private var insideItem = false
    
    func parse(data: Data) -> [LibriVoxService.RSSChapter] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return chapters
    }
    
    // MARK: XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentEnclosureURL = ""
            currentDuration = ""
        }
        
        // <enclosure url="..." type="audio/mpeg" />
        if elementName == "enclosure", insideItem {
            if let url = attributes["url"] {
                currentEnclosureURL = url
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        
        switch currentElement {
        case "title":
            currentTitle += string
        case "itunes:duration":
            currentDuration += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" && insideItem {
            insideItem = false
            
            guard !currentEnclosureURL.isEmpty else { return }
            
            let duration = parseDuration(currentDuration.trimmingCharacters(in: .whitespacesAndNewlines))
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            
            chapters.append(LibriVoxService.RSSChapter(
                title: title.isEmpty ? "Chapter \(chapters.count + 1)" : title,
                mp3URL: currentEnclosureURL,
                durationSeconds: duration
            ))
        }
    }
    
    /// Parse "HH:MM:SS" or "MM:SS" or raw seconds string
    private func parseDuration(_ str: String) -> Int {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return 0
        }
    }
}
