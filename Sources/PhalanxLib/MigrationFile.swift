import Foundation

public struct MigrationFile: Codable, Equatable {
  let file: String
  let version: Int
  let description: String
  let contents: String
  let hash: String
}

public enum MigrationFileError: Error, Equatable {
  case fileNotFound(String)
  case fileNameNotDetected(String)
}

public extension MigrationFile {
  /// Generates a `MigrationFile` instance from a file at the
  /// specified relative `path`.
  ///
  /// The function requires that the file name has already been
  /// parsed for version and file name description.
  ///
  /// The function does not do any other validation, but it will
  /// interrogate the contents the file for an internal description
  /// string.
  static func from(
    path: String,
    version: Int,
    fileNameDescription: String
  ) throws -> MigrationFile? {
    guard FileManager.default.fileExists(atPath: path) else {
      throw MigrationFileError.fileNotFound(path)
    }

    guard let file = path.split(separator: "/").last.flatMap(String.init) else {
      throw MigrationFileError.fileNameNotDetected(path)
    }

    let contents = try String(contentsOfFile: path)
    let internalMetadata = contents.extractInternalMetadata()

    return MigrationFile(
      file: file,
      version: version,
      description: internalMetadata?.description ?? fileNameDescription,
      contents: contents,
      hash: contents.sha256
    )
  }
}
