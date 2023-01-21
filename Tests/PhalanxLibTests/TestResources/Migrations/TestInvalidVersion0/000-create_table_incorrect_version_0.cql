-- This is an incorrect version 0 migration.
-- Version 0 migrations may only contain the
-- correct CREATE KEYSPACE invocation to
-- create an initial keyspace if required.

CREATE TABLE phalanx_test_keyspace.some_name_table (
  id UUID PRIMARY KEY,
  name text
);
