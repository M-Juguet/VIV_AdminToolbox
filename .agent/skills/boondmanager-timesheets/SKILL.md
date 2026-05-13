---
name: boondmanager-timesheets
description: >
  Expert guide for interacting with the BoondManager API on the Timesheets domain
  (feuilles de temps / CRA). Use this skill whenever the user wants to search, read,
  create, update, validate, or reject timesheets in BoondManager, or when working with
  individual time entries (lignes de temps / saisies journalières), raw time data, or
  the /times and /times-reports endpoints. Also triggers on French equivalents:
  "feuille de temps", "CRA", "compte-rendu d'activité", "saisie des temps", "ligne de temps",
  "valider les temps", "rejeter les temps", "types d'heures", or any mention of
  BoondManager + saisie/suivi du temps de travail.
---

# BoondManager — Timesheets (Feuilles de temps / CRA)

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth ou JWT Bearer token
- **Format**: JSON:API — réponses avec `data`, `included`, `meta`

## Architecture en 3 couches — Concept clé

```
TAB_LISTETEMPS   (times-reports)  ← Feuille mensuelle d'un collaborateur
    └── TAB_LIGNETEMPS   (lines)  ← Ligne de temps : lien Feuille ↔ Projet/Livraison + type d'heure
            └── TAB_TEMPS        ← Saisie journalière : date + durée (entre 0 et 1 jour)
```

> **Règle fondamentale** : `TEMPS_DUREE` est compris **strictement entre 0 et 1** (fractions de journée). Une journée entière = `1.0`, une demi-journée = `0.5`.

La feuille (`times-report`) est toujours **mensuelle** — sa date (`term`) est toujours au format `YYYY-MM-01`.

---

## Endpoints

### 1. Times Reports — Feuilles de temps (`/times-reports`)

```
GET    /times-reports                    ← liste / recherche
GET    /times-reports/default            ← valeurs par défaut avant création
POST   /times-reports                    ← créer une feuille
GET    /times-reports/{id}              ← profil complet (avec lignes et saisies)
PUT    /times-reports/{id}              ← mettre à jour (état, commentaires, clôture)
```

#### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `resource` | ID du collaborateur (`TAB_PROFIL.ID_PROFIL`) |
| `agency` | ID de l'agence |
| `pole` | ID du pôle |
| `mainManager` | ID du manager principal |
| `startDate` | Date de début (filtre sur le terme) — format `YYYY-MM-01` |
| `endDate` | Date de fin |
| `state` | État de la feuille : `1`=validée, `2`=en attente, `3`=rejetée |
| `isClosed` | `1` = feuilles clôturées uniquement |
| `page` / `numberPerPage` | Pagination |

#### Champs de la feuille (TAB_LISTETEMPS)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `term` | `LISTETEMPS_DATE` | Date | Mois de la feuille — **toujours au 1er du mois** (`YYYY-MM-01`) |
| `state` | `LISTETEMPS_ETAT` | Tinyint | `1`=validée · `2`=en attente · `3`=rejetée |
| `isClosed` | `LISTETEMPS_CLOTURE` | Tinyint | `1`=clôturée · `0`=ouverte |
| `workUnitRate` | `LISTETEMPS_TAUXHORAIRE` | Decimal(15,5) | Taux horaire de référence |
| `comments` | `LISTETEMPS_COMMENTAIRES` | Text | Commentaires libres |
| `creationDate` | `LISTETEMPS_CREATEDAT` | Datetime | Création automatique |
| `updateDate` | `LISTETEMPS_UPDATEDAT` | Datetime | Dernière mise à jour |

#### Relations de la feuille

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `resource.id` | `ID_PROFIL` | Collaborateur (TAB_PROFIL) |
| `agency.id` | `ID_SOCIETE` | Agence |

---

### 2. Time Lines — Lignes de temps (`lines` dans le profil)

Les lignes sont imbriquées dans la réponse `GET /times-reports/{id}` via le tableau `included`, ou accessibles via `/times-reports/{id}` directement.

Chaque ligne représente **l'association entre une feuille et une activité** (projet/livraison ou activité interne/absence).

