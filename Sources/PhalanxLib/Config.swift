import Foundation
import Yams

public struct Config: Codable {
  public struct Client: Codable {
    public var hosts: [String]?
    public var port: Int?
    public var protocolVersion: Int?
    public var keyspace: String?
    public var username: String?
    public var password: String?
    public var consistency: String?

    public init(
      hosts: [String]?,
      port: Int?,
      protocolVersion: Int?,
      keyspace: String?,
      username: String?,
      password: String?,
      consistency: String?
    ) {
      self.hosts = hosts
      self.port = port
      self.protocolVersion = protocolVersion
      self.keyspace = keyspace
      self.username = username
      self.password = password
      self.consistency = consistency
    }
  }

  public struct Migration: Codable {
    public var invocationDelay: Int?
    public var directory: String?
    public var fileSeparator: String?
    public var filePrefix: String?
    public var fileExtension: String?
    public var ignoreHistoricalHashes: Bool?

    public init(
      invocationDelay: Int?,
      directory: String?,
      fileSeparator: String?,
      filePrefix: String?,
      fileExtension: String?,
      ignoreHistoricalHashes: Bool?
    ) {
      self.invocationDelay = invocationDelay
      self.directory = directory
      self.fileSeparator = fileSeparator
      self.filePrefix = filePrefix
      self.fileExtension = fileExtension
      self.ignoreHistoricalHashes = ignoreHistoricalHashes
    }
  }

  public var client: Client?
  public var phalanxStateTable: String?
  public var migration: Migration?

  public init(
    client: Client?,
    phalanxStateTable: String?,
    migration: Migration?
  ) {
    self.client = client
    self.phalanxStateTable = phalanxStateTable
    self.migration = migration
  }
}

public extension Config {
  static func from(path: String) throws -> Config? {
    guard FileManager.default.fileExists(atPath: path) else {
      return nil
    }

    guard let data = try String(contentsOfFile: path).data(using: .utf8) else {
      return nil
    }

    return try YAMLDecoder().decode(Config.self, from: data, userInfo: [:])
  }

  func toYAML() -> String {
    try! YAMLEncoder().encode(self)
  }
}
