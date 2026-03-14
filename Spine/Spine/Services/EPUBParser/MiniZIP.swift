import Foundation
import Compression

/// A minimal ZIP extractor using only Foundation and the Compression framework (available on all Apple platforms).
/// Supports the standard ZIP format used by EPUB files (Stored and Deflated entries).
enum MiniZIP: Sendable {

    enum ZIPError: LocalizedError {
        case invalidArchive
        case unsupportedCompression(UInt16)
        case decompressionFailed(String)
        case crcMismatch

        var errorDescription: String? {
            switch self {
            case .invalidArchive: return "Not a valid ZIP archive."
            case .unsupportedCompression(let m): return "Unsupported compression method \(m)."
            case .decompressionFailed(let n): return "Failed to decompress entry: \(n)."
            case .crcMismatch: return "CRC-32 checksum mismatch."
            }
        }
    }

    // MARK: - Public

    /// Extract all entries from `zipData` into `destination`.
    static func extract(_ zipData: Data, to destination: URL, fileManager fm: FileManager) throws {
        // Locate End-of-Central-Directory record (EOCD).
        guard let eocdOffset = findEOCD(in: zipData) else {
            throw ZIPError.invalidArchive
        }

        let cdOffset = Int(readUInt32(zipData, at: eocdOffset + 16))
        let entryCount = Int(readUInt16(zipData, at: eocdOffset + 10))

        var offset = cdOffset
        for _ in 0..<entryCount {
            guard offset + 46 <= zipData.count else { throw ZIPError.invalidArchive }
            let sig = readUInt32(zipData, at: offset)
            guard sig == 0x02014B50 else { throw ZIPError.invalidArchive }

            let compressionMethod = readUInt16(zipData, at: offset + 10)
            let compressedSize = Int(readUInt32(zipData, at: offset + 20))
            let uncompressedSize = Int(readUInt32(zipData, at: offset + 24))
            let nameLen = Int(readUInt16(zipData, at: offset + 28))
            let extraLen = Int(readUInt16(zipData, at: offset + 30))
            let commentLen = Int(readUInt16(zipData, at: offset + 32))
            let localHeaderOffset = Int(readUInt32(zipData, at: offset + 42))

            let nameData = zipData[offset + 46 ..< offset + 46 + nameLen]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Advance past this central-directory entry.
            offset += 46 + nameLen + extraLen + commentLen

            // Skip directory entries and empty names.
            guard !name.isEmpty, !name.hasSuffix("/") else { continue }

            // Read from local file header to get the actual data offset.
            guard localHeaderOffset + 30 <= zipData.count else { throw ZIPError.invalidArchive }
            let localSig = readUInt32(zipData, at: localHeaderOffset)
            guard localSig == 0x04034B50 else { throw ZIPError.invalidArchive }

            let localNameLen = Int(readUInt16(zipData, at: localHeaderOffset + 26))
            let localExtraLen = Int(readUInt16(zipData, at: localHeaderOffset + 28))
            let dataStart = localHeaderOffset + 30 + localNameLen + localExtraLen

            guard dataStart + compressedSize <= zipData.count else { throw ZIPError.invalidArchive }
            let compressedData = zipData[dataStart ..< dataStart + compressedSize]

            let fileData: Data
            switch compressionMethod {
            case 0: // Stored
                fileData = Data(compressedData)
            case 8: // Deflated
                fileData = try inflate(Data(compressedData), expectedSize: uncompressedSize, entryName: name)
            default:
                throw ZIPError.unsupportedCompression(compressionMethod)
            }

            // Sanitize path to prevent directory traversal.
            let sanitized = name.components(separatedBy: "/").filter { $0 != ".." && !$0.isEmpty }.joined(separator: "/")
            let fileURL = destination.appendingPathComponent(sanitized)
            let parentDir = fileURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: parentDir.path) {
                try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            try fileData.write(to: fileURL)
        }
    }

    // MARK: - Private helpers

    /// Find the End-of-Central-Directory signature scanning backward.
    private static func findEOCD(in data: Data) -> Int? {
        let sig: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        let minOffset = max(0, data.count - 65_557) // max comment size + EOCD size
        for i in stride(from: data.count - 4, through: minOffset, by: -1) {
            if data[i] == sig[0], data[i+1] == sig[1], data[i+2] == sig[2], data[i+3] == sig[3] {
                return i
            }
        }
        return nil
    }

    /// Inflate (decompress) raw-deflate data using the Compression framework.
    private static func inflate(_ data: Data, expectedSize: Int, entryName: String) throws -> Data {
        // Use a generous buffer — some EPUB entries may be larger than expected.
        let bufferSize = max(expectedSize * 2, 65_536)
        var result = Data(count: bufferSize)
        let decompressedSize = data.withUnsafeBytes { srcPtr -> Int in
            result.withUnsafeMutableBytes { dstPtr -> Int in
                guard let srcBase = srcPtr.baseAddress,
                      let dstBase = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_decode_buffer(
                    dstBase, bufferSize,
                    srcBase.assumingMemoryBound(to: UInt8.self), data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decompressedSize > 0 else {
            throw ZIPError.decompressionFailed(entryName)
        }
        result.count = decompressedSize
        return result
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
    }
}
