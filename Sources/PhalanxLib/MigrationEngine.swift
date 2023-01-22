import CassandraClient
import Foundation

private let kKeyspacePlaceholder = "$${{KEYSPACE}}$$"

public enum MigrationEngineError: Error, Equatable {
  case invalidConfig(String)
  case invalidFileMetadata(String)
  case incorrectKeyspace(String)
  case noKeyspaceMigration(String)
  case duplicateVersions(String)
  case migrationMismatch(String)
  case migrationError(String)
}

public final class MigrationEngine {
  let config: Config
  let clientConfig: CassandraClient.Configuration
  let client: CassandraClient
  let keyspace: String
  let stateTable: String

  let printInfo: ((String) -> Void)?
  let printVerbose: ((String) -> Void)?

  // MARK: Init

  public init(
    config: Config,
    printInfo: ((String) -> Void)? = nil,
    printVerbose: ((String) -> Void)? = nil
  ) throws {
    self.config = config

    // Initialize Cassandra Config
    guard let hosts = config.client?.hosts, !hosts.isEmpty else {
      throw MigrationEngineError.invalidConfig("Cassandra client hosts/contactPoints are not defined")
    }

    guard let port = config.client?.port.flatMap(Int32.init) else {
      throw MigrationEngineError.invalidConfig("Cassandra client port is not defined")
    }

    guard let protocolVersionInt = config.client?.protocolVersion.flatMap(Int32.init) else {
      throw MigrationEngineError.invalidConfig("Cassandra client protocolVersion is not defined")
    }

    guard let protocolVersion = CassandraClient.Configuration.ProtocolVersion(rawValue: protocolVersionInt) else {
      throw MigrationEngineError.invalidConfig("Cassandra client protocolVersion \(protocolVersionInt) is invalid")
    }

    guard let keyspace = config.client?.keyspace else {
      throw MigrationEngineError.invalidConfig("Cassandra client keyspace is not defined")
    }

    guard let stateTable = config.phalanxStateTable else {
      throw MigrationEngineError.invalidConfig("Cassandra state table name is not defined")
    }

    var clientConfig = CassandraClient.Configuration(
      contactPointsProvider: { $0(.success(hosts)) },
      port: port,
      protocolVersion: protocolVersion
    )

    // If consistency is defined, we should verify it
    if let consistency = config.client?.consistency {
      guard let resolved = consistency.cassandraConsistency else {
        throw MigrationEngineError.invalidConfig("Cassandra client consistency \(consistency) is invalid")
      }

      clientConfig.consistency = resolved
    }

    clientConfig.username = config.client?.username
    clientConfig.password = config.client?.password
    clientConfig.keyspace = keyspace

    self.clientConfig = clientConfig
    self.client = CassandraClient(configuration: clientConfig)
    self.keyspace = keyspace
    self.stateTable = stateTable
    self.printInfo = printInfo
    self.printVerbose = printVerbose
  }

  deinit {
    try? client.shutdown()
    try? neutralClient.shutdown()
    try? serialConsistencyClient.shutdown()
    try? anyConsistencyClient.shutdown()
  }

  // MARK: Specialized Clients

  /// Generates a version of the engine's client that is not associated
  /// to a specific keyspace. This allows us to perform keyspace-based
  /// queries regardless of whether or not the keyspace exists.
  lazy var neutralClient: CassandraClient = {
    var neutralConfig = clientConfig
    neutralConfig.keyspace = nil
    return CassandraClient(configuration: neutralConfig)
  }()

  /// Generates a version of the engine's client that is set with .serial
  /// consistency. Useful for serialized operations
  lazy var serialConsistencyClient: CassandraClient = {
    var neutralConfig = clientConfig
    neutralConfig.consistency = .serial
    return CassandraClient(configuration: neutralConfig)
  }()

  /// Generates a version of the engine's client that is set with .any
  /// consistency. Useful for inserting state table updates
  lazy var anyConsistencyClient: CassandraClient = {
    var neutralConfig = clientConfig
    neutralConfig.consistency = .any
    return CassandraClient(configuration: neutralConfig)
  }()

  // MARK: Detect Current Remote State

  /// Connect to the cluster and determine the current migration state.
  public func detectMigrationState() async throws -> InstalledMigrationState {
    let keyspaceQuery = try await neutralClient.query("DESC KEYSPACES")
    let keyspaces = keyspaceQuery.map { row -> String? in row.column(0) }
    guard keyspaces.contains(keyspace) else {
      return .noKeyspace
    }

    // Detect our state table (this will generate an error if the table
    // does not exist.
    do {
      _ = try await serialConsistencyClient.query("DESC \(keyspace).\(stateTable)")
    } catch {
      return .noTable(keyspace: keyspace)
    }

    // The table exists, so we can extract migrations
    let migrations: [InstalledMigrationVersion] = try await serialConsistencyClient.query("SELECT * FROM \(keyspace).\(stateTable)")

    return InstalledMigrationState(
      keyspace: keyspace,
      stateTable: stateTable,
      migrations: migrations.sorted(by: { $0.version < $1.version })
    )
  }

