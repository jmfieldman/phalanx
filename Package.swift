// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "phalanx",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .executable(name: "phalanx", targets: ["Phalanx"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-cassandra-client.git", from: "0.2.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "2.2.4"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "Phalanx",
      dependencies: [
        "PhalanxLib",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(
      name: "PhalanxLib",
      dependencies: [
        .product(name: "CassandraClient", package: "swift-cassandra-client"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Yams", package: "Yams"),
      ]
    ),
    .testTarget(
      name: "PhalanxLibTests",
      dependencies: [
        "PhalanxLib",
        .product(name: "CassandraClient", package: "swift-cassandra-client"),
      ],
      resources: [
        .copy("TestResources"),
      ]
    ),
  ]
)
