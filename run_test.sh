#!/bin/bash

# run_test.sh

if [ "$#" -ne 2 ]; then
    echo "Usage: run_test.sh <metric> <value>"
    exit 1
fi

METRIC=$1
VALUE=$2

# Build builder
echo "Building builder"

sed -i '/esp/Id' builder/Dockerfile  # Speedup build removing ESP-IDF from the builder
sed -i '/idf/Id' builder/Dockerfile
sed -i '/snap/Id' builder/Dockerfile # Snap also slows down the build

builder/build.sh

if [ $? -ne 0 ]; then
    echo "Building builder failed, skipping commit"
    exit 125
fi

# Build docker image
echo "Building docker image"
platforms/docker/build.sh amd64 stable

if [ $? -ne 0 ]; then
    echo "Building docker image failed, skipping commit"
    exit 125
fi

# Run the test
HUSARNET_VERSION="dev"

function husarnet_server () {
    HUSARNET_VERSION=${HUSARNET_VERSION} docker compose exec husarnet-server "${@}"
}
function husarnet_client () {
    HUSARNET_VERSION=${HUSARNET_VERSION} docker compose exec husarnet-client "${@}"
}
function iperf_client () {
    HUSARNET_VERSION=${HUSARNET_VERSION} docker compose exec iperf-client "${@}"
}

function compose() {
    HUSARNET_VERSION=${HUSARNET_VERSION} docker compose $@
}

compose up --remove-orphans -d

echo "Compose up done, preparing images"

husarnet_server bash -c "apt-get -qq update && apt-get -qq install iputils-ping jq"
husarnet_client bash -c "apt-get -qq update && apt-get -qq install iputils-ping jq"

echo "Image preparation done, starting functional tests"

server_ip=$(husarnet_server bash -c "cat /var/lib/husarnet/id | cut -d ' ' -f 1")
client_ip=$(husarnet_client bash -c "cat /var/lib/husarnet/id | cut -d ' ' -f 1")

husarnet_server husarnet daemon whitelist add ${client_ip} > /dev/null
husarnet_client husarnet daemon whitelist add ${server_ip} > /dev/null

echo "Functional tests done, starting benchmark"

iperf_result=$(iperf_client iperf3 -c ${server_ip} --json)
rx=$(echo ${iperf_result} | jq -r '.end.sum_received.bits_per_second')
tx=$(echo ${iperf_result} | jq -r '.end.sum_sent.bits_per_second')

rx=$(echo "scale=2; ${rx} / 1000000" | bc)
tx=$(echo "scale=2; ${tx} / 1000000" | bc)

husarnet version
echo "RX: ${rx} Mbps, TX: ${tx} Mbps"

# Clean up
git reset --hard > /dev/null
compose down --remove-orphans > /dev/null

# Test if the throughput satifies the expected value
if [ $(echo "${rx} < ${VALUE}" | bc) -eq 1 ] || [ $(echo "${tx} < ${VALUE}" | bc) -eq 1 ]; then
    echo "Bad commit"
    exit 1
else
    echo "Good commit"
    exit 0
fi