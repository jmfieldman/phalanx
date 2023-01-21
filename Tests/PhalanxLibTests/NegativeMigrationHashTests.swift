import Foundation
@testable import PhalanxLib
import XCTest

final class NegativeMigrationHashTests: MigrationTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  /// Verify that migration inconsistency detection is not performed when
  /// it is disabled at the config level
  func testNoThrowWhenAHashIsIncorrectButDisabled() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestNegativeMigrationHashes")
    config?.migration?.ignoreHistoricalHashes = true
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    var migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    // Setup the migration correctly
    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // Modify hash
    try runAsyncAndWaitFor { [testClient, keyspace, stateTable] in
      _ = try await testClient.query("UPDATE \(keyspace).\(stateTable) SET hash = 'sad' WHERE rank = 1")
    }

    // Reload migration state with the new incorrect hash
    migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }

    XCTAssertNoThrow(
      try runAsyncAndWaitFor {
        try await engine.executeMigration(
          migrationState: migrationState,
          fileMigrations: fileMigrations
        )
      }
    )

    try dropKeyspace()
  }

  /// Verify that migration detects an invalid hash
  func testThrowWhenAHashIsIncorrect() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestNegativeMigrationHashes")
    config?.migration?.ignoreHistoricalHashes = false
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    var migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    // Setup the migration correctly
    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // Modify hash
    try runAsyncAndWaitFor { [testClient, keyspace, stateTable] in
      _ = try await testClient.query("UPDATE \(keyspace).\(stateTable) SET hash = 'sad' WHERE rank = 1")
    }

    // Reload migration state with the new incorrect hash
    migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }

    XCTAssertThrowsError(
      try runAsyncAndWaitFor {
        try await engine.executeMigration(
          migrationState: migrationState,
          fileMigrations: fileMigrations
        )
      }
    ) { error in
      XCTAssertEqual(
        error as! MigrationEngineError,
        MigrationEngineError.migrationMismatch(
          "File migration version 1 hash [479389cd17434be7438a84270939b2d13a9ab89afc3f9f8bff30c942d8f33381] does not match state table hash [sad]"
        )
      )
    }

    try dropKeyspace()
  }

  /// Verify that migration detects a missing hash
  func testThrowWhenAHashIsMissing() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestNegativeMigrationHashes")
    config?.migration?.ignoreHistoricalHashes = false
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    var migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    // Setup the migration correctly
    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // Modify hash
    try runAsyncAndWaitFor { [testClient, keyspace, stateTable] in
      _ = try await testClient.query("DELETE FROM \(keyspace).\(stateTable) WHERE rank = 1")
    }

    // Reload migration state with the new incorrect hash
    migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }

    XCTAssertThrowsError(
      try runAsyncAndWaitFor {
        try await engine.executeMigration(
          migrationState: migrationState,
          fileMigrations: fileMigrations
        )
      }
    ) { error in
      XCTAssertEqual(
        error as! MigrationEngineError,
        MigrationEngineError.migrationMismatch(
          "File migration version 1 does not exist in the state table."
        )
      )
    }

    try dropKeyspace()
  }
}
