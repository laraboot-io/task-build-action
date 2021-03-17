#!/usr/bin/env bash

set -eu
set -o pipefail

# scripts
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ../
readonly GO_PROJECT_DIR="$(cd "${THIS_DIR}/.." && pwd)"

echo "THIS_DIR=$THIS_DIR"
echo "GO_PROJECT_DIR=$GO_PROJECT_DIR"

source $THIS_DIR/build.sh

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

  echo "----> GO_PROJECT_DIR=$GO_PROJECT_DIR"
  echo "----> CWD=$(pwd)"

  readonly json_task=$(yq eval -j -I=0 ./task.yml)
  readonly package_toml=$GO_PROJECT_DIR/dist/package.toml
  readonly pkg_name=$(echo $json_task | jq -rc '.name')
  readonly pkg_version=$(echo $json_task | jq -rc '.version')

  #grab action run
  readonly run_content=$(echo $json_task | jq -rc '.run')

  echo "----> pkg_name=$pkg_name"
  echo "----> pkg_version=$pkg_version"

  # Prep work
  mkdir -p $GO_PROJECT_DIR/dist

  #  cmd::copy_task
  cmd::create_buildpack_file
  cmd::package
  cmd::build
  cmd::build_binaries
}

function usage() {
  cat <<-USAGE
main.sh [OPTIONS]

Builds the buildpack executables.

OPTIONS
  --help  -h  prints the command usage
USAGE
}

#function cmd::copy_task() {
#  echo "----> copy_task"
#  cat <<EOF >$GO_PROJECT_DIR/dist/task.json
#{
#  "dependencies": [
#    {
#      "name": "php",
#      "version": "$req_php_version"
#    }
#  ]
#}
#EOF
#
#  # @todo get a way around this. The process shouldn't include additional files
#  # into the project
#  cp $GO_PROJECT_DIR/dist/task.json $GO_PROJECT_DIR/sample-app/task.json
#
#}

function cmd::create_buildpack_file() {

  echo "----> create_buildpack_file"

  cat <<EOF >$GO_PROJECT_DIR/dist/buildpack.toml
# Buildpack API version
api = "0.5"

# Buildpack ID and metadata
[buildpack]
id = "user/$pkg_name"
version = "$pkg_version"
name = "$pkg_name"

# Stacks that the buildpack will work with
[[stacks]]
id = "io.buildpacks.stacks.bionic"
EOF

}

function cmd::package() {

  cat <<EOF >$package_toml
[buildpack]
uri="."
EOF

}

function cmd::build_binaries() {
  echo "----> build_binaries"
  # test & package commands require docker privileges
  #  cmd::go_pkg_assets
  cmd::go_generate
  cmd::go_build
  cmd::go_export
  cmd::go_package
  #  cmd::go_test
  #  pushd $GO_PROJECT_DIR/concealer
  #  ls -ltah
  #  GOOS=linux go build -ldflags "-X 'main.TaskName=MyTask' -s -w" -o ./bin/detect ./cmd/detect/main.go &&
  #    GOOS=linux go build -ldflags "-s -w" -o ./bin/build ./cmd/build/main.go &&
  #    chmod +x ./bin/detect &&
  #    chmod +x ./bin/build &&
  #    pack config default-builder paketobuildpacks/builder:full &&
  #    pack buildpack package my-task --config ./package.toml &&
  #    pack build tmp-app \
  #      --path ../sample-app \
  #      --buildpack gcr.io/paketo-buildpacks/php-dist \
  #      --buildpack docker://my-task \
  #      --clear-cache --verbose
  #  popd
}

function cmd::build() {

  : ${IMAGE_TAG:=dev}

  readonly script_file="$GO_PROJECT_DIR/dist/bin/user_build_script"

  mkdir -p $GO_PROJECT_DIR/dist/bin

  cat <<EOF >$script_file
#!/usr/bin/env bash
set -eu
set -o pipefail
$run_content
exit 0
EOF

  chmod +x $script_file

}

[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
