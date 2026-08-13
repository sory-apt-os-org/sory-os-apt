#!/usr/bin/env bash
set -euo pipefail

# Validate the APT repository structure with apt-ftparchive.
# This script checks the repository structure and generates the necessary
# metadata files. It should be run from the root of the APT repository
# (soryos-apt).
#
# Steps:
#   1. Create the dists directory structure for the distribution (e.g., stable)
#   2. Generate Packages and Release files using apt-ftparchive
#   3. Optionally sign the Release file
#
# Usage:
#   ./validate-repository.sh [distribution] [component]
#
# Example: ./validate-repository.sh stable main
#
# If no arguments, defaults to distribution='stable' and component='main'.

DISTRIBUTION="${1:-stable}"
COMPONENT="${2:-main}"
REPO_DIR=$(pwd)
DISTS_DIR="${REPO_DIR}/dists/${DISTRIBUTION}"
POOL_DIR="${REPO_DIR}/pool"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required tool: %s\n' "$1" >&2
    exit 1
  fi
}

require_tool apt-ftparchive
require_tool dpkg-scanpackages

# Create the directory structure for the distribution
mkdir -p "${DISTS_DIR}/${COMPONENT}/binary-amd64"

if [[ ! -d "${POOL_DIR}/${DISTRIBUTION}" ]]; then
  printf 'missing pool directory: %s\n' "${POOL_DIR}/${DISTRIBUTION}" >&2
  exit 1
fi

# Generate the Packages file for binary packages
dpkg-scanpackages -a amd64 "${POOL_DIR}/${DISTRIBUTION}" /dev/null \
  > "${DISTS_DIR}/${COMPONENT}/binary-amd64/Packages"
gzip -9cn "${DISTS_DIR}/${COMPONENT}/binary-amd64/Packages" \
  > "${DISTS_DIR}/${COMPONENT}/binary-amd64/Packages.gz"

# Generate the Release file for the distribution
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=SoryOS" \
  -o "APT::FTPArchive::Release::Label=SoryOS" \
  -o "APT::FTPArchive::Release::Suite=${DISTRIBUTION}" \
  -o "APT::FTPArchive::Release::Codename=${DISTRIBUTION}" \
  -o "APT::FTPArchive::Release::Architectures=amd64" \
  -o "APT::FTPArchive::Release::Components=main" \
  -o "APT::FTPArchive::Release::Description=SoryOS APT Repository" \
  release "${DISTS_DIR}" > "${DISTS_DIR}/Release"

printf 'validated repository: dists/%s\n' "${DISTRIBUTION}"
printf '  %s\n' \
  "${DISTS_DIR}/${COMPONENT}/binary-amd64/Packages" \
  "${DISTS_DIR}/${COMPONENT}/binary-amd64/Packages.gz" \
  "${DISTS_DIR}/Release"