#### Champs d'une ligne (TAB_LIGNETEMPS)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `workUnitTypeRef` | `LIGNETEMPS_TYPEHREF` | Int | **Référence du type d'heure** — cf. `TAB_TYPEHEURE.TYPEH_REF` |
| `timesheet.id` | `ID_LISTETEMPS` | Int | Feuille parente |
| `project.id` | `ID_PROJET` | Int | `-1`=Activité d'absence · `-2`=Activité interne · entier positif=Projet |
| `delivery.id` | `ID_MISSIONPROJET` | Int | Livraison du projet (TAB_MISSIONPROJET) |
| `batch.id` | `ID_LOT` | Int | Lot (si projet en mode forfait+lots) |

> ⚠️ `project.id = -1` → absence · `project.id = -2` → activité interne (intercontrat, formation…)

---

### 3. Time Entries — Saisies journalières (TAB_TEMPS)

Les saisies sont les **valeurs jour par jour** à l'intérieur d'une ligne.

#### Champs d'une saisie (TAB_TEMPS)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `date` | `TEMPS_DATE` | Date | Date de la saisie (`YYYY-MM-DD`) |
| `duration` | `TEMPS_DUREE` | Decimal(15,5) | Durée **en jours** — **valeur entre 0 et 1 strictement** |
| `durationInWorkUnits` | `TEMPS_DUREEUO` | Decimal(15,5) | Durée en unités d'œuvre |
| `line.id` | `ID_LIGNETEMPS` | Int | Ligne parente |

---

### 4. Endpoint `/times` — Vue transverse

```
GET /times
```
Donne une vue agrégée des saisies sans passer par la structure feuille→ligne→saisie. Utile pour extraire toutes les saisies d'une période sur plusieurs collaborateurs.

**Paramètres de recherche :**

| Paramètre | Description |
|-----------|-------------|
| `resource` | ID du collaborateur |
| `startDate` / `endDate` | Plage de dates |
| `project` | Filtrer par projet |
| `delivery` | Filtrer par livraison |
| `agency` | Agence |
| `pole` | Pôle |

---

## Types d'heures (TAB_TYPEHEURE) — Référentiel critique

Le `workUnitTypeRef` d'une ligne pointe vers `TYPEH_REF` (un entier configuré par agence, **non pas l'ID**).

### Catégories de types d'heures (`TYPEH_TYPEACTIVITE`)

| Valeur | Catégorie | Comportement |
|--------|-----------|-------------|
| `0` | **Production** | Temps sur projet/livraison facturable |
| `1` | **Absence** | Congés, RTT, maladie… — `project.id = -1` |
| `2` | **Interne** | Intercontrat, formation, réunion interne — `project.id = -2` |
| `3` | **Exceptionnel (temps)** | Astreintes, heures sup… comptabilisées en temps |
| `4` | **Exceptionnel (calendrier)** | Astreintes comptabilisées en jours calendaires |

### Récupérer les types d'heures disponibles

Les types d'heures sont configurés par agence et ne sont **pas dans le dictionnaire général**. Ils sont retournés dans le `included` des feuilles de temps, ou via :
```
GET /application/dictionary   → clé data.setting.workUnitType (si disponible)
```
Sinon, ils apparaissent dans la réponse `GET /times-reports/{id}` dans `included`.

### Permissions des types d'heures (`TYPEH_PERMISSIONS`)

| Valeur | Signification |
|--------|---------------|
| `0` | Aucune ressource autorisée |
| `1` | Tous les types de ressources |
| `2` | Certains types de ressources uniquement (cf. `TYPEH_TYPESRESSOURCES`) |

---

## Cycle de validation

```
État 2 (en attente)  →  validation manager  →  État 1 (validée)
État 2 (en attente)  →  rejet manager       →  État 3 (rejetée)
État 3 (rejetée)     →  correction resource →  État 2 (en attente)
```

La **clôture** (`isClosed = 1`) fige la feuille après validation et empêche toute modification ultérieure.

### Valider / rejeter via PUT

