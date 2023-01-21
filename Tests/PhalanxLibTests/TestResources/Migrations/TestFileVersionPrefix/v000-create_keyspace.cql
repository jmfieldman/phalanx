CREATE KEYSPACE IF NOT EXISTS
  phalanx_test_keyspace
WITH REPLICATION = {
  'class' : 'SimpleStrategy',
  'replication_factor' : 1
}
