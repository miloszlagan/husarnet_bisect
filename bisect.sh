#!/bin/bash

# bisect.sh
# This script is used to find offending commit in the Husarnet repository that introduced performance regression.

# Usage: bisect.sh <from_good_commit> <to_bad_commit>

GIT_REPOSITORY="https://github.com/husarnet/husarnet"

set -e

# Check if the number of arguments is correct
if [ "$#" -ne 4 ]; then
    echo "Usage: bisect.sh <from_good_commit> <to_bad_commit> throughput <value>"
    exit 1
fi

GOOD_COMMIT=$1
BAD_COMMIT=$2
METRIC=$3
VALUE=$4

# Clone the repository
if [ -d "repo" ]; then
    git -C repo reset --hard
    git -C repo fetch
    git -C repo checkout master
    git -C repo pull
else
    git clone $GIT_REPOSITORY repo
fi

# Start bisecting
cd repo
git bisect reset
git bisect start
git bisect good $GOOD_COMMIT
git bisect bad $BAD_COMMIT


# Run the test
git bisect run ../run_test.sh $METRIC $VALUE