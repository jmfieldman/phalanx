CREATE KEYSPACE IF NOT EXISTS
  $${{KEYSPACE}}$$
WITH REPLICATION = {
  'class' : 'SimpleStrategy',
  'replication_factor' : 1
}