  // MARK: Drop Keyspace

  /// Drop the keyspace that is configured for this engine (this is associated
  /// with the `clean` action.
  public func dropKeyspace() async throws {
    _ = try await neutralClient.query("DROP KEYSPACE IF EXISTS \(keyspace)")
  }

  // MARK: Return detected migrations on disk

  /// Returns the detected migrations from the configured migration directory.
  public func detectFileMigrations() throws -> [MigrationFile] {
    guard let directory = config.migration?.directory else {
      throw MigrationEngineError.invalidConfig("migrationDirectory is not defined")
    }

    guard let separator = config.migration?.fileSeparator else {
      throw MigrationEngineError.invalidConfig("migrationFileSeparator is not defined")
    }

    let descriptors = try MigrationFileDescriptor.from(
      directory: directory,
      migrationFilePrefix: config.migration?.filePrefix,
      migrationFileSeparator: separator,
      migrationFileExtension: config.migration?.fileExtension
    )

    var dupeCheck: Set<Int> = []
    try descriptors.forEach {
      if dupeCheck.contains($0.version) {
        throw MigrationEngineError.duplicateVersions("There are two file migrations with duplicate version \($0.version)")
      }
      dupeCheck.insert($0.version)
    }

    return try descriptors.compactMap { descriptor -> MigrationFile? in
      try MigrationFile.from(
        path: descriptor.path,
        version: descriptor.version,
        fileNameDescription: descriptor.fileNameDescription
      )
    }
  }

  // MARK: - Execute Migration

