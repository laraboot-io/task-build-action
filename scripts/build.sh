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

function cmd::go_pkg_assets() {
  echo "----> ----> packaging assets"
  # Clean up assets
  rm -rf $GO_PROJECT_DIR/assets/
  # Copy all bin-dist files into assets folder
  #  cp -r $BUILDER_WORKBENCH/dist/bin $GO_PROJECT_DIR/assets/
  #  ls -ltah $GO_PROJECT_DIR/assets/
  pushd $GO_PROJECT_DIR >/dev/null
  #  readonly cwd=$(pwd)
  #  echo "cwd=$cwd"
  # Package assets
  pkger
  pkger list
  #  GOOS=linux go build -ldflags="-s -w" -o ./bin/pack ./cmd/pack/main.go
  #smoke test
  #  ./bin/user_script
  popd >/dev/null
}

function cmd::go_generate() {
  echo "----> ----> go_generate"
  pushd $GO_PROJECT_DIR >/dev/null
  go generate
  popd >/dev/null
}

function cmd::go_build() {

  echo "----> ----> go build"

  readonly name="my-task"

  cp -r $BUILDER_WORKBENCH/dist/* $GO_PROJECT_DIR
  pushd $GO_PROJECT_DIR >/dev/null

  GOOS=linux go build -ldflags "-X 'main.TaskName=${name}' -s -w" -o ./bin/detect ./cmd/detect/main.go
  GOOS=linux go build -ldflags="-s -w" -o ./bin/build ./cmd/build/main.go

  chmod -R +x ./bin
  popd >/dev/null

}

function cmd::go_test() {
  echo "----> ----> go_test"
  #smoke test
  pack build tmp-app \
    --path $BUILDER_WORKBENCH/sample-app \
    --buildpack gcr.io/paketo-buildpacks/php-dist \
    --buildpack docker://$name \
    --builder paketobuildpacks/builder:full \
    --clear-cache
}

function cmd::go_export() {
  mkdir -p $BUILDER_WORKBENCH/dist/task/bin &&
    cp -r $GO_PROJECT_DIR/*.toml $BUILDER_WORKBENCH/dist/task &&
    cp -r $GO_PROJECT_DIR/bin/* $BUILDER_WORKBENCH/dist/task/bin
}

function cmd::go_package() {
  pushd $BUILDER_WORKBENCH/dist/task >/dev/null
  # pack as docker image
  pack buildpack package $name --config ./package.toml
  # pack as file
  pack buildpack package $BUILDER_WORKBENCH/dist/$name.cnb --config ./package.toml --format file
  #  jam && jam pack \
  #    --buildpack ./buildpack.toml \
  #    --stack io.paketo.stacks.tiny \
  #    --version 1.2.3 \
  #    --offline \
  #    --output .$BUILDER_WORKBENCH/dist/buildpack.tgz
  popd >/dev/null
}

#[[ ${BASH_SOURCE[0]} = $0 ]] && main "$@"
