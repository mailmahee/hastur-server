#!/bin/bash

# generate the schema

print_schema () {
  table=$1

  echo "
create column family $table
  with column_type = 'Standard'
  and comparator = 'BytesType(reversed=true)'
  and default_validation_class = 'BytesType'
  and key_validation_class = 'BytesType'
  and caching = 'KEYS_ONLY'
  and read_repair_chance = 0.1
  and gc_grace = 5184000
  and replicate_on_write = true
  and compaction_strategy = 'org.apache.cassandra.db.compaction.LeveledCompactionStrategy'
  and compaction_strategy_options={'sstable_size_in_mb': 256}
  and bloom_filter_fp_chance = 0.5
  and compression_options = {'sstable_compression': 'org.apache.cassandra.io.compress.SnappyCompressor'};
"
}

echo "
create keyspace hastur
  with placement_strategy = 'SimpleStrategy'
  and strategy_options = {replication_factor : 3}
  and durable_writes = true;

use hastur;
"

for table in gauge_archive counter_archive mark_archive compound_archive counter_value gauge_value mark_value compound_value
do
  print_schema $table
done

for table in log_archive error_archive event_archive
do
  print_schema $table
done

for table in hb_agent_archive hb_process_archive reg_agent_archive reg_process_archive info_process_archive info_agent_archive info_ohai_archive
do
  print_schema $table
done

for table in hb_process hb_agent
do
  print_schema $table
done

for table in counter_rollup gauge_rollup mark_rollup compound_rollup hb_agent_rollup hb_process_rollup
do
  print_schema $table
done

for table in gauge_metadata counter_metadata mark_metadata compound_metadata log_metadata error_metadata event_metadata hb_agent_metadata hb_process_metadata reg_agent_metadata reg_process_metadata info_process_metadata info_agent_metadata info_ohai_metadata
do
  print_schema $table
done

for table in registration_day lookup_by_key
do
  print_schema $table
done
