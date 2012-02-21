#!/usr/bin/env ruby

require "trollop"
require "hastur/sink/cassandra_schema"
require "time"

opts = Trollop.options do
  opt :n,       "Number to insert per batch",   :default => 1,                     :type => :int
  opt :batches, "Number of batches to insert",  :default => 1,                     :type => :int
  opt :delay,   "Delay between batches",        :default => 0.1,                   :type => Float
  opt :types,   "Types to insert",              :default => ["gauge"],             :type => :strings
  opt :names,   "Names to insert",              :default => ["test-stat"],         :type => :strings
  opt :tags,    "Tags to mark as",              :default => ["tag1"],              :type => :strings
  opt :print,   "Print messages",               :default => false,                 :type => :boolean
  opt :insert,  "Write messages to C*",         :default => true,                  :type => :boolean
  opt :keyspace,"Keyspace to write",            :default => "Hastur",              :type => String
  opt :host,    "Cassandra host",               :default => "127.0.0.1:9160",      :type => String
end

client = Cassandra.new(opts[:keyspace], opts[:host])

opts[:batches].times do |batch|
  opts[:n].times do |i|
    type = opts[:types].sample
    name = opts[:names].sample
    value = rand() * rand() * 1000.0
    message = <<EOM
  {
    "uuid": "a6-a6-a6-a6-a6-a6-a6",
    "type": "#{type}",
    "name": "#{name}",
    "value": #{value},
    "timestamp": #{(Time.now.to_f * 1_000_000.0).to_i},
    "tags": {
  #{opts[:tags].map { |s| "    \"#{s}\": 1" }.join(",\n")}
    }
  }
EOM

    puts "Generated stat:\n#{message}" if opts[:print]
    Hastur::Cassandra.insert_stat(client, message) if opts[:insert]
  end

  # Sleep, except on the last batch
  sleep opts[:delay] unless (batch + 1) == opts[:batches]
end
