import Foundation
@testable import PhalanxLib
import XCTest

final class BasicKeyspaceTests: MigrationTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  func testCreateKeyspaceFromInitialMigration() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestCreateKeyspace")
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

    XCTAssertTrue(try checkKeyspace())
  }
}
