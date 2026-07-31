# Plan d'implémentation : Système de Mise à Jour Automatique

## Phase 1 : Configuration et Dépendances
- [ ] Ajouter les dépendances requises dans `pubspec.yaml` :
  - `dio` (requêtes HTTP et téléchargement)
  - `package_info_plus` (lecture de la version locale)
  - `path_provider` (accès au dossier temporaire système)
  - `flutter_markdown` (rendu des notes de version)
  - `shared_preferences` (sauvegarde de la préférence "Ignorer cette version")
- [ ] Lancer `flutter pub get`.

## Phase 2 : Modélisation des Données
- [ ] Créer le fichier `lib/models/github_release.dart`.
- [ ] Définir la classe `GithubRelease` pour parser la réponse de `/repos/{owner}/{repo}/releases/latest`.
- [ ] Extraire `tag_name`, `body` (notes de version) et chercher la première URL de téléchargement se terminant par `.exe` dans la liste `assets`.

## Phase 3 : Service Métier (UpdateService)
- [ ] Créer `lib/services/update_service.dart`.
- [ ] Implémenter la logique d'appel API vers GitHub (avec support d'un token optionnel via `--dart-define=GITHUB_TOKEN`).
- [ ] Implémenter la logique de comparaison sémantique des versions (en supprimant le "v" de `v1.0.0`).
- [ ] Implémenter le nettoyage des fichiers `.exe` temporaires résiduels (`Directory.systemTemp`).
- [ ] Implémenter le téléchargement du fichier avec suivi de la progression (calcul du pourcentage).
- [ ] Implémenter le lancement de l'installeur en processus détaché (`ProcessStartMode.detached`) et forcer l'arrêt de l'app (`exit(0)`).

## Phase 4 : Gestion de l'État (Riverpod)
- [ ] Créer `lib/providers/update_provider.dart`.
- [ ] Définir les états : `initial`, `checking`, `upToDate`, `available`, `downloading`, `readyToInstall`, `error`.
- [ ] Gérer la logique "Ignorer cette version" en lisant/écrivant le tag ignoré dans `SharedPreferences`.
- [ ] Exposer les méthodes `checkForUpdates(silent: true/false)`, `downloadUpdate()`, et `runInstaller()`.

## Phase 5 : Interface Utilisateur (UI)
- [ ] **Modale de mise à jour** (`lib/widgets/update_modal.dart`) :
  - Design respectant le système en place (`viv_shadcn_theme.dart` / `viv_theme.dart`).
  - Zone scrollable contrainte avec `MarkdownBody` pour les notes de version.
  - Case à cocher "Ignorer cette version".
  - Actions : "Plus tard" (ferme), "Télécharger et installer" (se transforme en barre de progression + pourcentage pendant le téléchargement).
- [ ] **Écouteur Global** (`lib/main.dart` ou composant racine) :
  - Ajouter un `ref.listen` pour réagir à l'état `available` et afficher la modale de manière unique.
  - Lancer un `checkForUpdates(silent: true)` lors de l'initialisation.
- [ ] **Paramètres** (`lib/screens/settings_screen.dart`) :
  - Ajouter une section affichant la version actuelle (récupérée via `package_info_plus`).
  - Ajouter un bouton de vérification manuelle.
  - Gérer les retours visuels (chargement, toast de succès "Déjà à jour" ou erreur).

## Phase 6 : Configuration InnoSetup (.iss)
- [ ] Modifier le script InnoSetup pour cibler une installation non-administrateur :
  - `PrivilegesRequired=lowest`
  - `DefaultDirName={userpf}\OpsisApp`
- [ ] Ajouter `CloseApplications=force` dans la section `[Setup]`.
