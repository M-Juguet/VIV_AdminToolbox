---
name: boondmanager-positionings-purchases
description: >
  Expert guide for interacting with the BoondManager API on Positionings and Purchases —
  the two missing pieces of the full service delivery cycle. Use this skill whenever the
  user wants to search, read, create, or update positionings (propositions de ressources
  sur une opportunité) or purchases (achats de prestation sous-traitée, abonnements,
  licences). Also triggers when linking a delivery to a subcontractor purchase, managing
  the commercial pipeline of resource proposals, or tracking provider costs on a project.
  Triggers on French equivalents: "positionnement", "proposition de ressource", "achat",
  "sous-traitance", "achat de prestation", "fournisseur prestation", "abonnement",
  "refacturation achat", or any mention of BoondManager + cycle commercial prestation /
  achats fournisseurs.
---

# BoondManager — Positionings & Purchases

## Place dans le cycle prestation — Vue d'ensemble

```
Opportunité (TAB_AO)
    └── Positionnement (TAB_POSITIONNEMENT)   ← "Qui propose-t-on sur cet AO ?"
            └── si gagné → Livraison (TAB_MISSIONPROJET) dans un Projet
                                └── Achat (TAB_ACHAT)   ← "Combien paie-t-on le sous-traitant ?"
                                        └── Paiement fournisseur (TAB_PAIEMENT)
```

**Positionnement** = étape commerciale amont : une ressource (ou un produit) est proposée sur une opportunité, avec un TJM proposé et des dates.

**Achat** = engagement de coût fournisseur lié à un projet : sous-traitance, licence, abonnement, matériel…

---

## 1. POSITIONINGS — Positionnements (`/positionings`)

### Endpoints

```
GET    /positionings                       ← liste / recherche
POST   /positionings                       ← créer un positionnement
GET    /positionings/{id}                  ← profil complet
PUT    /positionings/{id}                  ← mettre à jour
DELETE /positionings/{id}                  ← supprimer
```

Accès contextuel (retourné dans `included`) :
```
GET /opportunities/{id}/positionings       ← positionnements d'une opportunité
GET /resources/{id}/positionings           ← positionnements d'une ressource
GET /candidates/{id}/positionings          ← positionnements d'un candidat
GET /projects/{id}/positionings            ← positionnements liés à un projet
```

### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `keywords` | Recherche textuelle |
| `state` | État du positionnement — cf. `data.setting.state.positioning` |
| `opportunity` | ID de l'opportunité (`TAB_AO.ID_AO`) |
| `resource` | ID de la ressource ou du candidat (`TAB_PROFIL.ID_PROFIL`) |
| `project` | ID du projet lié (`TAB_PROJET.ID_PROJET`) |
| `agency` | ID agence |
| `pole` | ID pôle |
| `startDate` / `endDate` | Plage de dates sur `startDate` du positionnement |
| `page` / `numberPerPage` | Pagination |

### Modèle de données — Positioning (TAB_POSITIONNEMENT)

#### Identité & Statut

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `state` | `POS_ETAT` | Int | État — cf. `data.setting.state.positioning` |
| `itemType` | `ITEM_TYPE` | Tinyint | `0` = ressource ou candidat · `1` = produit |
| `stateReason` | `POS_STATE_REASON` | Int | Motif de fin de processus |
| `stateReasonComment` | `POS_STATE_REASON_COMMENT` | Text | Commentaire de fin de processus |
| `shield` | `POS_SHIELD` | Tinyint | Complétude champs conditionnels : `0`=incomplet · `1`=minimum · `2`=complet |
| `creationSource` | `POS_CREATIONSOURCE` | Varchar(20) | `'manual'`, `'api'`, `'linkedin'`… |
| `creationDate` | `POS_DATE` | Datetime | Auto-set |
| `updateDate` | `POS_DATEUPDATE` | Datetime | Dernière mise à jour |

#### Dates & Tarification (ressource/candidat)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `startDate` | `POS_DEBUT` | Date | Date de début de la prestation proposée |
| `endDate` | `POS_FIN` | Date | Date de fin |
| `dailyRate` | `POS_TARIF` | Decimal(30,10) | **TJM proposé au client** (prix de vente HT) |
| `averageDailyCost` | `POS_CJM` | Decimal(30,10) | **Coût journalier moyen** (coût interne) |
| `invoicedDays` | `POS_NBJRSFACTURE` | Decimal(30,10) | Nombre de jours facturés |
| `freeDays` | `POS_NBJRSGRATUIT` | Decimal(30,10) | Nombre de jours gratuits |
| `additionalTurnover` | `POS_TARIFADDITIONNEL` | Decimal(30,10) | CA additionnel |
| `additionalInvestment` | `POS_INVESTISSEMENT` | Decimal(30,10) | Investissement additionnel |
| `syncSimulation` | `POS_CORRELATION` | Tinyint | `1` = synchroniser avec la simulation de l'opportunité |

