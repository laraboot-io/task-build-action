#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "${PROGDIR}/.." && pwd)"

echo "PROGDIR=$PROGDIR"
echo "PROJECT_DIR=$PROJECT_DIR"

source $PROGDIR/build.sh

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

  echo "----> PROJECT_DIR=$PROJECT_DIR"

  readonly json_task=$(yq eval -j -I=0 task.yml)
  readonly package_toml=$PROJECT_DIR/dist/package.toml
  readonly pkg_name=$(echo $json_task | jq -rc '.name')
  readonly pkg_version=$(echo $json_task | jq -rc '.version')

  readonly req_php_version=$(echo $json_task | jq -rc '.requires.php')

  #grab action run
  readonly run_content=$(echo $json_task | jq -rc '.run')

  echo "----> pkg_name=$pkg_name"
  echo "----> pkg_version=$pkg_version"

  # Prep work
  mkdir -p $PROJECT_DIR/dist

  cmd::copy_task
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

function cmd::copy_task() {
  echo "----> copy_task"
  cat <<EOF >$PROJECT_DIR/dist/task.json
{
  "dependencies": [
    {
      "name": "php",
      "version": "$req_php_version"
    }
  ]
}
EOF

  # @todo get a way around this. The process shouldn't include additional files
  # into the project
  cp $PROJECT_DIR/dist/task.json $PROJECT_DIR/sample-app/task.json

}

function cmd::create_buildpack_file() {

  echo "----> create_buildpack_file"

  cat <<EOF >$PROJECT_DIR/dist/buildpack.toml
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
  cmd::go_pkg_assets
  cmd::go_generate
  cmd::go_build
  cmd::go_export
  cmd::go_package
  #  cmd::go_test
  #  pushd $PROJECT_DIR/concealer
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

  readonly script_file="$PROJECT_DIR/dist/bin/user_build_script"

  mkdir -p $PROJECT_DIR/dist/bin

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
