Overview
--------

Hastur is a new monitoring system focused on removing any barriers to entry
for engineers who need their systems monitored. Many of the components are
built from existing open source projects, making Hastur mostly a new way
to (not) manage monitoring configuration. The communication and most points
of scalability are built on top of ZeroMQ, allowing the client daemon to be
thin and simple.

Components
----------

* hastur-client.rb
* hastur-router.rb

(in progress)

* hastur-sink-stats-to-graphite.rb
* hastur-sink-to-file.rb (can sink most routes)

(planned)

* hastur-sink-to-cassandra.rb

(testing only)

* zmqcli.rb

Architecture
------------

Development
-----------

Install ZeroMQ & bundle install from the root directory. Look at the integration specs in tests/integration-*.json.

Dependencies
------------

* Ruby 1.9.3 (1.9.2 probably works)
* ZeroMQ 2.x (2.2.11) or 3.1.x
* Gems in Gemfile

Deployment
----------

TBD, probably puppet + fezzik