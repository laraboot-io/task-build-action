#!/usr/bin/env bash

set -eu
set -o pipefail

echo "args = $*"

time=$(date)
echo "::set-output name=time::$time"

readonly task_directory="$2"
pushd $task_directory

readonly json_task=$(yq eval -j -I=0 ./task.yml)
readonly pkg_name=$(echo $json_task | jq -rc '.name')
readonly pkg_version=$(echo $json_task | jq -rc '.version')

#grab action run
readonly run_content=$(echo $json_task | jq -rc '.run')
readonly script_file=./bin/user_build_script

mkdir -p bin
mkdir -p dist
mkdir -p tmp

# Create package.toml
cat <<EOF >./package.toml
[buildpack]
uri="."
EOF

# Create buildpack.toml
cat <<EOF >./buildpack.toml
# Buildpack API version
api = "0.5"

# Buildpack ID and metadata
[buildpack]
id = "io.laraboot.user.$pkg_name"
version = "$pkg_version"
name = "$pkg_name"
homepage = "https://laraboot.io/tasks/user/$pkg_name"

[metadata]
  include-files = ["bin/build", "bin/detect", "buildpack.toml"]
  [metadata.default-versions]
    $pkg_name = "$pkg_version"

# Stacks that the buildpack will work with
[[stacks]]
id = "io.buildpacks.stacks.bionic"
EOF

cat <<EOF >$script_file
#!/usr/bin/env bash
set -eu
set -o pipefail
$run_content
exit 0
EOF

chmod +x $script_file

GOOS=linux go build -ldflags "-X 'main.TaskName=$pkg_name' -s -w" -o ./bin/detect ./cmd/detect/main.go &&
  GOOS=linux go build -ldflags "-s -w" -o ./bin/build ./cmd/build/main.go &&
  chmod -R +x ./bin

pack buildpack package my-task --config package.toml

popd

#pwd
#ls -ltah
#$BUILDER_HOME/scripts/main.sh
