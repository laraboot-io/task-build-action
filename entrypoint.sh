#!/usr/bin/env bash

set -eu
set -o pipefail

echo "Arg0?:= $1"
echo "directory?:= $2"

readonly task_directory="$2"

time=$(date)
echo "::set-output name=time::$time"

pushd $task_directory
/src/scripts/main.sh
popd > /dev