  /// Execute the migration given the current state and migration files.
  public func executeMigration(
    migrationState: InstalledMigrationState,
    fileMigrations: [MigrationFile]
  ) async throws {
    // Step 1: Create the keyspace if it is not present.
    if migrationState.keyspace == nil {
      printVerbose?("Keyspace [\(keyspace)] not found; creating with version 0 migration.")
      try await generateKeyspaceFromVersionZero(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    } else if let migrationKeyspace = migrationState.keyspace, migrationKeyspace != keyspace {
      // Sanity checking that the correct state was passed in
      throw MigrationEngineError.incorrectKeyspace("Migration state keyspace [\(migrationKeyspace)] mismatches engine keyspace [\(keyspace)]")
    }

    // Step 2: Create the state table if it doesn't exist
    if migrationState.stateTable == nil {
      printVerbose?("State table [\(keyspace).\(stateTable)] not found; creating")
      try await generateStateTable(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    } else if let migrationStateTable = migrationState.stateTable, migrationStateTable != stateTable {
      // Sanity checking that the correct state table was passed in
      throw MigrationEngineError.incorrectKeyspace("Migration state table [\(keyspace).\(migrationStateTable)] mismatches engine state table [\(stateTable)]")
    }

    // Step 3: Verify hashes of existing migrations (if desired)
    if !(config.migration?.ignoreHistoricalHashes == true) {
      try verifyHistoricalHashes(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // Step 4: Install new migrations
    try await installNewMigrations(
      migrationState: migrationState,
      fileMigrations: fileMigrations
    )
  }

  /// Executes the version 0 migration to create the required keyspace,
  /// then sanity checks that the keyspace now exists.
  func generateKeyspaceFromVersionZero(
    migrationState: InstalledMigrationState,
    fileMigrations: [MigrationFile]
  ) async throws {
    guard let migration = fileMigrations.first(where: { $0.version == 0 }) else {
      throw MigrationEngineError.noKeyspaceMigration("Keyspace \(keyspace) is missing and requires a reserved version 0 migration to create.")
    }

    guard migration.contents.detectKeyspaceCreation() else {
      throw MigrationEngineError.noKeyspaceMigration("Keyspace creation migration (version 0) requires a CREATE KEYSPACE command.")
    }

    _ = try await neutralClient.query(
      migration.contents.replacingOccurrences(
        of: kKeyspacePlaceholder,
        with: keyspace
      )
    )

    // Sanity check that migration 0 created the correct keyspace
    let newState = try await detectMigrationState()
    guard newState.keyspace == keyspace else {
      throw MigrationEngineError.incorrectKeyspace("Expected keyspace \(keyspace) was not created by migration version 0")
    }
  }

  /// Generate the state table if it does not exist.
  func generateStateTable(
    migrationState: InstalledMigrationState,
    fileMigrations: [MigrationFile]
  ) async throws {
    _ = try await serialConsistencyClient.query("""
    CREATE TABLE \(keyspace).\(stateTable) (
      rank int PRIMARY KEY,
      version int,
      description text,
      file text,
      hash text,
      installed timestamp,
      duration int
    )
    """)

    // Sanity check that migration 0 created the correct keyspace
    let newState = try await detectMigrationState()
    guard newState.stateTable == stateTable else {
      throw MigrationEngineError.incorrectKeyspace("Expected state table \(keyspace).\(stateTable) but it was not created properly")
    }
  }

  func verifyHistoricalHashes(
    migrationState: InstalledMigrationState,
    fileMigrations: [MigrationFile]
  ) throws {
    // Get the max version installed in the keyspace
    guard let maxVersion = migrationState.migrations?.last?.version else {
      return
    }

    printVerbose?("Verifying migration hashes through version \(maxVersion)")

    try fileMigrations.filter { $0.version > 0 && $0.version <= maxVersion }.forEach { fileMigration in
      guard let installedMigration = migrationState.migrations?.first(where: { $0.version == fileMigration.version }) else {
        throw MigrationEngineError.migrationMismatch("File migration version \(fileMigration.version) does not exist in the state table.")
      }

      guard installedMigration.hash == fileMigration.hash else {
        throw MigrationEngineError.migrationMismatch("File migration version \(fileMigration.version) hash [\(fileMigration.hash)] does not match state table hash [\(installedMigration.hash)]")
      }
    }

    printInfo?("Verified migration hashes through version \(maxVersion)")
  }

  func installNewMigrations(
    migrationState: InstalledMigrationState,
    fileMigrations: [MigrationFile]
  ) async throws {
    // Get the max version installed in the keyspace.  We can default to 0
    // which is the reserved version for keyspace creation (and will not be
    // a part of any migration here.)
    let maxVersion = migrationState.migrations?.last?.version ?? 0
    let maxRank = migrationState.migrations?.last?.rank ?? 0

    // Get the list of migrations to install (already in version order)
    let toBeInstalled = fileMigrations.filter { $0.version > maxVersion }

    guard !toBeInstalled.isEmpty else {
      printInfo?("No migrations to run (keyspace is already at version \(maxVersion))")
      return
    }

    var nextRank = maxRank + 1
    for migration in toBeInstalled {
      guard !migration.file.contains("$$") else {
        throw MigrationEngineError.invalidFileMetadata("Migration Version \(migration.version) cannot have $$ in its filename: \(migration.file)")
      }

      guard !migration.description.contains("$$") else {
        throw MigrationEngineError.invalidFileMetadata("Migration Version \(migration.version) cannot have $$ in its description: \(migration.description)")
      }

      // We may need a different client for this invocation if the metadata
      // differs from the basic one.
      var invocationClient = client
      var usingTransientClient = false
      let migrationMetadata = migration.contents.extractInternalMetadata()
      if let migrationConsistencyString = migrationMetadata?.consistency {
        guard let resolved = migrationConsistencyString.cassandraConsistency else {
          throw MigrationEngineError.invalidConfig("Migration Version \(migration.version) consistency \(migrationConsistencyString) is invalid")
        }

        if resolved != clientConfig.consistency {
          var invocationConfig = clientConfig
          invocationConfig.consistency = resolved
          invocationClient = CassandraClient(configuration: invocationConfig)
          usingTransientClient = true
        }
      }

      // Execute the invocation
      let startTime = Date()
      do {
        _ = try await invocationClient.query(
          migration.contents.replacingOccurrences(
            of: kKeyspacePlaceholder,
            with: keyspace
          )
        )
      } catch {
        printInfo?("Error in migration version \(migration.version):")
        throw MigrationEngineError.migrationError(error.localizedDescription)
      }
      let duration = Int(Date().timeIntervalSince(startTime))

      if usingTransientClient {
        try? invocationClient.shutdown()
      }

      printInfo?("Migration \(migration.version) Successful - \(migration.description) - \(duration)s")

      // Update our state table
      _ = try await anyConsistencyClient.query("""
        INSERT INTO \(keyspace).\(stateTable)(rank, version, description, file, hash, installed, duration)
        VALUES (
          \(nextRank),
          \(migration.version),
          $$\(migration.description)$$,
          $$\(migration.file)$$,
          $$\(migration.hash)$$,
          toTimestamp(now()),
          \(duration)
        ) IF NOT EXISTS
      """)

      nextRank += 1

      // Delay for the invocationDelay period
      let delayTime = migrationMetadata?.invocationDelay ?? config.migration?.invocationDelay ?? 0
      if delayTime > 0 {
        try await Task.sleep(nanoseconds: UInt64(delayTime) * 1_000_000_000)
      }
    }
  }
}
