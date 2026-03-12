import Foundation
import CloudKit
import os.log

// MARK: - CloudKit Social Service
// SocialServiceProtocol implementation using CloudKit public database.
// Handles discussions, highlight sharing, and public profiles.

final class CloudKitSocialService: SocialServiceProtocol, @unchecked Sendable {
    
    private let container = CKContainer(identifier: "iCloud.com.spine.app")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private let logger = Logger(subsystem: "com.spine.app", category: "social")
    
    // MARK: - Record Types
    
    private enum RecordType {
        static let discussion = "DiscussionPost"
        static let sharedHighlight = "SharedHighlight"
        static let publicProfile = "PublicProfile"
        static let readingClub = "ReadingClub"
    }
    
    // MARK: - Share Highlight
    
    func shareHighlight(highlightId: String, bookTitle: String) async throws {
        let record = CKRecord(recordType: RecordType.sharedHighlight)
        record["highlightId"] = highlightId
        record["bookTitle"] = bookTitle
        record["sharedAt"] = Date()
        
        try await publicDB.save(record)
        logger.info("📤 Shared highlight from \(bookTitle)")
    }
    
    // MARK: - Discussions
    
    func getDiscussion(bookId: String, unitOrdinal: Int) async throws -> [DiscussionPost] {
        let predicate = NSPredicate(
            format: "bookId == %@ AND unitOrdinal == %d",
            bookId, unitOrdinal
        )
        let query = CKQuery(recordType: RecordType.discussion, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            
            return results.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return DiscussionPost(
                    id: record.recordID.recordName,
                    authorName: record["authorName"] as? String ?? "Reader",
                    text: record["text"] as? String ?? "",
                    timestamp: record["timestamp"] as? Date ?? Date()
                )
            }
        } catch {
            // Record type doesn't exist yet — will be created on first post
            let ckError = error as NSError
            if ckError.domain == CKErrorDomain {
                logger.info("⚠️ Discussion record type not found yet — post first to create it")
                return []
            }
            throw error
        }
    }
    
    func postToDiscussion(bookId: String, unitOrdinal: Int, text: String) async throws {
        let record = CKRecord(recordType: RecordType.discussion)
        record["bookId"] = bookId
        record["unitOrdinal"] = unitOrdinal
        record["text"] = text
        record["authorName"] = try await fetchCurrentUserName()
        record["timestamp"] = Date()
        
        try await publicDB.save(record)
        logger.info("💬 Posted to discussion for unit \(unitOrdinal)")
    }
    
    // MARK: - Public Profile
    
    func getPublicProfile(userId: String) async throws -> PublicProfile {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: RecordType.publicProfile, predicate: predicate)
        
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        if let (_, result) = results.first,
           case .success(let record) = result {
            return PublicProfile(
                userId: record["userId"] as? String ?? userId,
                displayName: record["displayName"] as? String ?? "Reader",
                booksRead: record["booksRead"] as? Int ?? 0,
                currentStreak: record["currentStreak"] as? Int ?? 0
            )
        }
        
        return PublicProfile(userId: userId, displayName: "Reader", booksRead: 0, currentStreak: 0)
    }
    
    // MARK: - Reading Clubs
    
    func createClub(name: String, description: String, bookId: String) async throws -> String {
        let record = CKRecord(recordType: RecordType.readingClub)
        record["name"] = name
        record["clubDescription"] = description
        record["bookId"] = bookId
        record["memberCount"] = 1
        record["createdAt"] = Date()
        
        let saved = try await publicDB.save(record)
        logger.info("📚 Created reading club: \(name)")
        return saved.recordID.recordName
    }
    
    func getClubs(for bookId: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "bookId == %@", bookId)
        let query = CKQuery(recordType: RecordType.readingClub, predicate: predicate)
        
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 20)
        return results.compactMap { _, result in
            if case .success(let record) = result { return record }
            return nil
        }
    }
    
    // MARK: - Update Public Profile
    
    func updatePublicProfile(
        displayName: String,
        booksRead: Int,
        currentStreak: Int,
        topGenres: [String]
    ) async throws {
        let userId = try await fetchCurrentUserId()
        
        // Try to fetch existing profile
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: RecordType.publicProfile, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        
        let record: CKRecord
        if let (_, result) = results.first,
           case .success(let existing) = result {
            record = existing
        } else {
            record = CKRecord(recordType: RecordType.publicProfile)
            record["userId"] = userId
        }
        
        record["displayName"] = displayName
        record["booksRead"] = booksRead
        record["currentStreak"] = currentStreak
        record["topGenres"] = topGenres
        record["updatedAt"] = Date()
        
        try await publicDB.save(record)
        logger.info("👤 Updated public profile")
    }
    
    // MARK: - Helpers
    
    private func fetchCurrentUserId() async throws -> String {
        let userID = try await container.userRecordID()
        return userID.recordName
    }
    
    private func fetchCurrentUserName() async throws -> String {
        // In production, you'd fetch from user's profile
        return "Reader"
    }
}
