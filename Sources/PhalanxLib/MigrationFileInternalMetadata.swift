import Foundation

public struct MigrationFileInternalMetadata: Codable, Equatable {
  let description: String?
  let consistency: String?
  let invocationDelay: Int?
}

public struct MigrationFileInternalMetadataContainer: Codable, Equatable {
  let metadata: MigrationFileInternalMetadata
}
