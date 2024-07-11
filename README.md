# husarnet_bisect

Quick and dirty script to bisect Husarnet releases, currently only throughput test is supported. It will automatically build Husarnet Docker container and corresponding builder for each tested release.

## Usage

```bash
./bisect.sh <from_good_commit> <to_bad_commit> throughput <value_in_Mbps>
```