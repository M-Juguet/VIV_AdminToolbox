---
name: boondmanager-expenses
description: >
  Expert guide for interacting with the BoondManager API on the Expenses domain
  (notes de frais). Use this skill whenever the user wants to search, read, create,
  update, validate, or reject expense reports in BoondManager, or when working with
  individual expense lines (frais réels), kilometric expenses, expense types, or the
  /expenses and /expenses-reports endpoints. Also triggers on French equivalents:
  "note de frais", "frais", "frais réels", "frais kilométriques", "IKV", "NDF",
  "justificatif", "remboursement de frais", "valider les frais", or any mention of
  BoondManager + gestion des dépenses/remboursements.
---

# BoondManager — Notes de Frais (Expenses Reports)

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth ou JWT Bearer token
- **Format**: JSON:API — réponses avec `data`, `included`, `meta`

## Architecture en 2 couches — Concept clé

```
TAB_LISTEFRAIS  (expenses-reports)   ← Note de frais mensuelle d'un collaborateur
    └── TAB_FRAISREEL  (expenses)    ← Ligne de frais : un frais individuel daté
```

> Symétrique des feuilles de temps : la note de frais est **mensuelle** (`term` = `YYYY-MM-01`), elle regroupe toutes les dépenses du mois d'un collaborateur. Chaque ligne est un frais individuel (repas, transport, hôtel, IKV…) rattaché à un projet ou une activité.

---

## Endpoints

### 1. Expenses Reports — Notes de frais (`/expenses-reports`)

```
GET    /expenses-reports                 ← liste / recherche
GET    /expenses-reports/default         ← valeurs par défaut
POST   /expenses-reports                 ← créer une note de frais
GET    /expenses-reports/{id}            ← profil complet (avec lignes)
PUT    /expenses-reports/{id}            ← mettre à jour (état, commentaires, clôture)
```

#### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `resource` | ID du collaborateur |
| `agency` | ID de l'agence |
| `pole` | ID du pôle |
| `mainManager` | ID du manager principal |
| `startDate` | Début de période (format `YYYY-MM-01`) |
| `endDate` | Fin de période |
| `state` | État : `1`=validée · `2`=en attente · `3`=rejetée |
| `isClosed` | `1` = notes clôturées uniquement |
| `isPaid` | `1` = notes remboursées uniquement |
| `page` / `numberPerPage` | Pagination |

#### Champs de la note de frais (TAB_LISTEFRAIS)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `term` | `LISTEFRAIS_DATE` | Date | Mois — **toujours au 1er du mois** (`YYYY-MM-01`) |
| `state` | `LISTEFRAIS_ETAT` | Tinyint | `1`=validée · `2`=en attente · `3`=rejetée |
| `isClosed` | `LISTEFRAIS_CLOTURE` | Tinyint | `1`=clôturée (immuable) |
| `isPaid` | `LISTEFRAIS_REGLE` | Tinyint | `1`=remboursée · `0`=non remboursée |
| `advance` | `LISTEFRAIS_AVANCE` | Decimal(30,10) | Avance versée au collaborateur |
| `comments` | `LISTEFRAIS_COMMENTAIRES` | Text | Commentaires libres |
| `agencyExchangeRate` | `LISTEFRAIS_CHANGEAGENCE` | Decimal(30,10) | Taux de change de l'agence |
| `agencyCurrency` | `LISTEFRAIS_DEVISEAGENCE` | Int | Devise de l'agence — cf. `data.setting.currency` |
| `kilometerRateRef` | `LISTEFRAIS_BKMREF` | Int | Référence du barème IKV utilisé — cf. `TAB_BAREMEKM.BARKM_REF` |
| `kilometerRateValue` | `LISTEFRAIS_BKMVALUE` | Decimal(15,5) | Valeur du taux kilométrique (€/km) |
| `lastExportDate` | `LISTEFRAIS_LAST_EXTRACT_DATE` | Datetime | Date du dernier export comptable |
| `creationDate` | `LISTEFRAIS_CREATEDAT` | Datetime | Auto-set |
| `updateDate` | `LISTEFRAIS_UPDATEDAT` | Datetime | Dernière modification |

#### Relations de la note de frais

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `resource.id` | `ID_PROFIL` | Collaborateur (TAB_PROFIL) |
| `agency.id` | `ID_SOCIETE` | Agence |

---

### 2. Expenses — Lignes de frais (`/expenses`)

