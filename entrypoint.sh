#!/usr/bin/env bash

set -eu
set -o pipefail

echo "Arg0?:= $1"
time=$(date)
echo "::set-output name=time::$time"

chmod +x ./scripts/main.sh
./scripts/main.sh