import Foundation
@testable import PhalanxLib
import XCTest

// MARK: - Resource Helpers

extension XCTestCase {
  var relativeResourcePath: String {
    String(Bundle.module.resourcePath!
      .replacingOccurrences(of: FileManager.default.currentDirectoryPath, with: "")
      .dropFirst())
  }

  func pathTo(config: String) -> String {
    "\(relativeResourcePath)/TestResources/Configs/\(config)"
  }

  func pathTo(migrations: String) -> String {
    "\(relativeResourcePath)/TestResources/Migrations/\(migrations)"
  }
}

// MARK: - runAsyncAndWaitFor

private var responseStore: [UUID: Any] = [:]
private var errorStore: [UUID: Error] = [:]

extension XCTestCase {
  func runAsyncAndWaitFor<T>(_ closure: @escaping () async throws -> T, _ timeout: TimeInterval = 3.0) throws -> T {
    let finished = expectation(description: "finished")
    let testUUID = UUID()
    Task.detached {
      do {
        responseStore[testUUID] = try await closure()
      } catch {
        errorStore[testUUID] = error
      }
      finished.fulfill()
    }
    wait(for: [finished], timeout: timeout)
    if let innerError = errorStore[testUUID] {
      throw innerError
    }

    return responseStore[testUUID]! as! T
  }
}
