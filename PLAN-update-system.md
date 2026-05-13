# Plan d'implémentation : Système de Mise à Jour Automatique (GitHub Releases)

## Vue d'ensemble
Ce plan détaille l'intégration d'un système de mise à jour "transparent" pour l'application Windows Opsis.
L'application interrogera l'API GitHub pour vérifier la présence d'une nouvelle release. Si une mise à jour est trouvée, l'application proposera une modale avec les nouveautés, téléchargera le fichier exécutable d'installation (`.exe`) en arrière-plan, l'exécutera, puis se fermera pour permettre la mise à jour.

> **Note sur le dépôt privé :** L'utilisation d'un dépôt privé est tout à fait possible. Pour l'utilisateur final, cela sera 100% transparent. Du côté du développement, cela impliquera de générer un **Personal Access Token (PAT) GitHub** en lecture seule (strictement limité à la lecture des releases de ce dépôt). Ce token sera injecté dans l'application lors de la compilation pour autoriser les requêtes vers l'API GitHub sans que l'utilisateur n'ait besoin de s'authentifier.

## Type de Projet
**DESKTOP (Flutter Windows)** - Agent principal recommandé : `frontend-specialist`

## Critères de succès
1. L'application peut lire sa propre version locale.
2. L'application contacte l'API GitHub en toute sécurité (avec un token injecté) pour lire la dernière release.
3. Si `version_github > version_locale`, une modale non bloquante affiche les notes de version.
4. Au clic sur "Télécharger et installer", le fichier `.exe` est téléchargé dans les fichiers temporaires du système.
5. Une fois téléchargé, le fichier d'installation est lancé automatiquement et l'application Flutter se ferme pour laisser l'installation se faire.
6. L'écran des paramètres affiche la version actuelle et permet de lancer une recherche manuelle.

## Technologies & Packages
- `dio` : Pour interroger l'API GitHub et télécharger le fichier binaire (déjà présent).
- `package_info_plus` : Pour lire la version actuelle de l'application depuis `pubspec.yaml`.
- `path_provider` : Pour obtenir le chemin vers le dossier temporaire de Windows (`%TEMP%`).
- `process_run` (ou native `Process.run`) : Pour exécuter le `.exe` téléchargé.

## Structure des fichiers modifiés/créés
```
lib/
├── models/
│   └── github_release.dart        # Modèle de données pour la release
├── services/
│   └── update_service.dart        # Logique de vérification, téléchargement et exécution
├── providers/
│   └── update_provider.dart       # État global (Vérification en cours, Dispo, Téléchargement...)
├── widgets/
│   └── update_modal.dart          # Modale UI affichant les nouveautés et la progression
├── screens/
│   ├── main_shell.dart            # Déclenchement de la vérification au démarrage
│   └── settings_screen.dart       # Affichage de la version actuelle
```

## Découpage des tâches

### Tâche 1 : Ajout des dépendances et configuration
- **Agent :** `frontend-specialist`
- **Skills :** `bash-linux`, `clean-code`
- **Action :** Ajouter `package_info_plus` et `path_provider` au projet.
- **Vérification :** `flutter pub get` réussit et les packages sont utilisables.

### Tâche 2 : Modèle et Service de mise à jour (GitHub API)
- **Agent :** `backend-specialist`
- **Skills :** `api-patterns`
- **Action :** Créer le modèle `GithubRelease` et le service `UpdateService` pour :
  - Lire la version locale.
  - Interroger l'API GitHub (`/repos/{owner}/{repo}/releases/latest`).
  - Implémenter la méthode de téléchargement du `.exe` vers `getTemporaryDirectory()`.
  - Lancer le `.exe` via `Process.run` et appeler `exit(0)`.
- **Vérification :** Le service parvient à parser le JSON d'une release GitHub (même fictive) et la logique de téléchargement ne bloque pas le thread principal.

### Tâche 3 : Provider d'état (Riverpod)
- **Agent :** `frontend-specialist`
- **Skills :** `react-best-practices`
- **Action :** Créer `UpdateProvider` gérant les états (`Initial`, `Checking`, `UpdateAvailable`, `Downloading(progress)`, `ReadyToInstall`).
- **Vérification :** L'état se met à jour correctement au fil des appels simulés au service.

### Tâche 4 : Modale UI et intégration au Shell
- **Agent :** `frontend-specialist`
- **Skills :** `frontend-design`
- **Action :**
  - Créer `UpdateModal` affichant les notes de version et une barre de progression.
  - Intégrer l'appel au `UpdateProvider` dans le `initState` de `MainShell` pour vérifier silencieusement au démarrage.
- **Vérification :** L'interface utilisateur est premium (shadcn_ui) et réagit à l'avancement du téléchargement sans figer l'application.

### Tâche 5 : Écran des paramètres
- **Agent :** `frontend-specialist`
- **Skills :** `frontend-design`
- **Action :** Ajouter une section "À propos / Mise à jour" dans `settings_screen.dart` affichant la version locale et un bouton "Vérifier les mises à jour".
- **Vérification :** La version est correctement lue et le clic déclenche le processus manuel.

---

## ✅ PHASE X : Vérifications finales
- [ ] Lint: `flutter analyze` réussit sans erreurs.
- [ ] L'application démarre et ne crash pas lors de la vérification réseau (ex: pas d'internet).
- [ ] L'installeur (si téléchargé manuellement pour tester) se lance bien avec `Process.run` et l'application se ferme proprement.
- [ ] Le design de la modale respecte le *Purple Ban* et s'intègre parfaitement au `viv-design-system`.
