#!/usr/bin/env bash
# Import all repositories from a GitHub organization into a GitLab group.
# Mirrors redox-auto-import.sh but source = GitHub (sory-os-org), dest = GitLab (sory-os.org).
set -euo pipefail

echo "================================="
echo " SoryOS - GitHub → GitLab Import"
echo "================================="

##################################
# Dependencies
##################################

echo "[1/6] Vérification dépendances..."

for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null; then
    printf 'ERREUR : %s introuvable dans le PATH\n' "$cmd" >&2
    exit 1
  fi
done

if command -v gh >/dev/null 2>&1; then
  HAVE_GH=1
else
  HAVE_GH=0
fi

echo "curl et jq OK"

##################################
# Configuration
##################################

GITHUB_HOST="${GITHUB_HOST:-github.com}"
GITHUB_ORG="${GITHUB_ORG:-sory-os-org}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"
GITLAB_GROUP="${GITLAB_GROUP:-sory-os.org}"

GITHUB_API="https://${GITHUB_HOST}/api/v3"
if [[ "$GITHUB_HOST" == "github.com" ]]; then
  GITHUB_API="https://api.github.com"
fi

GITLAB_API="https://${GITLAB_HOST}/api/v4"
DEST_GROUP="$GITLAB_GROUP"

# Tokens: env vars, or gh / glab CLI when available.
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [[ -z "$GITLAB_TOKEN" ]] && command -v glab >/dev/null 2>&1; then
  GITLAB_TOKEN="$(glab config get token -h "$GITLAB_HOST" 2>/dev/null || true)"
fi

if [[ -z "$GITHUB_TOKEN" ]] && [[ "$HAVE_GH" -eq 1 ]]; then
  GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
fi

DRY_RUN="${DRY_RUN:-0}"
IMPORT_DELAY="${IMPORT_DELAY:-2}"
PER_PAGE="${PER_PAGE:-100}"

if [[ -z "$GITLAB_TOKEN" ]]; then
  printf 'ERREUR : GITLAB_TOKEN absent. Exporte-le ou connecte glab auth login.\n' >&2
  exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
  printf 'ERREUR : GITHUB_TOKEN absent. Exporte-le ou connecte gh auth login.\n' >&2
  exit 1
fi

printf 'Source GitHub : https://%s/%s\n' "$GITHUB_HOST" "$GITHUB_ORG"
printf 'Destination   : https://%s/%s\n' "$GITLAB_HOST" "$GITLAB_GROUP"
printf 'DRY_RUN=%s  IMPORT_DELAY=%ss\n' "$DRY_RUN" "$IMPORT_DELAY"

##################################
# GitLab group
##################################

echo "[2/6] Recherche groupe GitLab..."

SORY_RESP="$(curl --fail --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_API/groups/$DEST_GROUP")"
SORY_ID="$(echo "$SORY_RESP" | jq -r '.id')"

if [[ "$SORY_ID" == "null" ]] || [[ -z "$SORY_ID" ]]; then
  printf 'Groupe GitLab introuvable : %s\n' "$DEST_GROUP" >&2
  printf 'Réponse API : %s\n' "$SORY_RESP" >&2
  exit 1
fi

printf 'GitLab group ID : %s\n' "$SORY_ID"

##################################
# List GitHub repos
##################################

echo "[3/6] Liste des dépôts GitHub..."

list_github_repos() {
  local page=1
  local repos_json="[]"

  while true; do
    local chunk
    if [[ "$HAVE_GH" -eq 1 ]] && [[ "$GITHUB_HOST" == "github.com" ]]; then
      chunk="$(gh api "orgs/$GITHUB_ORG/repos?per_page=$PER_PAGE&page=$page&type=all" 2>/dev/null || true)"
    else
      chunk="$(curl --fail --silent \
        --header "Authorization: token $GITHUB_TOKEN" \
        --header "Accept: application/vnd.github+json" \
        "$GITHUB_API/orgs/$GITHUB_ORG/repos?per_page=$PER_PAGE&page=$page&type=all")"
    fi

    local count
    count="$(echo "$chunk" | jq 'length')"
    if [[ "$count" -eq 0 ]]; then
      break
    fi

    repos_json="$(jq -s 'add' <<<"$repos_json$chunk")"
    page=$((page + 1))
  done

  echo "$repos_json"
}

REPOS_JSON="$(list_github_repos)"
REPO_COUNT="$(echo "$REPOS_JSON" | jq 'length')"
printf 'Dépôts GitHub trouvés : %d\n' "$REPO_COUNT"

