# Modèle Releases + Pages + ISO live (SoryOS Debian)

Aligné sur `modules-sory-os/sory-os-apt` (pkgar Redox), adapté aux **`.deb`** et à l’ISO live COSMIC.

Dernière mise à jour : **2026-08-21** (boot USB validé)

---

## Pourquoi deux canaux ?

| Canal | Limite | Rôle |
|-------|--------|------|
| **GitHub Pages** | ~1 Go / site | Catalogue : `index.json` signé, `dists/stable/`, clés — **jamais les `.deb`** |
| **GitHub Release** | assets immuables | **Binaires** : tous les `.deb` par tag |

Org : **`sory-os-org`** — Pages : https://sory-os-org.github.io/sory-os-apt/

---

## Qui build quoi ?

| Machine | Action |
|---------|--------|
| **CI GitHub Actions** | `dpkg-buildpackage` → Release + mise à jour Pages |
| **PC dev (RAM limitée)** | **Ne compile pas** les apps COSMIC en local |
| **`make DISTRO_CODE=soryos iso`** | Télécharge Pages + Release → chroot → ISO live |

---

## Chaîne CI `.deb`

1. `cosmic-apps/manifest.json` — liste composants
2. `build-deb-release.yml` — matrix, publish Release
3. `publish-pages.yml` — catalogue Pages (workflow)
4. `update-deb-release.yml` — incrémental

Secrets : `SORYOS_GPG_PRIVATE_KEY`, `SORYOS_INDEX_PRIVATE_KEY_PEM`

**Ne pas** fetch depuis `apt.pop-os.org`.

Compat dépendances Pop : template `templates/soryos-pop-compat/` (`Provides: pop-launcher`, etc.).

---

## Chaîne ISO

```bash
cd sory-os/iso
make DISTRO_CODE=soryos iso
```

> Paramètre : **`DISTRO_CODE=soryos`** (pas `CONFIG=`). Pas de cible `live`.

1. `scripts/soryos-release-pool.sh` → `download-release-pool.sh`
2. Pages : vérifie `index.json` + signature
3. Release : télécharge `.deb` (BLAKE3 + taille)
4. Chroot : bind-mount `build/soryos-apt` → `apt install`
5. Live : casper + patches boot (`soryos-patch-casper-bottom.sh`)
6. ISO : squashfs + xorriso hybrid (`isohybrid-mbr` + EFI)

Config : `iso/config/soryos/24.04.mk`

- `RELEASE_SUITE=stable`
- `RELEASE_TRUSTED=1`
- `MAIN_POOL=` (pool CD vide — normal)
- `DISTRO_PARAMS+=noplymouth`

---

## Boot live — exigences (2026-08-21)

Sans ces points, **écran noir** après casper :

| Exigence | Où |
|----------|-----|
| `noplymouth` (pas `quiet splash`) | `24.04.mk` → grub/isolinux |
| Retrait `plymouth-quit-wait` greeter | `mk/chroot.mk` patch live |
| Pas de `41apt_cdrom` (pool CD vide) | `soryos-patch-casper-bottom.sh` |
| `update-initramfs` après patch casper | `mk/chroot.mk` |

Test matériel : `dd` ISO → USB → boot UEFI (validé).

Doc détaillée : `docs-plans/SORYOS-ISO-LIVE-BOOT.md`

**Revue exhaustive (changements + dette + checklist)** : `docs-plans/REVISION-COMPLETE-ISO-APT-2026-08-21.md`

---

## Rebuild ISO après changement boot

```bash
make DISTRO_CODE=soryos clean-live
sudo rm -rf build/soryos/24.04/amd64/iso build/soryos/24.04/amd64/grub \
           build/soryos/24.04/amd64/iso_*.tag build/soryos/24.04/amd64/*.iso \
           build/soryos/24.04/amd64/live.tag
make DISTRO_CODE=soryos iso
```

---

## Écarts vs modules-sory-os (pkgar)

| Élément | modules-sory-os | sory-os |
|---------|-----------------|---------|
| Format | `.pkgar` | `.deb` |
| Consommateur | `redox` + `REPO_BINARY=1` | `iso` + pool Release |
| Boot test | QEMU + USB RedoxFS | ISO hybrid + casper COSMIC |

Voir aussi `docs/LOCAL-BUILD-POLICY.md`.
