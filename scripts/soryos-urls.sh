#!/usr/bin/env bash
# SoryOS platform URLs — GitLab is the default CI/catalog source (GitHub Actions unreliable).
# Source this file from scripts and CI jobs:  source "$(dirname "$0")/soryos-urls.sh"
set -euo pipefail

soryos_load_urls() {
  SORYOS_PLATFORM="${SORYOS_PLATFORM:-github}"

  if [[ "$SORYOS_PLATFORM" == "gitlab" ]]; then
    SORYOS_GIT_HOST="${SORYOS_GIT_HOST:-gitlab.com}"
    SORYOS_GITLAB_GROUP="${SORYOS_GITLAB_GROUP:-sory-os.org}"
    SORYOS_APT_PROJECT="${SORYOS_APT_PROJECT:-sory-os-apt}"
    SORYOS_APT_PROJECT_PATH="${SORYOS_APT_PROJECT_PATH:-${SORYOS_GITLAB_GROUP}/${SORYOS_APT_PROJECT}}"
    SORYOS_APT_REPO="${SORYOS_APT_REPO:-${SORYOS_APT_PROJECT_PATH}}"
    SORYOS_GIT_BASE_URL="${SORYOS_GIT_BASE_URL:-https://${SORYOS_GIT_HOST}/${SORYOS_GITLAB_GROUP}}"
    SORYOS_PAGES_BASE_URL="${SORYOS_PAGES_BASE_URL:-https://sory-os-org.gitlab.io/${SORYOS_APT_PROJECT}}"
    SORYOS_RELEASE_DOWNLOAD_BASE="${SORYOS_RELEASE_DOWNLOAD_BASE:-https://${SORYOS_GIT_HOST}/${SORYOS_APT_PROJECT_PATH}/-/releases}"
    SORYOS_COSMIC_EPOCH_REPO="${SORYOS_COSMIC_EPOCH_REPO:-${SORYOS_GIT_BASE_URL}/cosmic-epoch.git}"
    SORYOS_COSMIC_EPOCH_REF="${SORYOS_COSMIC_EPOCH_REF:-main}"
    SORYOS_LIBCOSMIC_REPO="${SORYOS_LIBCOSMIC_REPO:-${SORYOS_GIT_BASE_URL}/libcosmic.git}"
    SORYOS_LIBCOSMIC_REF="${SORYOS_LIBCOSMIC_REF:-main}"
    SORYOS_COSMIC_UTILS_ORG="${SORYOS_COSMIC_UTILS_ORG:-${SORYOS_GITLAB_GROUP}}"
    SORYOS_COSMIC_UTILS_GIT_BASE="${SORYOS_COSMIC_UTILS_GIT_BASE:-${SORYOS_GIT_BASE_URL}}"
    SORYOS_COSMIC_UTILS_REF="${SORYOS_COSMIC_UTILS_REF:-main}"
    SORYOS_ADW_GTK3_REPO="${SORYOS_ADW_GTK3_REPO:-${SORYOS_GIT_BASE_URL}/adw-gtk3.git}"
    SORYOS_ADW_GTK3_REF="${SORYOS_ADW_GTK3_REF:-master}"
    SORYOS_DISTINST_REPO="${SORYOS_DISTINST_REPO:-${SORYOS_GIT_BASE_URL}/distinst.git}"
    SORYOS_DISTINST_REF="${SORYOS_DISTINST_REF:-master}"
  else
    SORYOS_GIT_HOST="${SORYOS_GIT_HOST:-github.com}"
    SORYOS_APT_REPO="${SORYOS_APT_REPO:-sory-apt-os-org/sory-os-apt}"
    SORYOS_GIT_BASE_URL="${SORYOS_GIT_BASE_URL:-https://${SORYOS_GIT_HOST}/sory-os-org}"
    SORYOS_PAGES_BASE_URL="${SORYOS_PAGES_BASE_URL:-https://sory-apt-os-org.github.io/sory-os-apt}"
    SORYOS_RELEASE_DOWNLOAD_BASE="${SORYOS_RELEASE_DOWNLOAD_BASE:-https://${SORYOS_GIT_HOST}/${SORYOS_APT_REPO}/releases/download}"
    SORYOS_COSMIC_EPOCH_REPO="${SORYOS_COSMIC_EPOCH_REPO:-${SORYOS_GIT_BASE_URL}/cosmic-epoch.git}"
    SORYOS_COSMIC_EPOCH_REF="${SORYOS_COSMIC_EPOCH_REF:-main}"
    SORYOS_LIBCOSMIC_REPO="${SORYOS_LIBCOSMIC_REPO:-${SORYOS_GIT_BASE_URL}/libcosmic.git}"
    SORYOS_LIBCOSMIC_REF="${SORYOS_LIBCOSMIC_REF:-main}"
    SORYOS_COSMIC_UTILS_ORG="${SORYOS_COSMIC_UTILS_ORG:-sory-os-org}"
    SORYOS_COSMIC_UTILS_GIT_BASE="${SORYOS_COSMIC_UTILS_GIT_BASE:-${SORYOS_GIT_BASE_URL}}"
    SORYOS_COSMIC_UTILS_REF="${SORYOS_COSMIC_UTILS_REF:-main}"
    SORYOS_ADW_GTK3_REPO="${SORYOS_ADW_GTK3_REPO:-${SORYOS_GIT_BASE_URL}/adw-gtk3.git}"
    SORYOS_ADW_GTK3_REF="${SORYOS_ADW_GTK3_REF:-master}"
    SORYOS_DISTINST_REPO="${SORYOS_DISTINST_REPO:-${SORYOS_GIT_BASE_URL}/distinst.git}"
    SORYOS_DISTINST_REF="${SORYOS_DISTINST_REF:-master}"
  fi

  export SORYOS_PLATFORM SORYOS_GIT_HOST SORYOS_GITLAB_GROUP SORYOS_APT_PROJECT
  export SORYOS_APT_PROJECT_PATH SORYOS_APT_REPO SORYOS_GIT_BASE_URL
  export SORYOS_PAGES_BASE_URL SORYOS_RELEASE_DOWNLOAD_BASE
  export SORYOS_COSMIC_EPOCH_REPO SORYOS_COSMIC_EPOCH_REF
  export SORYOS_LIBCOSMIC_REPO SORYOS_LIBCOSMIC_REF
  export SORYOS_COSMIC_UTILS_ORG SORYOS_COSMIC_UTILS_GIT_BASE SORYOS_COSMIC_UTILS_REF
  export SORYOS_ADW_GTK3_REPO SORYOS_ADW_GTK3_REF SORYOS_DISTINST_REPO SORYOS_DISTINST_REF
}

