import Foundation

public struct InstalledMigrationVersion: Codable, Equatable {
  public let rank: Int
  public let version: Int
  public let description: String
  public let file: String
  public let hash: String
  public let installed: Date
  public let duration: Int
}
