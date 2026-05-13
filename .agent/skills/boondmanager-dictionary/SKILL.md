---
name: boondmanager-dictionary
description: >
  Expert guide for the BoondManager /application/dictionary endpoint — the central
  reference that resolves all enumeration codes used across every other BoondManager
  API domain. Use this skill whenever the user needs to understand what integer values
  mean in BoondManager fields (states, types, currencies, work unit types, expense types,
  etc.), or when building a feature that requires listing available options for a field,
  or when populating dropdowns/selects from the API. Also triggers when the user asks
  "what are the possible values for X", "how do I get the list of contract types",
  "comment résoudre les codes d'état", "dictionnaire BoondManager", "référentiel",
  "énumération", or any mention of /application/dictionary.
---

# BoondManager — Dictionnaire Application (`/application/dictionary`)

## Vue d'ensemble

`GET /application/dictionary` est l'**endpoint socle** de toute intégration BoondManager. Il retourne un objet JSON unique contenant **tous les référentiels de l'instance** : états, types, devises, zones géographiques, compétences, etc.

```
GET /application/dictionary
Authorization: Bearer {token}
```

La réponse a la structure :
```json
{
  "data": {
    "setting": {
      "state": { ... },
      "typeOf": { ... },
      "currency": [ ... ],
      "activityArea": [ ... ],
      ...
    }
  }
}
```

> **Important** : la plupart des référentiels sont **configurés par agence** et **propres à chaque instance**. Les valeurs `id` ne sont pas universelles — toujours interroger le dictionnaire de l'instance cible avant de coder en dur des valeurs.

---

## Endpoint complémentaire : dictionnaire par agence

```
GET /application/dictionary?agency={agencyId}
```

