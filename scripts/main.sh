#!/usr/bin/env bash

set -eu
set -o pipefail

# scripts
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ../
readonly GO_PROJECT_DIR="$(cd "${THIS_DIR}/.." && pwd)"

# temporal directory for temporal things
# located inside workbench for observability
# could be replaced for any /tmp folder
readonly WORDLY_PLACE="${BUILDER_WORKBENCH}/tmp"

echo "THIS_DIR=$THIS_DIR"
echo "GO_PROJECT_DIR=$GO_PROJECT_DIR"

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
  # this file will be created
  readonly package_toml=$WORDLY_PLACE/package.toml
  readonly pkg_name=$(echo $json_task | jq -rc '.name')
  readonly pkg_version=$(echo $json_task | jq -rc '.version')

  #grab action run
  readonly run_content=$(echo $json_task | jq -rc '.run')

  echo "----> pkg_name=$pkg_name"
  echo "----> pkg_version=$pkg_version"

  # Prep work
  mkdir -p $WORDLY_PLACE

  #  cmd::copy_task
  cmd::create_buildpack_file
  cmd::package
  cmd::build
  cmd::go_generate
  cmd::go_build
  cmd::go_export
  cmd::go_package
  cmd::go_test

  rm -rf $WORDLY_PLACE
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
#  cat <<EOF >$WORDLY_PLACE/task.json
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
#  cp $WORDLY_PLACE/task.json $GO_PROJECT_DIR/sample-app/task.json
#
#}

function cmd::create_buildpack_file() {

  echo "----> create_buildpack_file"

  cat <<EOF >$WORDLY_PLACE/buildpack.toml
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

function cmd::build() {

  : ${IMAGE_TAG:=dev}

  readonly script_file="$WORDLY_PLACE/bin/user_build_script"

  mkdir -p $WORDLY_PLACE/bin

  cat <<EOF >$script_file
#!/usr/bin/env bash
set -eu
set -o pipefail
$run_content
exit 0
EOF

  chmod +x $script_file

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
  GOOS=linux go build -ldflags="-s -w" -o ./bin/pack ./cmd/pack/main.go
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

  #  cp -r $BUILDER_WORKBENCH/dist/* $GO_PROJECT_DIR
  pushd $GO_PROJECT_DIR >/dev/null
  GOOS=linux go build -ldflags "-X 'main.TaskName=${name}' -s -w" -o ./bin/detect ./cmd/detect/main.go
  GOOS=linux go build -ldflags="-s -w" -o ./bin/build ./cmd/build/main.go
  chmod -R +x ./bin
  popd >/dev/null

}

function cmd::go_test() {
  echo "----> ----> go_test"
  echo "pwd=$(pwd)"
  #smoke test
  pack build tmp-app \
  --path . \
  --buildpack gcr.io/paketo-buildpacks/php-dist \
  --buildpack docker://$name \
  --builder paketobuildpacks/builder:full \
  --clear-cache
}

function cmd::go_export() {
  echo "----> ----> go_export"
  mkdir -p $BUILDER_WORKBENCH/dist/task/bin &&
    cp -r $WORDLY_PLACE/*.toml $BUILDER_WORKBENCH/dist/task &&
    cp -r $WORDLY_PLACE/bin/* $BUILDER_WORKBENCH/dist/task/bin &&
    cp -r $GO_PROJECT_DIR/bin/* $BUILDER_WORKBENCH/dist/task/bin
  ls -ltah $BUILDER_WORKBENCH/dist/task
  ls -ltah $BUILDER_WORKBENCH/dist/task/bin
}

function cmd::go_package() {
  echo "----> ----> go_package"
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

[[ ${BASH_SOURCE[0]} == $0 ]] && main "$@"
