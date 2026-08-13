#!/usr/bin/env bash
set -euo pipefail

# APT Toolbox for SoryOS Repository
# Helper functions for building and managing the SoryOS APT repository.
#
# Functions:
#   - setup_environment: Prepare the build environment
#   - build_package: Build a Debian package from source
#   - add_to_repository: Add a built package to the repository
#   - update_repository: Update the repository metadata
#   - sign_repository: Sign the repository with GPG
#   - clean_workspace: Clean temporary build files
#
# Usage: source ./apt-toolbox.sh
# Then call the functions as needed.
#
# Example:
#   source ./apt-toolbox.sh
#   setup_environment
#   build_package cosmic-comp
#   add_to_repository cosmic-comp_1.0.0_amd64.deb
#   update_repository
#   sign_repository
#   clean_workspace
#
# Directories:
#   BUILD_DIR: Where packages are built (default: ./build)
#   REPO_DIR: The APT repository root (default: .)
#   POOL_DIR: The package pool (default: ./pool)
#   DISTS_DIR: The distributions directory (default: ./dists)

BUILD_DIR="${BUILD_DIR:-./build}"
REPO_DIR="${REPO_DIR:-$(pwd)}"
POOL_DIR="${POOL_DIR:-${REPO_DIR}/pool}"
DISTS_DIR="${DISTS_DIR:-${REPO_DIR}/dists}"

# Function to set up the build environment
setup_environment() {
  echo 'Setting up build environment...'
  mkdir -p "${BUILD_DIR}" "${POOL_DIR}" "${DISTS_DIR}"
  # Install any required build dependencies if needed
  # For example:
  #   sudo apt-get update
  #   sudo apt-get install -y debhelper devscripts fakeroot
  # But note: we are in a container or CI, so we assume they are present.
}

# Function to build a Debian package from source
# Parameters:
#   $1 - Package name (directory under cosmic-epoch or libcosmic, etc.)
#   $2 - Version (optional, if not provided will try to get from git or changelog)
build_package() {
  local pkg_name="$1"
  local version="$2"
  if [[ -z "${pkg_name}" ]]; then
    echo 'Error: Package name not provided' >&2
    return 1
  fi

  local src_dir="${REPO_DIR}/../cosmic-epoch/${pkg_name}"
  if [[ ! -d "${src_dir}" ]]; then
    echo "Error: source directory not found: ${src_dir}" >&2
    return 1
  fi

  if [[ -z "${version}" ]]; then
    if [[ -f "${src_dir}/Cargo.toml" ]]; then
      version=$(grep '^version' "${src_dir}/Cargo.toml" | head -1 | sed 's/version = "//;s/"//')
    elif [[ -f "${src_dir}/debian/changelog" ]]; then
      version=$(head -1 "${src_dir}/debian/changelog" | sed 's/.*(\(.*\)).*/\1/')
    fi
  fi

  echo "Building ${pkg_name} ${version}..."
  local work_dir="${BUILD_DIR}/${pkg_name}"
  local deb="${POOL_DIR}/${pkg_name}_${version}_amd64.deb"

  (cd "${src_dir}" && dpkg-buildpackage -us -uc -b)
  find "${src_dir}"/.. -maxdepth 1 -name "${pkg_name}_*.deb" -exec cp "{}" "${deb}" \;
  echo "Built: ${deb}"
}

# Function to add a built package to the repository
# Parameters:
#   $1 - Path to the .deb file to add
add_to_repository() {
  local deb_path="$1"
  if [[ -z "${deb_path}" || ! -f "${deb_path}" ]]; then
    echo 'Error: Valid .deb file path required' >&2
    return 1
  fi
  mkdir -p "${POOL_DIR}"
  cp "${deb_path}" "${POOL_DIR}/"
  echo "Added: ${POOL_DIR}/$(basename "${deb_path}")"
}

# Function to update the repository metadata
update_repository() {
  echo 'Updating repository metadata...'
  if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
    echo 'Error: dpkg-scanpackages is required' >&2
    return 1
  fi
  for suite_dir in "${DISTS_DIR}"/*; do
    [[ -d "${suite_dir}" ]] || continue
    local suite
    suite=$(basename "${suite_dir}")
    local index_dir="${suite_dir}/main/binary-amd64"
    mkdir -p "${index_dir}"
    dpkg-scanpackages -a amd64 "${POOL_DIR}" /dev/null > "${index_dir}/Packages"
    gzip -9cn "${index_dir}/Packages" > "${index_dir}/Packages.gz"
    echo "Generated ${index_dir}/Packages and Packages.gz"
  done
}

# Function to sign the repository with GPG
# Parameters:
#   $1 - GNUPGHOME directory (default: .private/gnupg)
sign_repository() {
  local gnupghome="${1:-${REPO_DIR}/.private/gnupg}"
  if ! command -v apt-ftparchive >/dev/null 2>&1; then
    echo 'Error: apt-ftparchive is required' >&2
    return 1
  fi
  if [[ ! -d "${gnupghome}" ]]; then
    echo "Error: signing GNUPGHOME not found: ${gnupghome}" >&2
    return 1
  fi
  local old_gnupghome="${GNUPGHOME:-}"
  export GNUPGHOME="${gnupghome}"
  for suite_dir in "${DISTS_DIR}"/*; do
    [[ -d "${suite_dir}" ]] || continue
    local suite
    suite=$(basename "${suite_dir}")
    apt-ftparchive \
      -o "APT::FTPArchive::Release::Origin=SoryOS" \
      -o "APT::FTPArchive::Release::Label=SoryOS" \
      -o "APT::FTPArchive::Release::Suite=${suite}" \
      -o "APT::FTPArchive::Release::Codename=${suite}" \
      -o "APT::FTPArchive::Release::Architectures=amd64" \
      -o "APT::FTPArchive::Release::Components=main" \
      -o "APT::FTPArchive::Release::Description=SoryOS APT Repository" \
      release "${suite_dir}" > "${suite_dir}/Release"
    gpg --batch --yes --local-user "${SORYOS_APT_KEY_EMAIL:-apt@soryos.local}" \
      --detach-sign --armor -o "${suite_dir}/Release.gpg" "${suite_dir}/Release"
    gpg --batch --yes --local-user "${SORYOS_APT_KEY_EMAIL:-apt@soryos.local}" \
      --clearsign -o "${suite_dir}/InRelease" "${suite_dir}/Release"
    echo "Signed ${suite_dir}/Release"
  done
  if [[ -z "${old_gnupghome}" ]]; then
    unset GNUPGHOME
  else
    export GNUPGHOME="${old_gnupghome}"
  fi
}

# Function to clean temporary build files
clean_workspace() {
  echo 'Cleaning workspace...'
  rm -rf "${BUILD_DIR}"
  echo 'Cleaned.'
}