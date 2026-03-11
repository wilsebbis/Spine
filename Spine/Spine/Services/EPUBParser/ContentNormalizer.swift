@preconcurrency import Foundation

// MARK: - Content Normalizer
// Sanitizes EPUB XHTML into clean, renderable content.
// Strips CSS, scripts, and presentation-only markup while preserving
// semantic structure (paragraphs, headings, lists, emphasis).

struct ContentNormalizer: Sendable {
    
    // MARK: - Public API
    
    /// Normalize raw EPUB XHTML into clean HTML suitable for rendering.
    /// Preserves semantic elements, strips scripts/styles/classes.
    func normalize(html: String) -> String {
        var result = html
        
        // Remove XML declarations and doctype
        result = removePattern(#"<\?xml[^>]*\?>"#, from: result)
        result = removePattern(#"<!DOCTYPE[^>]*>"#, from: result)
        
        // Remove <head> entirely (styles, meta, etc.)
        result = removePattern(#"<head[\s\S]*?</head>"#, from: result)
        
        // Remove <script> tags
        result = removePattern(#"<script[\s\S]*?</script>"#, from: result)
        
        // Remove <style> tags
        result = removePattern(#"<style[\s\S]*?</style>"#, from: result)
        
        // Remove HTML comments
        result = removePattern(#"<!--[\s\S]*?-->"#, from: result)
        
        // Strip all attributes except href on <a> tags
        result = stripAttributes(from: result)
        
        // Remove <body> wrapper while keeping content
        result = removePattern(#"</?html[^>]*>"#, from: result)
        result = removePattern(#"</?body[^>]*>"#, from: result)
        
        // Normalize whitespace
        result = result
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        // Collapse excessive newlines
        result = collapseNewlines(result)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Extract plain text from HTML, preserving paragraph breaks.
    func extractPlainText(from html: String) -> String {
        var text = html
        
        // Replace block elements with newlines
        let blockElements = ["p", "div", "br", "h1", "h2", "h3", "h4", "h5", "h6",
                           "li", "blockquote", "tr", "hr"]
        for element in blockElements {
            text = text.replacingOccurrences(
                of: "<\(element)[^>]*>",
                with: "\n",
                options: .regularExpression
            )
            text = text.replacingOccurrences(
                of: "</\(element)>",
                with: "\n",
                options: .regularExpression
            )
        }
        
        // Remove all remaining HTML tags
        text = removePattern(#"<[^>]+>"#, from: text)
        
        // Decode HTML entities
        text = decodeHTMLEntities(text)
        
        // Normalize whitespace within lines
        text = text.components(separatedBy: "\n").map { line in
            line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }.joined(separator: "\n")
        
        // Collapse excessive newlines but preserve paragraph breaks
        text = collapseNewlines(text, maxConsecutive: 2)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Count words in a plain text string.
    func wordCount(of text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    // MARK: - Private Helpers
    
    private func removePattern(_ pattern: String, from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
    
    private func stripAttributes(from html: String) -> String {
        // Keep href on <a> tags, strip everything else
        guard let regex = try? NSRegularExpression(
            pattern: #"<(\w+)(\s+[^>]*)>"#,
            options: .caseInsensitive
        ) else { return html }
        
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        var result = html
        let matches = regex.matches(in: html, range: range).reversed()
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let tagNameRange = match.range(at: 1)
            let attrsRange = match.range(at: 2)
            let fullRange = match.range(at: 0)
            
            let tagName = nsString.substring(with: tagNameRange).lowercased()
            
            if tagName == "a" {
                // Preserve href attribute
                let attrs = nsString.substring(with: attrsRange)
                if let hrefMatch = try? NSRegularExpression(pattern: #"href\s*=\s*"[^"]*""#)
                    .firstMatch(in: attrs, range: NSRange(attrs.startIndex..<attrs.endIndex, in: attrs)),
                   let hrefRange = Range(hrefMatch.range, in: attrs) {
                    let href = String(attrs[hrefRange])
                    let replacement = "<\(tagName) \(href)>"
                    result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
                } else {
                    let replacement = "<\(tagName)>"
                    result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
                }
            } else {
                // Strip all attributes from other tags
                let replacement = "<\(tagName)>"
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    private func collapseNewlines(_ text: String, maxConsecutive: Int = 2) -> String {
        let pattern = "\n{" + String(maxConsecutive + 1) + ",}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: String(repeating: "\n", count: maxConsecutive)
        )
    }
    
    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
            ("&lsquo;", "'"),
            ("&rsquo;", "'"),
            ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"),
            ("&bull;", "•"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&deg;", "°"),
            ("&frac12;", "½"),
            ("&frac14;", "¼"),
            ("&frac34;", "¾"),
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Numeric entities: &#123; and &#x1A;
        if let numericRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = numericRegex.matches(in: result, range: range).reversed()
            for match in matches {
                if let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(String(result[numRange])),
                   let scalar = Unicode.Scalar(codePoint) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }
        
        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = hexRegex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(String(result[hexRange]), radix: 16),
                   let scalar = Unicode.Scalar(codePoint) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }
        
        return result
    }
}
