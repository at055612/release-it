#!/bin/bash

# exit script on any error
set -eo pipefail

RELEASE_ARTEFACTS_DIR="${BUILD_DIR}/release_artefacts"

# Shell Colour constants for use in 'echo -e'
# e.g.  echo -e "My message ${GREEN}with just this text in green${NC}"
# shellcheck disable=SC2034
{
  RED='\033[1;31m'
  GREEN='\033[1;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[1;34m'
  NC='\033[0m' # No Colour
}

create_file_hash() {
  local -r file="$1"
  local -r hash_file="${file}.sha256"
  local dir
  dir="$(dirname "${file}")"
  local filename
  filename="$(basename "${file}")"

  echo -e "Creating a SHA-256 hash for file ${GREEN}${filename}${NC} in ${GREEN}${dir}${NC}"
  # Go to the dir where the file is so the hash file doesn't contain the full
  # path
  pushd "${dir}" > /dev/null
  sha256sum "${filename}" > "${hash_file}"
  popd > /dev/null
  echo -e "Created hash file ${GREEN}${hash_file}${NC}, containing:"
  echo -e "-------------------------------------------------------"
  cat "${hash_file}"
  echo -e "-------------------------------------------------------"
}

copy_release_artefact() {
  local source="$1"; shift
  local dest="$1"; shift
  local description="$1"; shift

  echo -e "${GREEN}Copying release artefact ${BLUE}${source}${NC}"

  mkdir -p "${RELEASE_ARTEFACTS_DIR}"

  cp "${source}" "${dest}"

  local filename
  if [[ -f "${dest}" ]]; then
    filename="$(basename "${dest}")"
  else
    filename="$(basename "${source}")"
  fi

  # Add an entry to a manifest file for the release artefacts
  echo "${filename} - ${description}" \
    >> "${RELEASE_MANIFEST}"
}

# Put all release artefacts in a dir to make it easier to upload them to
# Github releases. Some of them are needed by the stack builds in
# stroom-resources
gather_release_artefacts() {
  mkdir -p "${RELEASE_ARTEFACTS_DIR}"

  echo "Copying release artefacts to ${RELEASE_ARTEFACTS_DIR}"

  # The zip dist config is inside the zip dist. We need the docker dist
  # config so stroom-resources can use it.

  # Stroom
  copy_release_artefact \
    "${BUILD_DIR}/CHANGELOG.md" \
    "${RELEASE_ARTEFACTS_DIR}" \
    "Change log for this release"

  copy_release_artefact \
    "${BUILD_DIR}/tag_release.sh" \
    "${RELEASE_ARTEFACTS_DIR}" \
    "The script for initiating a release"

  copy_release_artefact \
    "${BUILD_DIR}/log_change.sh" \
    "${RELEASE_ARTEFACTS_DIR}" \
    "The script for recording a change entry"

  # Now generate hashes for all the zips
  for file in "${RELEASE_ARTEFACTS_DIR}"/*.sh; do
    create_file_hash "${file}"
  done
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script proper starts here
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# establish what version of stroom we are building
if [ -n "$BUILD_TAG" ]; then
  # Tagged commit so use that as our stroom version, e.g. v6.0.0
  BUILD_VERSION="${BUILD_TAG}"
else
  # No tag so use the branch name as the version, e.g. dev
  BUILD_VERSION="${BUILD_BRANCH}"
fi

# Dump all the env vars to the console for debugging
echo -e "HOME:                          [${GREEN}${HOME}${NC}]"
echo -e "BUILD_DIR:                     [${GREEN}${BUILD_DIR}${NC}]"
echo -e "BUILD_COMMIT:                  [${GREEN}${BUILD_COMMIT}${NC}]"
echo -e "BUILD_BRANCH:                  [${GREEN}${BUILD_BRANCH}${NC}]"
echo -e "BUILD_TAG:                     [${GREEN}${BUILD_TAG}${NC}]"
echo -e "BUILD_IS_PULL_REQUEST:         [${GREEN}${BUILD_IS_PULL_REQUEST}${NC}]"
echo -e "BUILD_VERSION:                 [${GREEN}${BUILD_VERSION}${NC}]"
echo -e "git version:                   [${GREEN}$(git --version)${NC}]"

pushd "${BUILD_DIR}" > /dev/null


# If it is a tagged build copy all the files needed for the github release
# artefacts
if [ -n "$BUILD_TAG" ]; then
  gather_release_artefacts
else
  echo -e "${GREEN}Not a release so nothing to do${NC}"
fi

exit 0

# vim:sw=2:ts=2:et:
