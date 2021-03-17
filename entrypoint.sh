#!/usr/bin/env bash

set -eu
set -o pipefail

echo "args = $*"

time=$(date)
echo "::set-output name=time::$time"

#readonly task_directory="$2"
#pushd $task_directory
$BUILDER_HOME/scripts/main.sh
