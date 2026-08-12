# Security Policy

## Supported Versions

SoryOS est basé sur Ubuntu et suit son cycle de support.
Seule la suite `stable` est recommandée pour les systèmes de production.

| Version | Supported          |
|---------|-------------------|
| stable  | ✅                |
| testing | ⚠️ Test seulement |
| nightly | ❌ Usage interne  |

## Reporting a Vulnerability

Signalez une vulnérabilité en ouvrant un advisory sur GitHub :
https://github.com/sory-x/soryos-apt/security/advisories/new

## APT Security

Le dépôt est signé avec GPG. La clé publique est dans `keyrings/`.

- `Release` + `Release.gpg` = signature détachée
- `InRelease` = signature inline
- Utilisez `signed-by` dans vos sources.list, jamais `[trusted=yes]`

## Signing Key

Fingerprint : voir `keyrings/FINGERPRINT`