```
PUT /times-reports/{id}
Body: {
  "data": {
    "type": "times-reports",
    "id": "{id}",
    "attributes": { "state": 1 }   ← 1=valider, 3=rejeter
  }
}
```

---

## Création complète d'une feuille avec saisies

La création se fait en **3 appels successifs** :

### Étape 1 — Créer la feuille mensuelle
```http
POST /times-reports
{
  "data": {
    "type": "times-reports",
    "attributes": { "term": "2025-03-01" },
    "relationships": {
      "resource": { "data": { "type": "resources", "id": "42" } }
    }
  }
}
```
→ Réponse : `{ "data": { "id": "123", ... } }`

### Étape 2 — Créer une ligne pour chaque activité
```http
PUT /times-reports/{id}
{
  "data": {
    "type": "times-reports",
    "id": "123",
    "attributes": {
      "lines": [
        {
          "workUnitTypeRef": 10,
          "project": { "id": "56" },
          "delivery": { "id": "78" },
          "times": [
            { "date": "2025-03-03", "duration": 1.0 },
            { "date": "2025-03-04", "duration": 0.5 },
            { "date": "2025-03-05", "duration": 1.0 }
          ]
        },
        {
          "workUnitTypeRef": 11,
          "project": { "id": "-2" },
          "times": [
            { "date": "2025-03-06", "duration": 1.0 }
          ]
        }
      ]
    }
  }
}
```

> Les lignes et les saisies sont envoyées ensemble dans le `PUT`. Le corps inclut la structure complète attendue pour le mois.

---

## Patterns de workflow

### Lister les feuilles en attente de validation pour une agence
```
GET /times-reports?state=2&agency={agencyId}&startDate=2025-03-01&endDate=2025-03-01
```

### Extraire toutes les saisies d'un collaborateur sur un mois
```
GET /times?resource={resourceId}&startDate=2025-03-01&endDate=2025-03-31
```

### Clôturer une feuille après validation
```
PUT /times-reports/{id}
Body: { data: { type: "times-reports", id: "{id}", attributes: { isClosed: 1 } } }
```

### Lire le détail complet d'une feuille (lignes + saisies)
```
GET /times-reports/{id}
```
→ Réponse avec `included` : resource, agency, lines, time entries, projects, deliveries.

---

## Enumeration References

| Source | Utilisation |
|--------|-------------|
| `LISTETEMPS_ETAT` : `1`, `2`, `3` | États de la feuille (pas dans le dictionnaire, valeurs fixes) |
| `TYPEH_REF` (par agence) | Référence des types d'heures — récupérer via `included` d'une feuille |
| `TYPEH_TYPEACTIVITE` : `0–4` | Catégorie du type d'heure — valeurs fixes documentées ci-dessus |

---

## Gestion des erreurs

| Code HTTP | Signification |
|-----------|---------------|
| `200` | Succès |
| `422` | Erreur de validation — vérifier `errors[].title` + `errors[].detail` |
| `401` | Authentification échouée |
| `403` | Droits insuffisants (ex. : tenter de valider sans être manager) |
| `404` | Feuille introuvable |

---

## Notes importantes

- `TEMPS_DUREE` est **toujours entre 0 et 1** — ne jamais envoyer une valeur > 1 par saisie. Si un collaborateur a travaillé plus d'une journée, cela n'est pas représentable sur une seule saisie ; utiliser des unités d'œuvre (`durationInWorkUnits`) à la place pour les types exceptionnels.
- Le `term` de la feuille est **toujours le 1er du mois** : `2025-03-01`, jamais `2025-03-15`.
- `project.id = -1` est réservé aux **absences** (type d'heure avec `TYPEH_TYPEACTIVITE = 1`).
- `project.id = -2` est réservé aux **activités internes** (intercontrat, formation — `TYPEH_TYPEACTIVITE = 2`).
- Les **types d'heures sont configurés par agence** — leur `TYPEH_REF` n'est pas un ID universel. Toujours les lire depuis le `included` d'une feuille existante ou depuis le dictionnaire de l'agence concernée.
- Une feuille **clôturée** (`isClosed = 1`) ne peut plus être modifiée, même par un administrateur via l'API.