soryos_release_index_url() {
  local tag="${1:?tag required}"
  if [[ "$SORYOS_PLATFORM" == "gitlab" ]]; then
    printf '%s/%s/downloads/index.json' "$SORYOS_RELEASE_DOWNLOAD_BASE" "$tag"
  else
    printf '%s/%s/index.json' "$SORYOS_RELEASE_DOWNLOAD_BASE" "$tag"
  fi
}

soryos_release_asset_base_url() {
  local tag="${1:?tag required}"
  if [[ "$SORYOS_PLATFORM" == "gitlab" ]]; then
    printf '%s/%s/downloads' "$SORYOS_RELEASE_DOWNLOAD_BASE" "$tag"
  else
    printf '%s/%s' "$SORYOS_RELEASE_DOWNLOAD_BASE" "$tag"
  fi
}

soryos_setup_git_auth() {
  if [[ "$SORYOS_PLATFORM" == "gitlab" ]]; then
    if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
      git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@${SORYOS_GIT_HOST}/".insteadOf "https://${SORYOS_GIT_HOST}/"
    elif [[ -n "${GITLAB_TOKEN:-}" ]]; then
      git config --global url."https://oauth2:${GITLAB_TOKEN}@${SORYOS_GIT_HOST}/".insteadOf "https://${SORYOS_GIT_HOST}/"
    fi
    return 0
  fi
  if [[ -n "${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN:-}}" ]]; then
    local tok="${SORYOS_GITHUB_PAT:-${GITHUB_TOKEN}}"
    git config --global url."https://x-access-token:${tok}@github.com/".insteadOf "https://github.com/"
  fi
}

soryos_load_urls
export -f soryos_release_index_url soryos_release_asset_base_url soryos_setup_git_auth 2>/dev/null || true
