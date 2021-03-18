#!/usr/bin/env bash

set -eu
set -o pipefail

readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


echo "args = $*"
echo "DIR = $DIR"

time=$(date)
echo "::set-output name=time::$time"

readonly task_directory=$(dirname "$2")

# 1)
# Step name: input-gather
# Purpose: Get the settings from task.yml
# Path: TaskDirectory
echo "----> input-gather"
pushd $task_directory > /dev/null
readonly json_task=$(yq eval -j -I=0 ./task.yml)
readonly pkg_name=$(echo $json_task | jq -rc '.name')
readonly pkg_version=$(echo $json_task | jq -rc '.version')
#grab action run
readonly run_content=$(echo $json_task | jq -rc '.run')
readonly script_file=./bin/user_script

mkdir -p bin
mkdir -p dist/task/bin

# 2)
# Step name: buildpack-config-generation
# Purpose: Create buildpack.toml and package.toml
# Path: TaskDirectory
echo "----> buildpack-config-generation"

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

# 3)
# Step name: buildpack-user-script
# Purpose: Put the custom script on a file to be executed by lifecycle
# Path: TaskDirectory
echo "----> buildpack-user-script"

cat <<EOF >$script_file
#!/usr/bin/env bash
set -eu
set -o pipefail
$run_content
exit 0
EOF

chmod +x $script_file

# 3.1 -> Create and fill  assets library
echo "----> assets"
mkdir -p $BUILDER_HOME/assets && \
cp $script_file $BUILDER_HOME/assets/user_build_script

popd

# 4)
# Step name: build-time
# Purpose: compile bin and detect binaries using user data
# Path: Builder home (where GO source lives)
echo "----> build-prep"
pushd $BUILDER_HOME > /dev/null
# 3.2 Package assets
ls -ltah $BUILDER_HOME/assets
echo "----> pkger"
pkger parse
pkger
pkger list
echo "----> go-build"
CGO_ENABLED=0 GOOS=linux go build -tags netgo -a -v -ldflags "-s -w" ./bin/pack ./cmd/pack/main.go
CGO_ENABLED=0 GOOS=linux go build -tags netgo -a -v -ldflags "-X 'main.TaskName=$pkg_name' -s -w" -o ./bin/detect ./cmd/detect/main.go
#CGO_ENABLED=0 GOOS=linux go build -tags netgo -a -v -ldflags "-s -w" -o ./bin/build ./cmd/build/main.go
popd

pushd $task_directory > /dev/null
cp -r $BUILDER_HOME/bin/* ./bin
chmod -R +x ./bin
pack buildpack package my-task --config package.toml
popd