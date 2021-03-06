#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for modeler.
GH_REPO="https://github.com/camunda/camunda-modeler"
TOOL_NAME="modeler"
TOOL_TEST=""

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

platform() {
  local os
  local platform

  os=$(uname -s)
  case "$os" in
  Darwin)
    platform="mac"
    ;;
  Linux)
    platform="linux"
    ;;
  *)
    fail "Unknown OS: $os"
    ;;
  esac

  echo "$platform"
}

file_name() {
  local version="$1"
  local platform_name="$(platform)"

  case "$platform_name" in
  mac)
    echo "camunda-modeler-$version-mac.zip"
    ;;
  linux)
    echo "camunda-modeler-$version-linux-x64.tar.gz"
    ;;
  *)
    fail "Unknown platform: $platform_name"
    ;;
  esac
}

executable() {
  local platform_name="$(platform)"

  case "$platform_name" in
  mac)
    echo "Contents/MacOS/Camunda Modeler"
    ;;
  linux)
    echo "camunda-modeler"
    ;;
  *)
    fail "Unknown platform: $platform_name"
    ;;
  esac

}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if modeler is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  # TODO: Adapt this. By default we simply list the tag names from GitHub releases.
  # Change this function if modeler has other means of determining installable versions.
  list_github_tags
}

download_release() {
  local version filename url artifact_name
  version="$1"
  filename="$2"
  artifact_name="$(file_name $version)"

  url="$GH_REPO/releases/download/v${version}/$artifact_name"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"
  local executable_path="$(executable)"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    test -x "$install_path/$executable_path" || fail "Expected $install_path/$executable_path to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