```
GET    /expenses                         ← liste transverse de toutes les lignes
GET    /expenses-reports/{id}            ← inclut les lignes dans `included`
PUT    /expenses-reports/{id}            ← créer/modifier les lignes via le rapport
```

#### Paramètres de recherche `/expenses`

| Paramètre | Description |
|-----------|-------------|
| `resource` | ID du collaborateur |
| `startDate` / `endDate` | Plage de dates sur la date du frais |
| `project` | Filtrer par projet |
| `delivery` | Filtrer par livraison |
| `agency` | Agence |
| `isReinvoiced` | `1` = frais refacturables uniquement |

#### Champs d'une ligne de frais (TAB_FRAISREEL)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `date` | `FRAISREEL_DATE` | Date | Date du frais (`YYYY-MM-DD`) |
| `title` | `FRAISREEL_INTITULE` | Varchar(250) | Libellé / description du frais |
| `expenseTypeRef` | `FRAISREEL_TYPEFRSREF` | Int | **Référence du type de frais** — `0` = IKV, sinon `TYPEFRS_REF` |
| `amount` | `FRAISREEL_MONTANT` | Decimal(30,10) | **Km si IKV** (typeRef=0), **montant TTC** sinon |
| `taxRate` | `FRAISREEL_TVA` | Decimal(15,5) | Taux de TVA — cf. `TAB_TYPEFRAIS.TYPEFRS_TVA` |
| `currency` | `FRAISREEL_DEVISE` | Int | Devise — cf. `data.setting.currency` |
| `exchangeRate` | `FRAISREEL_CHANGE` | Decimal(30,10) | Taux de change |
| `isReinvoiced` | `FRAISREEL_REFACTURE` | Tinyint | `1` = refacturable au client |
| `receiptId` | `FRAISREEL_ID_JUSTIFICATIF` | Int | Référence du justificatif attaché |
| `number` | `FRAISREEL_NUM` | Smallint(3) | Ordre de la ligne dans la note |

#### Relations d'une ligne de frais

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `expensesReport.id` | `ID_LISTEFRAIS` | Note de frais parente |
| `project.id` | `ID_PROJET` | `-1`=Activité interne · `-2`=Absence · entier=Projet |
| `delivery.id` | `ID_MISSIONPROJET` | Livraison du projet |
| `batch.id` | `ID_LOT` | Lot (forfait+lots) |

> ⚠️ Contrairement aux temps, ici `project.id = -1` = **activité interne** et `project.id = -2` = **absence** (l'ordre est inversé par rapport aux feuilles de temps).

---

## Types de frais (TAB_TYPEFRAIS) — Référentiel par agence

Comme les types d'heures, les types de frais sont **configurés par agence** et identifiés par leur `TYPEFRS_REF` (pas l'ID interne).

### Champs du type de frais

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `ref` | `TYPEFRS_REF` | Int | **Référence** utilisée dans les lignes (`FRAISREEL_TYPEFRSREF`) |
| `name` | `TYPEFRS_NAME` | Varchar(250) | Libellé (Repas, Transport, Hôtel…) |
| `taxRate` | `TYPEFRS_TVA` | Decimal(15,5) | Taux de TVA par défaut pour ce type |
| `state` | `TYPEFRS_ETAT` | Tinyint | `0`=archivé · `1`=actif |
| `isGuest` | `TYPEFRS_GUEST` | Tinyint | `1` = type "invité" (repas avec invité) |
| `hasMealDeduction` | `TYPEFRS_MEAL_DEDUCTION` | Tinyint | `1` = déduction repas applicable |

### Cas spécial : Indemnités Kilométriques (IKV)

Quand `expenseTypeRef = 0` (valeur réservée), la ligne est une **indemnité kilométrique** :
- `amount` représente le **nombre de kilomètres** (pas un montant)
- Le montant réel est calculé automatiquement : `km × kilometerRateValue` (cf. `LISTEFRAIS_BKMVALUE`)
- Le barème IKV applicable est défini sur la note de frais via `kilometerRateRef` / `kilometerRateValue`

---

## Cycle de validation

```
État 2 (en attente)  →  validation manager  →  État 1 (validée)
État 2 (en attente)  →  rejet manager       →  État 3 (rejetée)
État 3 (rejetée)     →  correction resource →  État 2 (en attente)
État 1 (validée)     →  marquage remboursée →  isPaid = 1
```

La **clôture** (`isClosed = 1`) fige la note après validation — aucune modification ultérieure possible.

### Valider / rejeter / marquer remboursée via PUT

