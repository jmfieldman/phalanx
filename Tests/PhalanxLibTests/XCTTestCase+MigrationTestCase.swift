import CassandraClient
import Foundation
@testable import PhalanxLib
import XCTest

class MigrationTestCase: XCTestCase {
  let keyspace = "phalanx_test_keyspace"
  let stateTable = "phalanx_state"

  let testClientConfig = CassandraClient.Configuration(
    contactPointsProvider: { $0(.success(["127.0.0.1"])) },
    port: 9042,
    protocolVersion: .v4
  )

  lazy var testClient = CassandraClient(configuration: testClientConfig)

  override func setUp() {
    super.setUp()

    XCTAssertNoThrow(try dropKeyspace())
  }

  override func tearDown() {
    super.tearDown()

    XCTAssertNoThrow(try dropKeyspace())
    try? testClient.shutdown()
  }

  func checkKeyspace() throws -> Bool {
    do {
      _ = try runAsyncAndWaitFor { [testClient, keyspace] in
        try await testClient.query("DESC KEYSPACE \(keyspace)")
      }
    } catch {
      return false
    }
    return true
  }

  func dropKeyspace(throwIfMissing: Bool = false) throws {
    do {
      try runAsyncAndWaitFor { [weak self] in try await self?.dropKeyspaceInternal() }
    } catch {
      if throwIfMissing {
        throw error
      }
    }
  }

  private func dropKeyspaceInternal() async throws {
    _ = try await testClient.query("DROP KEYSPACE \(keyspace)")
  }
}