#### Tarification produit (si `itemType = 1`)

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `productQuantity` | `POS_PRODUCT_QUANTITY` | Quantité de licences vendues |
| `productQuantityFree` | `POS_PRODUCT_QUANTITY_FREE` | Licences gratuites |
| `productRate` | `POS_PRODUCT_TARIF` | Prix HT par licence |

#### Commentaires

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `comments` | `POS_COMMENTAIRE` | Commentaires libres (max 500 car.) |

#### Relations

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `opportunity.id` | `ID_AO` | Opportunité parente (TAB_AO) |
| `resource.id` / `candidate.id` | `ID_ITEM` | Ressource ou candidat positionné (si `itemType=0`) |
| `product.id` | `ID_ITEM` | Produit positionné (si `itemType=1`) |
| `project.id` | `ID_PROJET` | Projet issu de ce positionnement (si gagné) |
| `mainManager.id` | `ID_RESPPROFIL` | Responsable commercial du positionnement |

---

### Cycle de vie d'un positionnement

```
Proposition envoyée → En attente réponse client → Accepté → Projet créé (livraison)
                                                 → Refusé  → Fin de processus
```

Les états exacts sont configurés via `data.setting.state.positioning` dans le dictionnaire. Les étapes typiques dans une ESN sont : proposé, entretien, shortlisté, accepté, refusé, sans suite.

**Conversion en projet** : quand un positionnement est accepté, il est converti manuellement (ou via API) en livraison dans un projet. Le lien est conservé via `project.id`.

---

## 2. PURCHASES — Achats (`/purchases`)

### Endpoints

```
GET    /purchases                          ← liste / recherche
GET    /purchases/default                  ← valeurs par défaut
POST   /purchases                          ← créer un achat
GET    /purchases/{id}                     ← profil complet
GET    /purchases/{id}/information         ← onglet informations
PUT    /purchases/{id}/information         ← mettre à jour
GET    /purchases/{id}/payments            ← paiements fournisseurs liés
GET    /purchases/{id}/tasks               ← tâches
```

Accès contextuel :
```
GET /projects/{id}/purchases               ← achats d'un projet
```

### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `keywords` | Référence, titre |
| `state` | État — cf. `data.setting.state.purchase` |
| `category` | Catégorie — cf. `data.setting.typeOf.purchase` |
| `project` | ID projet lié |
| `company` | ID société fournisseur |
| `agency` | ID agence |
| `pole` | ID pôle |
| `startDate` / `endDate` | Plage de dates |
| `isRebilled` | `1` = achats refacturables uniquement |
| `page` / `numberPerPage` | Pagination |

### Modèle de données — Purchase (TAB_ACHAT)

#### Identité & Statut

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `reference` | `ACHAT_REF` | Varchar(250) | Référence interne de l'achat |
| `providerReference` | `ACHAT_REFFOURNISSEUR` | Varchar(250) | Référence fournisseur |
| `title` | `ACHAT_TITLE` | Varchar(150) | Libellé de l'achat |
| `state` | `ACHAT_ETAT` | Int | État — cf. `data.setting.state.purchase` |
| `category` | `ACHAT_CATEGORIE` | Int | Catégorie — cf. `data.setting.typeOf.purchase` |
| `subscriptionType` | `ACHAT_TYPE` | Int | Type d'abonnement — cf. `data.setting.typeOf.subscription` |
| `comments` | `ACHAT_COMMENTAIRE` | Text | Commentaires libres |
| `showComments` | `ACHAT_SHOWCOMMENTAIRE` | Tinyint | `1` = afficher commentaires sur PDF |

#### Dates & Montants

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `date` | `ACHAT_DATE` | Date | Date de l'achat |
| `startDate` | `ACHAT_DEBUT` | Date | Début de la période |
| `endDate` | `ACHAT_FIN` | Date | Fin de la période |
| `quantity` | `ACHAT_QUANTITE` | Decimal(15,5) | Quantité |
| `amountExcludingTax` | `ACHAT_MONTANTHT` | Decimal(30,10) | Montant HT fournisseur |
| `amountIncludingTax` | `ACHAT_MONTANTTTC` | Decimal(30,10) | Montant TTC fournisseur |
| `totalExcludingTax` | `ACHAT_TOTALHT` | Decimal(30,10) | Total HT (quantité × montant) |
| `totalIncludingTax` | `ACHAT_TOTALTTC` | Decimal(30,10) | Total TTC |
| `taxRate` | `ACHAT_TAUXTVA` | Decimal(15,5) | Taux de TVA |
| `taxRates` | `ACHAT_LISTETAUXTVA` | Tinytext | Liste de taux TVA pipe-séparés |
| `currency` | `ACHAT_DEVISE` | Int | Devise — cf. `data.setting.currency` |
| `exchangeRate` | `ACHAT_CHANGE` | Decimal(30,10) | Taux de change |
| `paymentMethod` | `ACHAT_TYPEPAYMENT` | Int | Mode de paiement — cf. `data.setting.paymentMethod` |
| `paymentTerm` | `ACHAT_CONDREGLEMENT` | Int | Conditions de règlement — cf. `data.setting.paymentTerm` |

