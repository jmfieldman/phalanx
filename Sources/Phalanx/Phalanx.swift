import ArgumentParser
import Foundation
import PhalanxLib

enum PhalanxAction: String, ExpressibleByArgument {
  case clean
  case migrate
}

// MARK: - Main

@main
struct Phalanx: AsyncParsableCommand {
  // MARK: Params - General

  @Flag(name: .shortAndLong, help: "Include verbose output")
  var verbose = false

  @Flag(name: .shortAndLong, help: "Squash all non-error output")
  var quiet = false

  @Option(name: .long, help: "The relative directory path to the migration scripts.")
  var migrationDirectory: String? = nil

  @Option(name: .long, help: "The string prefixing the version number of the migration file (e.g. 'v').")
  var migrationFilePrefix: String? = nil

  @Option(name: .long, help: "The string separating the version number and the description (default: -).")
  var migrationFileSeparator: String?

  @Option(name: .long, help: "The file extension to accept when searching for migrations (default: cql).")
  var migrationFileExtension: String?

  @Option(name: .long, help: "The name of the table that contains the phalanx state. This table is generated if not already present (default: phalanx_state).")
  var phalanxStateTable: String?

  @Option(name: [.customShort("d"), .long], help: "The artificial delay, in seconds, to insert between version invocations.")
  var invocationDelay: Int?

  @Flag(name: .long, help: "Use this flag to prevent checking that the historical file migrations still have matching SHA256 hashes as what is recorded in the state table.")
  var ignoreHistoricalHashes: Bool = false

  // MARK: Params - Client Config

  @Option(name: .customLong("host"), help: "The host used to issue migration commands to. This parameter can be used multiple times to add additional hosts.")
  var hosts: [String] = []

  @Option(name: .shortAndLong, help: "The port used to connect to the host.")
  var port: Int?

  @Option(name: .long, help: "The protocol version to use (1-5).")
  var protocolVersion: Int?

  @Option(name: .shortAndLong, help: "The username to use.")
  var username: String?

  @Option(name: .long, help: "The password to use.")
  var password: String?

  @Option(name: .shortAndLong, help: "The keyspace to use.")
  var keyspace: String?

  @Option(name: .long, help: "The consistency to use for each invocation (default: serial).")
  var consistency: String?

  // MARK: Params - Config File

  @Option(name: [.customShort("f"), .customLong("config")], help: "The relative filepath to the config file to use")
  var configPath: String = "phalanx.yml"

  // MARK: Params - Action Argument

  @Argument(help: "The action to take. clean = drop the entire keyspace; migrate = perform migration")
  var action: PhalanxAction

  // MARK: run

  mutating func run() async throws {
    // Load file-based config, if available
    let configFromFile = try Config.from(path: configPath)
    if configFromFile != nil {
      printVerbose("Found config file: \(configPath)")
    }

    // Generate config with parameter overrides
    let config = Config(
      client: Config.Client(
        hosts: (hosts.isEmpty ? nil : hosts) ?? configFromFile?.client?.hosts,
        port: port ?? configFromFile?.client?.port,
        protocolVersion: protocolVersion ?? configFromFile?.client?.protocolVersion,
        keyspace: keyspace ?? configFromFile?.client?.keyspace,
        username: username ?? configFromFile?.client?.username,
        password: password ?? configFromFile?.client?.password,
        consistency: consistency ?? configFromFile?.client?.consistency ?? "serial"
      ),
      phalanxStateTable: phalanxStateTable ?? configFromFile?.phalanxStateTable ?? "phalanx_state",
      migration: Config.Migration(
        invocationDelay: invocationDelay ?? configFromFile?.migration?.invocationDelay ?? 0,
        directory: migrationDirectory ?? configFromFile?.migration?.directory,
        fileSeparator: migrationFileSeparator ?? configFromFile?.migration?.fileSeparator ?? "-",
        filePrefix: migrationFilePrefix ?? configFromFile?.migration?.filePrefix,
        fileExtension: migrationFileExtension ?? configFromFile?.migration?.fileExtension ?? "cql",
        ignoreHistoricalHashes: (ignoreHistoricalHashes ? ignoreHistoricalHashes : nil) ?? configFromFile?.migration?.ignoreHistoricalHashes ?? false
      )
    )

    printVerbose("Resolved configuration:")
    printVerbose(config.toYAML())

    // Create engine
    let engine = try MigrationEngine(
      config: config,
      printInfo: printInfo,
      printVerbose: printVerbose
    )

    // Capture current migration state
    let migrationState = try await engine.detectMigrationState()

    switch action {
    case .clean:
      // The clean action is relatively simple. Just drop the keyspace if
      // it exists.
      guard let keyspace = migrationState.keyspace else {
        printInfo("No action for clean; keyspace [\(config.client?.keyspace ?? "--")] does not exist.")
        return
      }

      try await engine.dropKeyspace()
      printInfo("Clean succeeded; Keyspace [\(keyspace)] dropped")
      return
    case .migrate:
      let fileMigrations = try engine.detectFileMigrations()

      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }
  }

  // MARK: - Output Handlers

  lazy var printVerbose: (String) -> Void = { [verbose, quiet] str in
    if verbose, !quiet { print(str) }
  }

  lazy var printInfo: (String) -> Void = { [quiet] str in
    if !quiet { print(str) }
  }

  /// Use this to write generic text to stderr. Use
  /// `exit(withError:)` to terminate the process with an error.
  lazy var printError: (String) -> Void = { str in
    try! FileHandle.standardError.write(contentsOf: str.data(using: .utf8) ?? Data())
  }
}
