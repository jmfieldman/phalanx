import Foundation

public struct InstalledMigrationState: Equatable {
  public let keyspace: String?
  public let stateTable: String?
  public let migrations: [InstalledMigrationVersion]?
}

public extension InstalledMigrationState {
  static let noKeyspace = InstalledMigrationState(
    keyspace: nil,
    stateTable: nil,
    migrations: nil
  )

  static func noTable(keyspace: String) -> InstalledMigrationState {
    InstalledMigrationState(
      keyspace: keyspace,
      stateTable: nil,
      migrations: nil
    )
  }
}
