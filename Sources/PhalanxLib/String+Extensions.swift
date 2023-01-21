import CassandraClient
import Crypto
import Foundation
import Yams

// MARK: - Hashing

extension String {
  var sha256: String {
    let data = self.data(using: .utf8)!
    let hash = SHA256.hash(data: data)
    return String(hash.description.split(separator: " ").last!)
  }
}

// MARK: - Conversions

extension String {
  /// Converts a string of numerics, that could begin with zeroes,
  /// into a version integer.  For example, "0123" -> 123
  var versionInt: Int? {
    var finalized = trimmingCharacters(in: .whitespaces)
    while finalized.hasPrefix("0") {
      finalized.removeFirst()
    }

    // If we were all zeroes, then we'd end up here
    if finalized.isEmpty, !isEmpty {
      return 0
    }

    return Int(finalized)
  }
}

// MARK: - Cassandra Consistency

extension String {
  var cassandraConsistency: CassandraClient.Consistency? {
    switch self {
    case "one": return .one
    case "two": return .two
    case "three": return .three
    case "quorum": return .quorum
    case "serial": return .serial
    case "any": return .any
    default: return nil
    }
  }
}

// MARK: - Content Parsing

extension String {
  /// Investigates the content of the CQL file to see if it starts with
  /// a `metadata:` YAML dictionary. If so, it consumes lines until it
  /// hits an empty line, then pipes that into the YAML parser to extract
  /// internal metadata.
  func extractInternalMetadata() -> MigrationFileInternalMetadata? {
    let lines = components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    guard lines.first == "metadata:" || lines.first == "-- metadata:" || lines.first == "// metadata:" else {
      return nil
    }

    var finished = false
    let metadataLines: [String] = lines.filter {
      guard !finished else { return false }
      if $0.isEmpty { finished = true }
      return true
    }

    let metadataString = metadataLines
      .map { line in
        if line.hasPrefix("-- ") || line.hasPrefix("// ") {
          return String(line.dropFirst(3))
        }
        return line
      }
      .joined(separator: "\n")

    return (try? YAMLDecoder().decode(MigrationFileInternalMetadataContainer.self, from: metadataString))?.metadata
  }

  /// Inspects a CQL file to see if it contains a CREATE KEYSPACE invocation
  func detectKeyspaceCreation() -> Bool {
    components(separatedBy: .newlines)
      .contains { line in
        line
          .lowercased()
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .hasPrefix("create keyspace")
      }
  }
}
