import Crypto
import Foundation

public struct MigrationFileDescriptor: Codable, Equatable {
  let path: String
  let version: Int
  let fileNameDescription: String
}

public extension MigrationFileDescriptor {
  /// Searches the specified relative `directory` for migration file
  /// descriptors, and returns them sorted in version order.
  static func from(
    directory: String,
    migrationFilePrefix: String?,
    migrationFileSeparator: String,
    migrationFileExtension: String?
  ) throws -> [MigrationFileDescriptor] {
    let directoryContents = try FileManager.default.contentsOfDirectory(atPath: directory)

    return directoryContents.compactMap { originalFilename -> MigrationFileDescriptor? in
      // If the prefix is designated, files that do not have the prefix are ignored
      if let migrationFilePrefix, !originalFilename.hasPrefix(migrationFilePrefix) {
        return nil
      }

      // If extension is designated, files that do not have it are ignored
      if let migrationFileExtension, !originalFilename.hasSuffix(migrationFileExtension) {
        return nil
      }

      // Pull off the prefix if required
      let nonPrefixedFilename = migrationFilePrefix.flatMap {
        originalFilename.range(of: $0).flatMap {
          originalFilename.replacingCharacters(in: $0, with: "")
        }
      } ?? originalFilename

      // Separate into version and description
      let versionDesc = nonPrefixedFilename.components(separatedBy: migrationFileSeparator)

      guard versionDesc.count > 1 else {
        return nil
      }

      guard let version = versionDesc.first?.versionInt, version >= 0 else {
        return nil
      }

      guard let description = versionDesc
        .dropFirst()
        .joined(separator: migrationFileSeparator)
        .replacingOccurrences(of: "_", with: " ")
        .components(separatedBy: ".")
        .first
      else { return nil }

      return MigrationFileDescriptor(
        path: "\(directory)/\(originalFilename)",
        version: version,
        fileNameDescription: description
      )
    }.sorted { $0.version < $1.version }
  }
}
