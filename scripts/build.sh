#!/usr/bin/env bash

set -eu
set -o pipefail

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
      util::print::error "unknown argument \"${1}\""
      ;;
    esac
  done

  yq --version

  # We need jq also
  jq --version

  # Jam is optionally required, if found it will be used to pack the buildpack as a file
  #  jam -h

  cmd::go_pkg_assets
  cmd::go_generate
  cmd::go_build
  cmd::go_test
  cmd::go_package
  cmd::go_export
}

function usage() {
  cat <<-USAGE
main.sh [OPTIONS]

Builds the buildpack executables.

OPTIONS
  --help  -h  prints the command usage
USAGE
}

