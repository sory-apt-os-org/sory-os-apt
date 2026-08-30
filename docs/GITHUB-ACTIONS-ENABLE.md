# Activer GitHub Actions (erreur « Actions has been disabled for this user »)

Si **Run workflow** affiche :

```text
Failed to queue workflow run: Bad request - Actions has been disabled for this user.
```

le blocage vient du **compte GitHub** qui clique sur Run workflow, pas du YAML.

## 1. Compte personnel (`sory-os` — erreur actuelle)

Vérification API (repo déjà OK) :

```bash
gh api repos/sory-os-org/sory-os-apt/actions/permissions
# → {"enabled":true,"allowed_actions":"all"}  (dépôt activé)
```

Le blocage est sur **ton compte** qui clique Run workflow :

```text
Actions has been disabled for this user.
```

**Ce paramètre n’est pas modifiable par API** (ni par Cursor). Seule action :

1. Ouvre https://github.com/settings/actions
2. Section **Actions permissions**
3. **Allow all actions and reusable workflows**
4. Si l’option est grisée → https://support.github.com (restriction plateforme GitHub)

Alternative : connecte un **owner** de `sory-os-org` et lance le workflow depuis son compte.

## 2. Dépôt `sory-os-org/sory-os-apt`

1. https://gitlab.com/sory-os.org/sory-os-apt/settings/actions
2. **Actions permissions** → autoriser les actions (idéalement toutes pour l’org)
3. Vérifier qu’aucun workflow n’est **disabled** dans l’onglet Actions

## 3. Organisation `sory-os-org`

Un admin org doit vérifier :

https://github.com/organizations/sory-os-org/settings/actions

- Actions activées pour les repos
- Membres autorisés à exécuter des workflows

## 4. Si le message persiste

GitHub peut avoir **bloqué Actions au niveau plateforme** pour ce compte ou ce repo.
Dans ce cas : https://support.github.com — mentionner le message exact.

## 5. Sans clic manuel

Le workflow `build-cosmic-utils-release.yml` a aussi un trigger **schedule** (2×/jour UTC).
Les runs planifiés ne passent pas par ton bouton **Run workflow**.