Certains référentiels (types d'heures, types de frais, barèmes IKV) sont spécifiques à une agence. Ce paramètre permet de récupérer le dictionnaire filtré pour une agence donnée.

---

## Carte complète des clés `data.setting.*`

### États (`data.setting.state.*`)

Ces clés retournent une liste d'objets `{ id, label }` permettant de résoudre les codes entiers stockés dans les champs d'état.

| Clé | Utilisée pour |
|-----|---------------|
| `data.setting.state.resource` | États d'une ressource (`PROFIL_ETAT`) |
| `data.setting.state.candidate` | États d'un candidat (`PROFIL_ETAT`) |
| `data.setting.state.opportunity` | États d'une opportunité (`AO_ETAT`) |
| `data.setting.state.positioning` | États d'un positionnement (`POS_ETAT`) |
| `data.setting.state.project` | États d'un projet (`PRJ_ETAT`) |
| `data.setting.state.delivery` | États d'une livraison (`MP_TYPE`) |
| `data.setting.state.order` | États d'un bon de commande (`BDC_ETAT`) |
| `data.setting.state.invoice` | États d'une facture (`FACT_ETAT`) |
| `data.setting.state.payment` | États d'un paiement (`PMT_ETAT`) |
| `data.setting.state.purchase` | États d'un achat (`ACHAT_ETAT`) |
| `data.setting.state.contact` | États d'un contact CRM (`CCON_TYPE`) |
| `data.setting.state.company` | États d'une société CRM (`CSOC_TYPE`) |
| `data.setting.state.probation` | États de période d'essai (`CTR_ETAT_PE`) |
| `data.setting.state.billableitem` | États d'un élément facturable |

### Types (`data.setting.typeOf.*`)

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.typeOf.resource` | Types de ressource ⚠️ valeur `1` = externe | `PROFIL_TYPE` |
| `data.setting.typeOf.project` | Types + **modes** de projet (`mode` key) | `PRJ_TYPE` / `PRJ_TYPEREF` |
| `data.setting.typeOf.delivery` | Types de livraison | `MP_TYPE_PRESTATION` |
| `data.setting.typeOf.contract` | Types de contrat (CDI, CDD, freelance…) | `CTR_TYPE` / `PARAM_CONTRAT` |
| `data.setting.typeOf.employee` | Catégories de salarié (ETAM, cadre…) | `CTR_CATEGORIE` |
| `data.setting.typeOf.workingTime` | Types de temps de travail (35h, forfait jour…) | `CTR_TPSTRAVAIL` |
| `data.setting.typeOf.purchase` | Catégories d'achat (prestation, licence…) | `ACHAT_CATEGORIE` |
| `data.setting.typeOf.subscription` | Types d'abonnement | `ACHAT_TYPE` |

### Finances & Comptabilité

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.currency` | Devises (EUR, USD, GBP…) | `*_DEVISE`, `*_DEVISEAGENCE` |
| `data.setting.taxRate` | Taux de TVA disponibles | `*_TAUXTVA`, `*_LISTETAUXTVA` |
| `data.setting.paymentMethod` | Modes de paiement (virement, chèque…) | `*_TYPEPAYMENT` |
| `data.setting.paymentTerm` | Conditions de règlement (30j, 45j fin de mois…) | `*_CONDREGLEMENT` |

### Compétences & Profils techniques

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.activityArea` | Domaines d'activité — **format `option.id`** | `AO_APPLICATIONS`, `CCON_APPLICATIONS`, etc. |
| `data.setting.expertiseArea` | Domaines d'expertise des sociétés | `CSOC_INTERVENTION` |
| `data.setting.tool` | Technologies / outils (Java, Python, AWS…) | `AO_OUTILS`, `CCON_OUTILS`, `DT_OUTILS` |
| `data.setting.experience` | Niveaux d'expérience | `DT_EXPERIENCE` |
| `data.setting.languageSpoken` | Langues parlées | `DT_LANGUES` |
| `data.setting.languageLevel` | Niveaux de langue (débutant → courant…) | `DT_LANGUES` |
| `data.setting.mobilityArea` | Zones de mobilité géographique | `PARAM_MOBILITE`, `AO_LIEU` |
| `data.setting.classification` | Niveaux de classification (cadre A, B…) | `CTR_CLASSIFICATION` |

### Personnes & Identité

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.civility` | Civilités (M., Mme…) | `PROFIL_CIVILITE`, `CCON_CIVILITE` |
| `data.setting.situation` | Situations familiales (célibataire, marié…) | `PROFIL_SITUATION` |
| `data.setting.evaluation` | Évaluations candidats | `PROFIL_STATUT` (candidat) |
| `data.setting.availability` | Types de disponibilité | `PARAM_TYPEDISPO` |

### Origines & Sources

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.origin` | Types d'origine (inbound, referral, salon…) | `AO_TYPESOURCE`, `CSOC_TYPESOURCE`, `CCON_TYPESOURCE` |
| `data.setting.source` | Sources candidats | `PARAM_TYPESOURCE` |

### Projets & Production

| Clé | Utilisée pour | Champ DB |
|-----|---------------|----------|
| `data.setting.duration` | Durées de mission (3 mois, 6 mois…) | `AO_DUREE` |
| `data.setting.action` | Types d'actions CRM + entité associée | `ACTION_TYPE` |

---

## Particularités importantes

### `data.setting.activityArea` — Format spécial `option.id`

Les domaines d'activité utilisent un format composite `category|domain` :

```json
{
  "activityArea": [
    {
      "id": "IT",
      "label": "Informatique",
      "options": [
        { "id": "IT_DEV", "label": "Développement" },
        { "id": "IT_INFRA", "label": "Infrastructure" }
      ]
    }
  ]
}
```

Les valeurs stockées dans les champs (ex: `AO_APPLICATIONS`) utilisent `option.id` (ex: `"IT_DEV"`), **pas** l'`id` parent. Les valeurs sont séparées par `|` : `"IT_DEV|IT_INFRA"`.

### `data.setting.typeOf.project` — Double usage : type ET mode

Chaque entrée contient deux valeurs distinctes :
- `id` → le **type** du projet (ex: "Projet client", "Interne")
- `mode` → le **mode de facturation** (0=régie, 1=forfait, 2=forfait+lots, etc.)

Ces deux valeurs correspondent à deux champs différents : `PRJ_TYPEREF` (type) et `PRJ_TYPE` (mode).

### `data.setting.tool` — Format avec niveau

Les outils dans les champs API sont stockés avec leur niveau (1–5) :
```
"Java|3#Python|4#AWS|2"   ← outil|niveau séparés par #
```
Mais le dictionnaire retourne juste la liste des outils `{ id, label }` sans niveaux. Les niveaux (1–5) sont libres.

---

## Autres endpoints `/application/*`

En plus du dictionnaire, l'espace `/application` expose d'autres endpoints utiles :

| Endpoint | Description |
|----------|-------------|
| `GET /application/currentUser` | Données de l'utilisateur authentifié |
| `GET /application/status` | Statut de l'API et de l'instance |
| `GET /application/settings` | Paramètres de configuration de l'instance |
| `PUT /application/settings` | Modifier les paramètres |
| `GET /application/language` | Langue courante |
| `GET /application/perimeters` | Périmètres accessibles (agences, pôles…) |
| `GET /application/flags` | Flags disponibles |
| `GET /application/dynamicFilters` | Filtres dynamiques configurés |
| `GET /application/assignments` | Assignations de l'utilisateur courant |
| `GET /application/geoCities` | Villes géolocalisées |
| `GET /application/weekendAndBankHolidays` | Jours fériés et week-ends |
| `GET /application/readDatabase` | Lecture directe de la base (admin) |
| `GET /application/resetPassword` | Réinitialisation de mot de passe |

---

## Patterns de workflow

### Bootstrap d'une intégration — charger tous les référentiels au démarrage
```
GET /application/dictionary
→ Stocker en cache les listes de states, types, currencies, activityAreas…
→ Rafraîchir périodiquement (les admins peuvent modifier les valeurs)
```

### Résoudre un code état avant affichage
```javascript
// Exemple : résoudre PRJ_ETAT = 3
const states = dictionary.data.setting.state.project;
const label = states.find(s => s.id === 3)?.label ?? 'Inconnu';
// → "En cours"
```

### Alimenter un select de types de contrat
```
GET /application/dictionary
→ data.setting.typeOf.contract
→ Mapper { id, label } pour alimenter la liste déroulante
```

### Obtenir les modes de projet disponibles
```
GET /application/dictionary
→ data.setting.typeOf.project
→ Chaque entrée a { id (typeRef), label, mode (PRJ_TYPE) }
→ Filtrer par mode pour n'afficher que les forfaits : entries.filter(e => e.mode === 1)
```

### Lister les taux de TVA configurés pour l'agence
```
GET /application/dictionary?agency={agencyId}
→ data.setting.taxRate  ← liste des taux disponibles pour cette agence
```

### Récupérer les jours fériés pour les calculs de planification
```
GET /application/weekendAndBankHolidays?year=2025&agency={agencyId}
→ Retourne la liste des jours non ouvrés
```

---

## Notes importantes

- **Le dictionnaire est propre à chaque instance** — ne jamais coder en dur les valeurs `id`. Ce qui vaut `3` pour "En cours" chez un client peut être `5` chez un autre.
- **Mettre en cache** la réponse du dictionnaire côté application — elle ne change que lorsqu'un administrateur modifie la configuration. Un rafraîchissement quotidien est généralement suffisant.
- **`data.setting.activityArea`** utilise `option.id` (l'identifiant enfant), pas `id` parent — erreur classique.
- **`data.setting.typeOf.project`** encode à la fois le type (`id` → `PRJ_TYPEREF`) et le mode (`mode` → `PRJ_TYPE`) dans la même entrée.
- Les **types d'heures** et **types de frais** ne sont **pas dans le dictionnaire général** — ils sont spécifiques par agence et retournés dans les `included` des feuilles de temps et notes de frais (cf. skills `boondmanager-timesheets` et `boondmanager-expenses`).
- `data.setting.action` contient les types d'actions CRM avec l'entité associée à chaque type — indispensable pour construire correctement une action (cf. skill `boondmanager-actions`).
