# Workflow Home Assistant : Git, SMB et ha-mcp

## Source de vérité

Les fichiers suivis par Git dans ce dépôt sont la source de vérité pour la configuration YAML :

- `configuration.yaml`, `automations.yaml`, `scripts.yaml`, `scenes.yaml`
- `packages/`, `dashboards/`, `blueprints/`

Les tableaux de bord en mode Storage et les objets créés par une API Home Assistant ne sont jamais copiés dans `.storage`. Leur configuration doit être exportée ou représentée dans Git lorsque possible, puis appliquée avec l'API Home Assistant adaptée.

## Audit avant modification

1. Lire `git status` et les fichiers concernés.
2. Découvrir les entités, intégrations, services et configuration active avec ha-mcp.
3. Comparer les fichiers concernés avec `\\HOMEASSISTANT\config`.
4. Si la version distante diverge, intégrer ou examiner le changement avant de poursuivre. Ne pas l'écraser.

## Prévisualiser un transfert SMB

Le script n'accepte que les chemins autorisés par sa liste interne, n'effectue aucune suppression distante et conserve les sauvegardes locales dans `.ha-inventory/` (ignoré par Git).

```powershell
.\scripts\deploy-ha.ps1 -ListAllowedPaths
.\scripts\deploy-ha.ps1 -Path dashboards\maison.yaml -DryRun
.\scripts\deploy-ha.ps1 -Path automations.yaml -DryRun
```

Un fichier distant différent sans empreinte de référence est un conflit bloquant. Il faut d'abord le réconcilier dans Git. À l'inverse, un fichier identique est simplement ignoré.

## Déploiement réel, après validation humaine

Après un DryRun sans conflit et une validation de contenu, exécuter uniquement le ou les chemins requis :

```powershell
.\scripts\deploy-ha.ps1 -Path dashboards\maison.yaml
```

Avant tout écrasement, le script sauvegarde la version distante dans `.ha-inventory/deploy-backups/<horodatage>/`, transfère le fichier puis compare les empreintes SHA-256. Il ne redémarre ni ne recharge Home Assistant.

## Validation Home Assistant

Après le transfert, Codex utilise ha-mcp pour :

1. Vérifier la configuration concernée et les journaux.
2. Déclencher uniquement le rechargement ciblé approprié, si disponible et sûr.
3. Confirmer que Home Assistant a appliqué le changement.

Un redémarrage total exige toujours un accord explicite. Une copie SMB, même vérifiée, ne suffit pas à établir que Home Assistant a rechargé le fichier.

## Finalisation

Une fois le changement appliqué et vérifié, créer un commit Git explicite ne contenant que les fichiers de configuration et de documentation concernés. Ne jamais ajouter les secrets, `.storage`, bases de données, journaux ni `.ha-inventory/`.