#### Refacturation

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `isRebilled` | `ACHAT_REFACTURE` | Tinyint | `1` = cet achat doit être refacturé au client |
| `rebilledRate` | `ACHAT_TAUXREFACTURATION` | Float(4) | Taux de refacturation (ex : `1.1` = +10%) |
| `rebilledPrice` | `ACHAT_TARIFFACTURE` | Decimal(30,10) | Prix de refacturation HT (si forcé manuellement) |

#### Relations

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `project.id` | `ID_PROJET` | Projet lié |
| `providerCompany.id` | `ID_CRMSOCIETE` | Société fournisseur (TAB_CRMSOCIETE) |
| `providerContact.id` | `ID_CRMCONTACT` | Contact fournisseur |
| `billingDetails.id` | `ID_COORDONNEES` | Coordonnées de facturation |
| `pole.id` | `ID_POLE` | Pôle |
| `agency.id` | `ID_SOCIETE` | Agence |
| `mainManager.id` | `ID_PROFIL` | Responsable de l'achat |

---

### Lien Achat ↔ Livraison (sous-traitance)

Quand une livraison est assurée par une ressource **externe** (sous-traitant), elle porte un `purchase.id` (`ID_ACHAT` dans `TAB_MISSIONPROJET`) qui pointe vers l'achat correspondant. Ce lien permet de :
- suivre le coût fournisseur associé à chaque livraison
- calculer la **marge** : TJM client (livraison) − coût fournisseur (achat)
- déclencher la **refacturation** si `isRebilled = 1`

```
TAB_MISSIONPROJET.ID_ACHAT → TAB_ACHAT.ID_ACHAT
```

---

## Enumeration References

| Clé dictionnaire | Utilisation |
|---|---|
| `data.setting.state.positioning` | États du positionnement |
| `data.setting.state.purchase` | États de l'achat |
| `data.setting.typeOf.purchase` | Catégories d'achat (prestation, licence, matériel…) |
| `data.setting.typeOf.subscription` | Types d'abonnement |
| `data.setting.paymentMethod` | Modes de paiement |
| `data.setting.paymentTerm` | Conditions de règlement |
| `data.setting.currency` | Devises |

---

## Workflow Patterns

### Positionner une ressource sur une opportunité
```http
POST /positionings
{
  "data": {
    "type": "positionings",
    "attributes": {
      "startDate": "2025-04-01",
      "endDate": "2025-09-30",
      "dailyRate": 650,
      "state": 1,                             ← état "proposé" (cf. dictionnaire)
      "comments": "Profil senior Java, 5 ans d'expérience"
    },
    "relationships": {
      "opportunity": { "data": { "type": "opportunities", "id": "84" } },
      "resource":    { "data": { "type": "resources",     "id": "42" } }
    }
  }
}
```

### Créer un achat de sous-traitance lié à un projet
```http
POST /purchases
{
  "data": {
    "type": "purchases",
    "attributes": {
      "title": "Prestation développement - Mars 2025",
      "startDate": "2025-03-01",
      "endDate": "2025-03-31",
      "amountExcludingTax": 400,              ← TJM fournisseur HT
      "quantity": 18,                          ← nb de jours
      "taxRate": 20,
      "isRebilled": 0,                         ← pas de refacturation directe
      "category": 1                            ← catégorie "prestation" (cf. dictionnaire)
    },
    "relationships": {
      "project":         { "data": { "type": "projects",  "id": "56" } },
      "providerCompany": { "data": { "type": "companies", "id": "12" } }
    }
  }
}
```

### Lister les positionnements ouverts sur une opportunité
```
GET /positionings?opportunity={aoId}&state=1
```

### Lister tous les achats refacturables d'un projet
```
GET /purchases?project={projectId}&isRebilled=1
```

### Chercher les positionnements d'une ressource (pipeline)
```
GET /positionings?resource={resourceId}
```

---

## Notes importantes

- Un positionnement peut pointer vers une **ressource** (`ITEM_TYPE=0`, `TAB_PROFIL`) ou un **produit** (`ITEM_TYPE=1`, `TAB_PRODUIT`). La distinction est critique pour les champs de tarification (TJM vs prix/licence).
- `syncSimulation = 1` (`POS_CORRELATION`) synchronise le TJM du positionnement avec la simulation financière de l'opportunité parente — ne pas modifier `dailyRate` manuellement dans ce cas.
- La **conversion positionnement → projet** n'est pas un appel API dédié : elle se fait en créant manuellement un projet et une livraison, puis en mettant à jour `project.id` sur le positionnement.
- Sur un achat, `amountExcludingTax` est le **coût unitaire** (TJM fournisseur), `quantity` est la quantité (nb de jours), `totalExcludingTax` est calculé automatiquement (`amountExcludingTax × quantity`).
- `isRebilled = 1` rend l'achat visible dans les éléments facturables du BDC client si le type `Purchases` y est activé. `rebilledRate` permet d'appliquer une majoration automatique (ex: `1.15` = +15% sur le coût fournisseur).
- Le lien `TAB_MISSIONPROJET.ID_ACHAT` crée la chaîne sous-traitance : une livraison externe est toujours associée à un achat pour le suivi des marges.
