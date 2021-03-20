#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOTDIR="$(cd "${PROGDIR}/.." && pwd)"

function main() {
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
    --help | -h)
      shift 1
      usage
      exit 0
      ;;

    "")
      # skip if the argument is empty
      shift 1
      ;;

    *)
      echo "Error: unknown argument \"${1}\""
      ;;
    esac
  done

  echo "ECR_REGISTRY=$ECR_REGISTRY"

  cmd::build_and_push
}

function usage() {
  cat <<-USAGE
build.sh [OPTIONS]

Builds the buildpack executables.

OPTIONS
  --help  -h  prints the command usage
USAGE
}

function cmd::build_and_push() {

  : ${IMAGE_TAG:=dev}

  pushd $ROOTDIR
  docker build -t task-builder:$IMAGE_TAG .
  docker tag task-builder:$IMAGE_TAG $ECR_REGISTRY/task-builder:$IMAGE_TAG
  docker push $ECR_REGISTRY/task-builder:$IMAGE_TAG
  popd

}

main "${@:-}"
