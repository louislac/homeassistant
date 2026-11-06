# Workflow Home Assistant

## Principes

- Consulter l'état du dépôt Git (`git status`, fichiers suivis et diff) avant toute modification.
- Utiliser `ha-mcp` pour découvrir les entités, états, intégrations, services et capacités réellement disponibles dans Home Assistant, puis vérifier le résultat après un déploiement.
- Git est la source de vérité des fichiers de configuration versionnés. Modifier en priorité ces fichiers dans le dépôt.
- Ne jamais modifier via MCP un fichier dont Git est la source de vérité. MCP est employé pour la découverte, la validation et, pour les objets Storage/API, le déploiement via l'API adaptée.
- Pour les dashboards Storage et les éléments gérés par API, conserver une représentation versionnée dans Git lorsque c'est possible ; les déployer avec l'API Home Assistant, jamais par écriture dans `.storage`.

## Déploiement SMB

- Avant chaque déploiement, comparer les fichiers concernés entre le dépôt et `\\HOMEASSISTANT\config` avec `scripts/deploy-ha.ps1 -DryRun`.
- Le script de déploiement est la seule voie SMB autorisée. Il ne déploie que des chemins explicitement autorisés, ne supprime aucun fichier distant et sauvegarde localement toute cible avant écrasement.
- Ne jamais copier brutalement des fichiers runtime, `.storage`, secrets, bases de données, journaux, caches ou inventaires.
- Si le script signale une divergence distante, s'arrêter : examiner et intégrer ou écarter explicitement ce changement avant tout déploiement. Ne pas l'écraser.
- Ne déployer que les fichiers nécessaires à la demande et vérifier leur empreinte après transfert.

## Validation Home Assistant

- Valider la configuration avant application et choisir le rechargement le plus ciblé possible (automatisations, scripts, scènes, templates ou dashboards).
- Une copie SMB réussie ne prouve pas que Home Assistant a chargé la configuration : vérifier via ha-mcp après le rechargement.
- Si un redémarrage complet est nécessaire, expliquer pourquoi et demander l'accord explicite de l'utilisateur avant de le lancer.
- Ne jamais envoyer de commande physique aux appareils (éclairage, chauffage, ouvrants, etc.) sans demande explicite de l'utilisateur.

## Git

- Après une validation et une vérification réussies, créer un commit Git explicite contenant uniquement les fichiers concernés.
- Ne jamais committer `secrets.yaml`, `.storage`, les bases de données, journaux, sauvegardes locales ou l'inventaire de déploiement.