if [[ "$REPO_COUNT" -eq 0 ]]; then
  printf 'Aucun dépôt à importer.\n' >&2
  exit 1
fi

##################################
# Import loop
##################################

echo "[4/6] Import des projets..."

TOTAL=0
SKIPPED=0
IMPORTED=0
FAILED=0

while IFS= read -r PROJECT; do
  NAME="$(echo "$PROJECT" | jq -r '.name')"
  PPATH="$(echo "$PROJECT" | jq -r '.name')"
  CLONE_URL="$(echo "$PROJECT" | jq -r '.clone_url')"
  PRIVATE="$(echo "$PROJECT" | jq -r '.private')"
  ARCHIVED="$(echo "$PROJECT" | jq -r '.archived')"

  if [[ "$ARCHIVED" == "true" ]]; then
    printf '\n→ %s (archivé, ignoré)\n' "$NAME"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # GitLab import_url with GitHub PAT (works for private repos).
  if [[ "$PRIVATE" == "true" ]]; then
    IMPORT_URL="https://x-access-token:${GITHUB_TOKEN}@${GITHUB_HOST}/${GITHUB_ORG}/${PPATH}.git"
  else
    IMPORT_URL="https://${GITHUB_HOST}/${GITHUB_ORG}/${PPATH}.git"
  fi

  printf '\n→ %s (%s)\n' "$NAME" "$CLONE_URL"

  EXIST_RESP="$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "$GITLAB_API/projects/$DEST_GROUP%2F$PPATH")"
  EXIST_ID="$(echo "$EXIST_RESP" | jq -r '.id')"
  IMPORT_STATUS="$(echo "$EXIST_RESP" | jq -r '.import_status // empty')"

  if [[ "$EXIST_ID" != "null" ]] && [[ -n "$EXIST_ID" ]]; then
    if [[ "$IMPORT_STATUS" == "finished" ]] || [[ "$IMPORT_STATUS" == "none" ]]; then
      printf '  Déjà présent (id=%s), on passe.\n' "$EXIST_ID"
      SKIPPED=$((SKIPPED + 1))
      TOTAL=$((TOTAL + 1))
      continue
    fi
    if [[ "$IMPORT_STATUS" == "scheduled" ]] || [[ "$IMPORT_STATUS" == "started" ]]; then
      printf '  Import en cours (status=%s), on passe.\n' "$IMPORT_STATUS"
      SKIPPED=$((SKIPPED + 1))
      TOTAL=$((TOTAL + 1))
      continue
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  [DRY_RUN] importerait vers %s/%s\n' "$DEST_GROUP" "$PPATH"
    IMPORTED=$((IMPORTED + 1))
    TOTAL=$((TOTAL + 1))
    continue
  fi

  RESULT="$(curl --silent --request POST \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --data "name=$NAME" \
    --data "path=$PPATH" \
    --data "namespace_id=$SORY_ID" \
    --data "visibility=public" \
    --data-urlencode "import_url=$IMPORT_URL" \
    "$GITLAB_API/projects")"

  IMPORT_ID="$(echo "$RESULT" | jq -r '.id')"
  if [[ "$IMPORT_ID" != "null" ]] && [[ -n "$IMPORT_ID" ]]; then
    printf '  ✓ Import lancé : %s (id=%s)\n' "$NAME" "$IMPORT_ID"
    IMPORTED=$((IMPORTED + 1))
    TOTAL=$((TOTAL + 1))
    sleep "$IMPORT_DELAY"
  else
    ERR="$(echo "$RESULT" | jq -r '.message // .error // .message[0] // "inconnue"')"
    printf '  ✗ Erreur %s : %s\n' "$NAME" "$ERR"
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
  fi
done < <(echo "$REPOS_JSON" | jq -c '.[]')

##################################
# Summary
##################################

echo ""
echo "================================="
echo " IMPORT TERMINÉ"
echo "================================="
printf 'Dépôts GitHub listés : %d\n' "$REPO_COUNT"
printf 'Traités             : %d\n' "$TOTAL"
printf 'Imports lancés      : %d\n' "$IMPORTED"
printf 'Ignorés / existants : %d\n' "$SKIPPED"
printf 'Erreurs             : %d\n' "$FAILED"
printf 'Destination         : https://%s/%s\n' "$GITLAB_HOST" "$DEST_GROUP"
echo ""
echo "Les imports GitLab sont asynchrones. Vérifie l'état sur :"
printf '  https://%s/%s\n' "$GITLAB_HOST" "$DEST_GROUP"
