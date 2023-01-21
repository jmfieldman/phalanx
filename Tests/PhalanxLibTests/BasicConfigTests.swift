import Foundation
@testable import PhalanxLib
import XCTest

final class BasicConfigTests: XCTestCase {
  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  // MARK: - Loading Configs

  func testLoadSimpleConfig() throws {
    let configFromFile = try Config.from(path: pathTo(config: "simple_local.yml"))
    XCTAssertNotNil(configFromFile)
  }

  func testRepoExampleConfig() throws {
    let configFromFile = try Config.from(path: pathTo(config: "phalanx_example.yml"))
    XCTAssertNotNil(configFromFile)
  }

  func testLoadConfigNoFileReturnsNil() {
    XCTAssertNil(try Config.from(path: pathTo(config: "simple_local_DOES_NOT_EXIST.yml")))
  }

  func testLoadConfigParserError() {
    XCTAssertThrowsError(try Config.from(path: pathTo(config: "yml_parser_error.yml")))
  }

  func testVersionPrefixDetection() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFileVersionPrefix")
    config?.migration?.filePrefix = "v"
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 2)
  }

  func testIncorrectVersionPrefixIgnoresFiles() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestGoodMigrationPhase1")
    config?.migration?.filePrefix = "v"
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 0)
  }

  func testMissingVersionPrefixIgnoresFiles() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFileVersionPrefix")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 0)
  }

  func testSeparatorDetection() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFileSeperator")
    config?.migration?.fileSeparator = "+"
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 2)
  }

  func testIncorrectSeparatorIgnoresFiles() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestGoodMigrationPhase1")
    config?.migration?.filePrefix = "+"
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 0)
  }

  func testMissingSeparatorIgnoresFiles() throws {
    var config = try Config.from(path: pathTo(config: "simple_local.yml"))
    config?.migration?.directory = pathTo(migrations: "TestFileSeperator")
    XCTAssertNotNil(config)

    let engine = try MigrationEngine(config: config!)
    let fileMigrations = try engine.detectFileMigrations()
    XCTAssertEqual(fileMigrations.count, 0)
  }
}
