import Foundation
@testable import PhalanxLib
import XCTest

final class MigrationTests: MigrationTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  /// Verify that a basic migration works as exepcted
  func testBasicMigration() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestGoodMigrationPhase1")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // At this point phase 1 migration is complete and the first table should be present
    try runAsyncAndWaitFor { [testClient, keyspace] in
      _ = try await testClient.query("DESC \(keyspace).some_name_table")
    }

    // But we would expect the second table to not be present yet
    XCTAssertThrowsError(
      try runAsyncAndWaitFor { [testClient, keyspace] in
        _ = try await testClient.query("DESC \(keyspace).some_name_table2")
      }
    )

    // Now we load up phase 2!
    var config2 = try Config.from(path: pathTo(config: "simple_local.yml"))
    config2?.migration?.directory = pathTo(migrations: "TestGoodMigrationPhase2")
    XCTAssertNotNil(config2)

    let engine2 = try MigrationEngine(config: config2!)
    let migrationState2 = try runAsyncAndWaitFor { try await engine2.detectMigrationState() }
    let fileMigrations2 = try engine2.detectFileMigrations()

    try runAsyncAndWaitFor {
      try await engine2.executeMigration(
        migrationState: migrationState2,
        fileMigrations: fileMigrations2
      )
    }

    // We expect that we now see both tables
    try runAsyncAndWaitFor { [testClient, keyspace] in
      _ = try await testClient.query("DESC \(keyspace).some_name_table")
      _ = try await testClient.query("DESC \(keyspace).some_name_table2")
    }

    try dropKeyspace()
  }
  
  /// Verify that a basic migration works as exepcted
  func testKeyspacePlaceholder() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestKeyspacePlaceholder")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // At this point phase migration is complete and the first table should be present
    try runAsyncAndWaitFor { [testClient, keyspace] in
      _ = try await testClient.query("DESC \(keyspace).some_name_table")
    }

    try dropKeyspace()
  }
}
