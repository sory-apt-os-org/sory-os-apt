# Contribuer à SoryOS APT

## Trouver le bon endroit

- **Paquets SoryOS** (intégration) : modifiez le fichier `templates/<nom>/control`
- **Composants COSMIC** : https://github.com/sory-x/cosmic-epoch (forké de pop-os)
- **Launcher** : https://github.com/sory-x/launcher (forké de pop-os)
- **CI/CD** : `.github/workflows/`
- **Documentation** : `docs/`

## Faire une modification

1. Forkez le dépôt concerné
2. Créez une branche
3. Faites vos changements
4. Créez une Pull Request

## Processus de release

1. Les PRs sont mergées sur `main`
2. La CI build automatiquement les paquets dans GitHub Actions
3. Les .deb sont publiés dans `pool/`
4. L'index APT est regénéré et signé
5. Le tout est pushé sur GitHub Pages

## Conventions

- Chaque paquet d'intégration doit avoir son fichier `control` dans `templates/`
- Les dépendances doivent être minimales
- Ne pas remplacer les paquets Ubuntu/Debian de base
- Tester localement avant de pusher
