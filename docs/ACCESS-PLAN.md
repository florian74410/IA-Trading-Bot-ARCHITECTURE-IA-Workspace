# Accès IA-TB Architecture — plan de sécurité

## Périmètre
- Site Caddy existant : `/srv/iatb-architecture/site`
- Workspace Git cible : `/srv/iatb-architecture/workspace`
- Domaine : `architecture.iatb.duckdns.org`
- Dépôt : `florian74410/IA-Trading-Bot-ARCHITECTURE-IA-Workspace`

## Règles
1. Le code réel du site doit être importé depuis le VPS ; ne pas le reconstruire depuis le HTML public.
2. Aucun jeton, clé privée, mot de passe ou fichier .env ne doit être commité.
3. L'accès GitHub ne donne pas d'accès shell SSH. Pour les opérations distantes depuis ChatGPT, utiliser une passerelle MCP authentifiée, avec fonctions limitées au workspace Architecture et audit, plutôt qu'un shell arbitraire.
4. L'utilisateur de développement ne doit pas avoir sudo ni accès aux services RELEASE/DEBUG.
5. Publication après validation, sauvegarde, vérification et possibilité de rollback.
6. Ne pas installer de runner self-hosted GitHub Actions ouvert à l'exécution du code des pull requests sur le VPS de production.
7. Un repo public révèle le code : envisager la visibilité privée si souhaité.

## Import initial
Sur le VPS, vérifier les permissions et fichiers ; cloner le dépôt dans un dossier séparé, copier les fichiers source depuis `/srv/iatb-architecture/site/` vers `workspace/site/`, puis commiter et pousser via des identifiants GitHub limités au dépôt. Ne jamais initialiser Git dans le répertoire directement servi par Caddy.

## Déploiement
Le script `scripts/deploy-local.sh` crée une sauvegarde et exige une confirmation locale avant copie. Il n'efface pas de fichiers automatiquement. Le déclenchement distant nécessitera une passerelle explicitement autorisée.
