![Phalanx](bin/img/phalanx_title.png)

Phalanx is a **Cassandra Migration utility written in Swift**, with ergonimics inspired by flyway.

### Motivation

There are other Cassandra migration tools written in Java and Python.

Phalanx is geared for developers already writing a Swift backend/microservice, who might
like to stay within the scope of a familiar toolchain/ecosystem.

Phalanx is based on [Apple's open source Cassandra client library](https://github.com/apple/swift-cassandra-client)

### Installation

#### Swift Package Manager

Add Phalanx to your own Package.swift:

```swift
.package(url: "https://github.com/jmfieldman/phalanx.git", from: "1.0.0")
```

Swift PM will automatically detect the executable target, so you can now run the _phalanx_ executable through your own package:

```bash
$ swift run phalanx ...
```

#### Standalone (Mint)

If Phalanx has dependency conflicts with your project, or you simply want a more
streamlined execution experience, try installing Phalanx using the very nice [Mint Package Manager](https://github.com/yonaskolb/Mint).

Mint builds each Swift executable in its own environment, tracks versions, and supports localized version-pegging through a Mintfile. This avoids continuous, unnecessary rebuild-checks when your own project's Package.swift changes.

```bash
# Install mint on your system, e.g.
$ brew install mint

# Install Phalanx
$ mint install jmfieldman/phalanx

# Run Phalanx using Mint. This is the recommended method if you plan
# on using a Mintfile for version-pegging
$ mint run phalanx <..>

# Or run it directly if you have the Mint bin directory in your path
$ phalanx <..>
```

### Usage

Phalanx offers two basic functions: `clean` and `migrate`.

```bash
# Phalanx will use the keyspace associated
# with the command to `DROP KEYSPACE <keyspace>`
$ phalanx clean

# Phalanx will use the detected migration files to bring your
# keyspace up to the most recent version.
$ phalanx migrate
```

### Configuration

Phalanx is typically configured using a config file. Details of
the available configuration options, including all of the command-line
overrides, are available in the [Example Configuration](/Examples/Config/phalanx_example.yml)

```bash
# Phalanx looks for phalanx.yml by default, but you can override
# that with the --config parameter, e.g.
$ phalanx --config conf/phalanx.yml migrate
```

All configuration can be set using command line options as well; use
help for reference:

```bash
$ phalanx --help
```

### Migration Files

Migration files should all be grouped into a single directory. Phalanx will
interrogate the contents of the migration directory for any files that look
like migrations.

You can configure the file prefix, extension, and version-description
separator that define a migration's file name structure.

An example file listing might look like:

```bash
# Prefix = null
# Separatpr = "-"
# Extension = "cql"

$ ls
000-create_keyspace.cql
001-create_user_table.cql
002-add_password_column_to_users.cql
003-create_device_table.cql
README.md # This file will be ignored as it does not match migration patterns
```

Migration files can contain their own unique metadata that affects
just their specific invocation. This metadata must be included at the top
of the migration file. It is formatted as CQL-commented YAML:

```sql
-- metadata:
--   description: This overrides the filename-based description
--   invocationDelay: <int> # Overrides the global invocation delay
--   consistency: <string> # Overrides the global consistency config

CREATE TABLE ...
```

Ensure that an empty line is present after the metadata to end YAML parsing.

### Important Concepts

**_One Keyspace Per Phalanx Invocation_**

Any given Phalanx invocation will only operate on the _single keyspace_
defined in the config or command line. If you want to setup migrations
for multiple keyspaces they will need to be in isolated directories,
and you will need to invoke Phalanx separately for each independent keyspace.

**_Migration 0 is Reserved for Keyspace Creation_**

Phalanx expects that initial migrations start with a blank slate, and that no
keyspace is ready before migration 0. Since keyspace creation can involve complex custom
parameters, Phalanx reserves migration 0 for keyspace creation.

This means that the migration tagged version 0 (e.g. `000-create_keyspace.cql`)
_may only contain a command that starts with `CREATE KEYSPACE`_.

If you do not want Phalanx to be responsible for keyspace creation, you can
create the keyspace yourself, and begin migration files with version 1. Phalanx will
throw an error if the keyspace does not exist and you are missing version 0.

**_Migration Files can only Contain One Command Each_**

Because Cassandra doesn't have traditional multi-command transactions, it isn't
safe to put multiple commands in a single migration version.  If, say, a migration
file contained 10 commands and the 5th one failed, there would be no clean way to
record that a certain migration file was "half complete".

We can insure that individual commands are successful, and locked into the state table,
by restricting migration files to one command each.

### Unit Tests

Phalanx has a suite of unit tests that can be run from the command line:

```bash
$ swift test
```

The tests expect a Cassandra node available at 127.0.0.1:9042, and will operate
on the `phalanx_test_keyspace` keyspace (dropping and creating it several times.)