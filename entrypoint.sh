#!/usr/bin/env bash

set -eu
set -o pipefail

echo "Arg0?:= $1"
time=$(date)
echo "::set-output name=time::$time"

if [ -f ./scripts/main.sh ]; then
  ./scripts/main.sh
fi
