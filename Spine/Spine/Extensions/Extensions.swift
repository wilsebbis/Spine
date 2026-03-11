import Foundation

// MARK: - Date Extensions

extension Date {
    /// Returns the start of day for this date.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns true if this date is today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if this date is yesterday.
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns the number of days between this date and another.
    func daysBetween(_ other: Date) -> Int {
        abs(Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0)
    }
}

// MARK: - String Extensions

extension String {
    /// Quick word count.
    var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    /// Estimated reading time in minutes.
    func estimatedReadingMinutes(wpm: Int = 225) -> Double {
        guard wpm > 0 else { return 0 }
        return Double(wordCount) / Double(wpm)
    }
    
    /// Truncate to a maximum length with ellipsis.
    func truncated(to maxLength: Int) -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength - 1)) + "…"
    }
}
