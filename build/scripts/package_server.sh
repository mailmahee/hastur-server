#!/bin/bash

# This builds a deployable file to copy to the Hastur core/retrieval servers.
# Run it from root of hastur-server project by calling bin/package_server.sh.

rm -rf build/server
rm build/jars/*
rm -rf server_package.tar*
mkdir build/server

cp build/scripts/install_server.sh build/server/

# Linux 64-bit ZeroMQ
cp build/binaries/libzmq* build/server/

# Build jars, copy into build/server/
rm -f jars/*.?ar
mkdir -p build/server
bundle exec rake core_jar || exit -1
mv build/jars/core.jar build/server/
bundle exec rake retrieval_war || exit -1
mv build/jars/retrieval_v2.war build/server/

# Hastur Core scripts
cp build/scripts/hastur-core.conf build/server/
cp bin/start_core.sh build/server/

# Hastur Retrieval v2 scripts
cp build/scripts/hastur-retrieval.conf build/server/
cp bin/start_retrieval.sh build/server/

# Manually-runnable removal scripts for old versions
cp build/scripts/remove*.sh build/server/

tar jcvf server_package.tar.bz2 build/server

rm -rf build/server
