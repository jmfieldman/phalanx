import Foundation
@testable import PhalanxLib
import XCTest

final class NegativeKeyspaceCreationTests: MigrationTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  /// Verify that the version-0 migration contains a valid CREATE KEYSPACE
  /// invocation.
  func testThrowOnIncorrectVersion0() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestInvalidVersion0")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    XCTAssertThrowsError(
      try runAsyncAndWaitFor {
        try await engine.executeMigration(
          migrationState: migrationState,
          fileMigrations: fileMigrations
        )
      }
    ) { error in
      XCTAssertEqual(error as! MigrationEngineError, MigrationEngineError.noKeyspaceMigration("Keyspace creation migration (version 0) requires a CREATE KEYSPACE command."))
    }
  }

  /// Verify that if the keyspace needs to be created that the version-0
  /// migration exists.
  func testThrowOnMissingVersion0() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestMissingVersion0")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    XCTAssertThrowsError(
      try runAsyncAndWaitFor {
        try await engine.executeMigration(
          migrationState: migrationState,
          fileMigrations: fileMigrations
        )
      }
    ) { error in
      XCTAssertEqual(error as! MigrationEngineError, MigrationEngineError.noKeyspaceMigration("Keyspace \(keyspace) is missing and requires a reserved version 0 migration to create."))
    }
  }
}
