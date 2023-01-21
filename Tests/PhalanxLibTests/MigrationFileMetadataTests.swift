import Foundation
@testable import PhalanxLib
import XCTest

final class MigrationFileMetadataTests: MigrationTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  /// Verify that we actually use the description from the internal metadata
  func testUseDescriptionFromFile() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestMigrationMetadata")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    var migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }
    let fileMigrations = try engine.detectFileMigrations()

    try runAsyncAndWaitFor {
      try await engine.executeMigration(
        migrationState: migrationState,
        fileMigrations: fileMigrations
      )
    }

    // Reload state after migration
    migrationState = try runAsyncAndWaitFor { try await engine.detectMigrationState() }

    XCTAssertEqual(migrationState.migrations![0].description, "this is a different description")

    try dropKeyspace()
  }

  /// Verify that we reject file names with $$ in them
  func testRejectBadFilenames() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFailedMigrationMetadataFilename")
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
      XCTAssertEqual(
        error as! MigrationEngineError,
        MigrationEngineError.invalidFileMetadata(
          "Migration Version 1 cannot have $$ in its filename: 001-create_table$$.cql"
        )
      )
    }

    try dropKeyspace()
  }

  /// Verify that we reject file descriptions with $$ in them
  func testRejectBadDescriptions() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFailedMigrationMetadataDescription")
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
      XCTAssertEqual(
        error as! MigrationEngineError,
        MigrationEngineError.invalidFileMetadata(
          "Migration Version 1 cannot have $$ in its description: this is a description with $$ in it"
        )
      )
    }

    try dropKeyspace()
  }

  func testAllMigrationFileInternalPropertiesDash() {
    let test = """
    -- metadata:
    --   invocationDelay: 3
    --   description: test desc
    --   consistency: all
    """

    let metadata = test.extractInternalMetadata()

    XCTAssertEqual(metadata?.invocationDelay, 3)
    XCTAssertEqual(metadata?.description, "test desc")
    XCTAssertEqual(metadata?.consistency, "all")
  }

  func testAllMigrationFileInternalPropertiesSlash() {
    let test = """
    // metadata:
    //   invocationDelay: 3
    //   description: test desc
    //   consistency: all
    """

    let metadata = test.extractInternalMetadata()

    XCTAssertEqual(metadata?.invocationDelay, 3)
    XCTAssertEqual(metadata?.description, "test desc")
    XCTAssertEqual(metadata?.consistency, "all")
  }

  func testMigrationFileInternalPropertiesEndAtNewline() {
    let test = """
    -- metadata:
    --   invocationDelay: 3
    --   description: test desc

    --   consistency: all

    CREATE TABLE foo
    """

    let metadata = test.extractInternalMetadata()

    XCTAssertEqual(metadata?.invocationDelay, 3)
    XCTAssertEqual(metadata?.description, "test desc")
    XCTAssertNil(metadata?.consistency)
  }

  func testMigrationFileInternalPropertiesNoBeginningNewline() {
    let test = """

    -- metadata:
    --   invocationDelay: 3
    --   description: test desc

    --   consistency: all

    CREATE TABLE foo
    """

    let metadata = test.extractInternalMetadata()

    XCTAssertNil(metadata)
  }
}