```http
PUT /expenses-reports/{id}
{
  "data": {
    "type": "expenses-reports",
    "id": "{id}",
    "attributes": {
      "state": 1,      ← 1=valider · 3=rejeter
      "isPaid": 1      ← marquer remboursée (après validation)
    }
  }
}
```

---

## Création d'une note de frais avec lignes

### Étape 1 — Créer la note mensuelle
```http
POST /expenses-reports
{
  "data": {
    "type": "expenses-reports",
    "attributes": { "term": "2025-03-01" },
    "relationships": {
      "resource": { "data": { "type": "resources", "id": "42" } }
    }
  }
}
```

### Étape 2 — Ajouter les lignes via PUT
```http
PUT /expenses-reports/{id}
{
  "data": {
    "type": "expenses-reports",
    "id": "{id}",
    "attributes": {
      "expenses": [
        {
          "date": "2025-03-05",
          "title": "Déjeuner client",
          "expenseTypeRef": 3,          ← type "Repas" configuré pour l'agence
          "amount": 45.00,              ← montant TTC
          "taxRate": 10,
          "isReinvoiced": 1,
          "project": { "id": "56" },
          "delivery": { "id": "78" }
        },
        {
          "date": "2025-03-06",
          "title": "Trajet domicile-client",
          "expenseTypeRef": 0,          ← IKV
          "amount": 85,                 ← nombre de km (pas un montant !)
          "project": { "id": "56" },
          "delivery": { "id": "78" }
        },
        {
          "date": "2025-03-10",
          "title": "Hôtel déplacement",
          "expenseTypeRef": 5,          ← type "Hôtel"
          "amount": 120.00,
          "taxRate": 20,
          "project": { "id": "-1" }     ← activité interne
        }
      ]
    }
  }
}
```

---

## Patterns de workflow

### Lister les notes en attente de validation pour une agence
```
GET /expenses-reports?state=2&agency={agencyId}&startDate=2025-03-01&endDate=2025-03-01
```

### Extraire toutes les lignes de frais refacturables d'un projet sur un mois
```
GET /expenses?project={projectId}&startDate=2025-03-01&endDate=2025-03-31&isReinvoiced=1
```

### Marquer une note comme remboursée après validation
```http
PUT /expenses-reports/{id}
{ "data": { "type": "expenses-reports", "id": "{id}", "attributes": { "isPaid": 1 } } }
```

### Clôturer une note validée
```http
PUT /expenses-reports/{id}
{ "data": { "type": "expenses-reports", "id": "{id}", "attributes": { "isClosed": 1 } } }
```

---

## Enumeration References

| Source | Utilisation |
|--------|-------------|
| `LISTEFRAIS_ETAT` : `1`, `2`, `3` | États de la note (valeurs fixes) |
| `TYPEFRS_REF` (par agence) | Référence du type de frais — récupérer via `included` d'une note |
| `data.setting.currency` | Devises — via `GET /application/dictionary` |
| `data.setting.taxRate` | Taux de TVA disponibles — via `GET /application/dictionary` |

---

## Gestion des erreurs

| Code HTTP | Signification |
|-----------|---------------|
| `200` | Succès |
| `422` | Validation — vérifier `errors[].title` + `errors[].detail` |
| `401` | Authentification échouée |
| `403` | Droits insuffisants |
| `404` | Note introuvable |

---

## Notes importantes

- Le `term` est **toujours le 1er du mois** : `2025-03-01`, jamais une autre date.
- **IKV** (`expenseTypeRef = 0`) : `amount` = **kilomètres**, pas un montant en €. Le montant est calculé côté serveur en multipliant par `kilometerRateValue` de la note.
- ⚠️ **Sens inversé par rapport aux feuilles de temps** : `project.id = -1` = activité interne, `project.id = -2` = absence (l'inverse des timesheets).
- Les **types de frais** (`TYPEFRS_REF`) sont configurés **par agence** — toujours les récupérer depuis le `included` d'une note existante, leur référence n'est pas universelle.
- Une note **clôturée** (`isClosed = 1`) est **immuable** — impossible à modifier ou supprimer.
- Le champ `advance` (`LISTEFRAIS_AVANCE`) permet de saisir une avance déjà versée au collaborateur, qui sera déduite du remboursement.
- `isReinvoiced = 1` sur une ligne indique que ce frais doit être refacturé au client. Il sera alors inclus dans les factures générées depuis le BDC si le type `Expenses` y est activé.
- Les types de frais avec `isGuest = 1` sont des frais "repas avec invité" — certains ERP les traitent différemment fiscalement.
