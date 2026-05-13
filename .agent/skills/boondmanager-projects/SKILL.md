---
name: boondmanager-projects
description: >
  Expert guide for interacting with the BoondManager API on the Projects domain.
  Use this skill whenever the user wants to search, read, create, or update projects
  in BoondManager, or when working with project sub-resources: deliveries (missions/CRA),
  groupments, batches/markers (lots/jalons), simulation, productivity, orders, purchases,
  actions, or billing details linked to a project. Also triggers on French equivalents:
  "projet", "mission", "CRA", "livraison", "lot", "jalon", "groupement", "régie",
  "forfait", "productivité projet", or any mention of BoondManager + gestion de projets.
---

# BoondManager — Projects

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth or JWT Bearer token
- **Format**: JSON:API — responses have `data`, `included`, `meta` root keys
- **Core table**: `TAB_PROJET` — one project can contain many deliveries (`TAB_MISSIONPROJET`)

---

## Project Modes (PRJ_TYPE) — Critical Concept

The `mode` (called `typeOf` in the API) drives the entire behaviour of a project:

| Mode value | Label | Description |
|---|---|---|
| `0` | Time & Materials (Régie) | Billing based on time spent; deliveries carry a daily rate |
| `1` | Fixed Price (Forfait) | Billing based on a fixed price; deliveries carry a fixed amount |
| `2` | Fixed Price + Batches | Forfait with batches (`lots`) and markers (`jalons`) for progress tracking |
| `3` | Internal | Internal project (no billing); `investment` = budget, `additionalTurnover` = price excl. tax |
| `4` | Fixed Price + Batches (billing by batch) | Like mode 2, with billing per batch |
| `-1` | Absence inactivity | System-managed |
| `-2` | Internal inactivity | System-managed |

> ⚠️ Several fields and behaviours **only apply to specific modes** — always check the mode before setting fields.

---

## Endpoints

### Search / List

```
GET /projects
```

**Key query parameters:**

| Parameter | Description |
|-----------|-------------|
| `keywords` | Search by reference, company name |
| `state` | Project state — cf. `data.setting.state.project` |
| `typeOf` | Project type/mode — cf. `data.setting.typeOf.project` |
| `startDate` / `endDate` | Date range filter |
| `agency` | Agency ID |
| `pole` | Pole ID |
| `mainManager` | Main manager ID |
| `resource` | Filter projects containing a specific resource delivery |
| `company` | CRM company ID |
| `page` / `numberPerPage` | Pagination |

---

### Get Default Values

```
GET /projects/default
```
Always call before `POST /projects` to retrieve pre-filled defaults.

---

### Create

```
POST /projects
Content-Type: application/json
```

**Minimal body:**
```json
{
  "data": {
    "type": "projects",
    "attributes": {
      "reference": "PRJ-2025-001",
      "startDate": "2025-01-01",
      "endDate": "2025-12-31",
      "mode": 0
    },
    "relationships": {
      "mainManager": { "data": { "type": "resources", "id": "12" } },
      "company": { "data": { "type": "companies", "id": "34" } }
    }
  }
}
```

---

### Read Profile

```
GET /projects/{id}
```

Returns the full project with `included` array (deliveries, groupments, agency, managers, etc.).

---

### Read Specific Tab

```
GET /projects/{id}/information          ← general info, dates, financials
GET /projects/{id}/simulation           ← budget simulation
GET /projects/{id}/batches-markers      ← lots & jalons (modes 2 & 4 only)
GET /projects/{id}/deliveries-groupments← deliveries and groupments list
GET /projects/{id}/productivity         ← production stats per resource
GET /projects/{id}/advantages           ← project-level advantages
GET /projects/{id}/purchases            ← linked purchases
GET /projects/{id}/orders               ← linked orders
GET /projects/{id}/actions              ← CRM actions linked to project
GET /projects/{id}/tasks                ← tasks
```

---

### Update

```
PUT /projects/{id}/information
PUT /projects/{id}/simulation
PUT /projects/{id}/batches-markers
```

**Body pattern:**
```json
{
  "data": {
    "type": "projects",
    "id": "{id}",
    "attributes": { "fieldToUpdate": "value" }
  }
}
```

---

## Project Data Model (TAB_PROJET)

### Identity & Status

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `reference` | `PRJ_REFERENCE` | Varchar(100) | Project reference |
| `state` | `PRJ_ETAT` | Int | Cf. `data.setting.state.project` |
| `mode` | `PRJ_TYPE` | Int | **Project mode** — see mode table above |
| `typeOf` | `PRJ_TYPEREF` | Int | Project type — cf. `data.setting.typeOf.project` |
| `stateReason` | `PRJ_STATE_REASON` | Tinyint | End-of-process reason |
| `stateReasonComment` | `PRJ_STATE_REASON_COMMENT` | Text | End-of-process comment |
| `creationDate` | `PRJ_DATE` | Datetime | Auto-set on creation |
| `updateDate` | `PRJ_DATEUPDATE` | Datetime | Last update |
| `lastActivityDate` | `PRJ_DATELASTACTIVITY` | Datetime | Last activity |

### Dates & Location

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `startDate` | `PRJ_DEBUT` | Date | Project start date |
| `endDate` | `PRJ_FIN` | Date | Project end date |
| `deliveryAddress` | `PRJ_ADR` | Varchar(250) | Delivery address |
| `deliveryPostcode` | `PRJ_CP` | Char(10) | Delivery postcode |
| `deliveryTown` | `PRJ_VILLE` | Varchar(100) | Delivery city |
| `deliveryCountry` | `PRJ_PAYS` | Varchar(100) | Delivery country (default: 'France') |
| `deliverySubdivision` | `PRJ_SUBDIVISION` | Varchar(6) | ISO-3166-2 |

### Financial Fields

| API field | DB column | Type | Mode | Description |
|-----------|-----------|------|------|-------------|
| `workUnitRate` | `PRJ_TAUXHORAIRE` | Decimal(15,5) | All | Work unit rate |
| `exchangeRate` | `PRJ_CHANGE` | Decimal(30,10) | All | Exchange rate |
| `currency` | `PRJ_DEVISE` | Int | All | Cf. `data.setting.currency` |
| `investment` | `PRJ_INVESTISSEMENT` | Decimal(30,10) | Mode 3: budget; others: additional investment |
| `additionalTurnover` | `PRJ_TARIFADDITIONNEL` | Decimal(30,10) | Mode 3: price excl. tax; others: additional turnover |
| `remainsToBeDone` | `PRJ_RESTEAFAIRE` | Decimal(15,5) | Mode 2 only | Remaining work (days) |
| `comments` | `PRJ_COMMENTAIRES` | Text | All | Information comments |

### Behaviour Flags

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `syncRemainsWithMarkers` | `PRJ_CORRELATIONJALON` | Tinyint | Mode 2 only — sync `remainsToBeDone` with marker progress |
| `showBatchesTab` | `PRJ_LOTSTAB` | Tinyint | Modes 2 & 4 — show batches tab in UI |
| `showMarkersOnBatches` | `PRJ_LOTVIEW` | Tinyint | Mode 2 only — allow marker creation on batches |
| `productivityView` | `PRJ_CONSOMMATIONVIEW` | Tinyint | Modes 1 & 2 — `0`=resources, `1`=deliveries, `2`=groupments |

### Relations (Foreign Keys)

| API field | DB column | Description |
|-----------|-----------|-------------|
| `agency.id` | `ID_SOCIETE` | Agency |
| `pole.id` | `ID_POLE` | Pole |
| `mainManager.id` | `ID_PROFIL` | Main manager (resource) |
| `projectManagers` | `ID_PROFILCDP` | List of project managers (pipe-separated IDs) |
| `opportunity.id` | `ID_AO` | Source opportunity |
| `company.id` | `ID_CRMSOCIETE` | Client company |
| `contact.id` | `ID_CRMCONTACT` | Client contact |
| `technicalContact.id` | `ID_CRMTECHNIQUE` | Technical contact |
| `billingIntermediary.id` | `ID_INTERMEDIAIRE_CRMSOCIETE` | Billing intermediary company |
| `billingIntermediaryContact.id` | `ID_INTERMEDIAIRE_CRMCONTACT` | Billing intermediary contact |

---

## Deliveries & Groupments (TAB_MISSIONPROJET)

A delivery is a line within a project linking either a **resource** or a **product** to the project with billing conditions. Groupments aggregate multiple deliveries.

### Endpoints

```
GET  /deliveries?project={id}      ← list deliveries for a project
GET  /deliveries/{id}              ← single delivery
POST /deliveries                   ← create delivery
PUT  /deliveries/{id}              ← update delivery

GET  /deliveries-groupments?project={id}  ← groupments list
```

### ITEM_TYPE — Delivery vs Groupment

| `itemType` | Description |
|---|---|
| `0` | Delivery linked to a resource |
| `1` | Delivery linked to a product |
| `5` | Groupment — proportional distribution |
| `6` | Groupment — weighted distribution |
| `7` | Groupment — manual distribution |

### Key Delivery Fields

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `title` | `MP_NOM` | Varchar(100) | Delivery title |
| `state` | `MP_TYPE` | Int | Cf. `data.setting.state.delivery` |
| `typeOf` | `MP_TYPE_PRESTATION` | Int | Cf. `data.setting.typeOf.delivery` |
| `startDate` | `MP_DEBUT` | Date | Delivery start date |
| `endDate` | `MP_FIN` | Date | Delivery end date |
| `dailyRate` | `MP_TARIF` | Decimal(30,10) | Daily price excl. tax |
| `hourlyRate` | `MP_TARIFHEURE` | Decimal(30,10) | Hourly price excl. tax |
| `averageDailyCost` | `MP_CJM` | Decimal(30,10) | Average daily cost |
| `workingDays` | `MP_NBJRSOUVRE` | Decimal(15,5) | Planned working days |
| `invoicedDays` | `MP_NBJRSFACTURE` | Decimal(30,10) | Invoiced days |
| `freeDays` | `MP_NBJRSGRATUIT` | Decimal(30,10) | Free (non-invoiced) days |
| `dailyExpenses` | `MP_FRSJOUR` | Decimal(30,10) | Daily net expenses |
| `monthlyExpenses` | `MP_FRSMENSUEL` | Decimal(30,10) | Monthly net expenses |
| `additionalTurnover` | `MP_TARIFADDITIONNEL` | Decimal(30,10) | Additional turnover (modes > 0) |
| `additionalInvestment` | `MP_INVESTISSEMENT` | Decimal(30,10) | Additional investment (modes > 0) |
| `weeklyDuration` | `MP_DUREEHEBDOMADAIRE` | Decimal(15,5) | Weekly working hours |
| `comments` | `MP_COMMENTAIRES` | Text | Information comments |
| `specialConditions` | `MP_CONDITIONS` | Text | Special conditions (or groupment contents) |
| `calendar` | `MP_CALENDRIER` | Varchar(100) | Calendar reference |
| `isDailyRateForced` | `MP_FORCETARIF` | Tinyint | Force daily rate (in groupment) |
| `isHourlyRateForced` | `MP_FORCETARIFHEURE` | Tinyint | Force hourly rate |
| `productQuantity` | `MP_PRODUCT_QUANTITY` | Decimal | Nb of licences sold (product delivery) |
| `productQuantityFree` | `MP_PRODUCT_QUANTITY_FREE` | Decimal | Nb of free licences |
| `productRate` | `MP_PRODUCT_TARIF` | Decimal | Price per licence excl. tax |
| `creationDate` | `MP_CREATEDAT` | Datetime | Auto-set |
| `updateDate` | `MP_UPDATEDAT` | Datetime | Auto-set |

### Delivery Relations

| API field | DB column | Description |
|-----------|-----------|-------------|
| `resource.id` / `product.id` | `ID_ITEM` | Resource or product linked (depends on `itemType`) |
| `project.id` | `ID_PROJET` | Parent project |
| `contract.id` | `ID_CONTRAT` | Resource contract used for this delivery |
| `purchase.id` | `ID_ACHAT` | Linked purchase (for subcontractor deliveries) |
| `groupment.id` | `ID_PARENT` | Parent groupment (if delivery is inside a groupment) |
| `purchaserDelivery.id` | `ID_MASTER` | Purchaser delivery (for subcontractor chain) |

---

## Batches & Markers (TAB_LOT / TAB_JALON)

Only relevant for projects with `mode` = `2` or `4`.

### Batches endpoint
```
GET /projects/{id}/batches-markers
PUT /projects/{id}/batches-markers
```

### Marker fields (TAB_JALON)

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `title` | `JALON_TITRE` | Varchar(100) | Marker title |
| `date` | `JALON_DATE` | Date | Marker date |
| `duration` | `JALON_DUREE` | Decimal(15,5) | Duration in days |
| `value` | `JALON_VALUE` | Decimal(15,5) | Progress rate (if no batch) OR progress in days (if in batch) |
| `resource.id` | `ID_PROFIL` | Int | Associated resource |
| `batch.id` | `ID_LOT` | Int | Parent batch (`0` = no batch) |

---

## Enumeration References

Resolve all integer codes via `GET /application/dictionary`:

| Dictionary key | Used for |
|---|---|
| `data.setting.state.project` | Project states |
| `data.setting.typeOf.project` | Project types + **modes** (`mode` key per entry) |
| `data.setting.state.delivery` | Delivery states |
| `data.setting.typeOf.delivery` | Delivery types |
| `data.setting.currency` | Currencies |
| `data.setting.typeOf.workingTime` | Working time types |

---

## Error Handling

| HTTP Code | Meaning |
|-----------|---------|
| `200` | Success |
| `422` | Validation error — check `errors[].title` + `errors[].detail` |
| `401` | Auth failure |
| `403` | Insufficient rights |
| `404` | Not found |

---

## Workflow Patterns

### Create a Time & Materials project (Régie)
```
1. GET /projects/default
2. POST /projects  { mode: 0, startDate, endDate, reference, company.id, mainManager.id }
3. POST /deliveries { project.id, itemType: 0, resource.id, startDate, endDate, dailyRate }
```

### Create a Fixed Price project (Forfait)
```
1. GET /projects/default
2. POST /projects  { mode: 1, startDate, endDate, reference, company.id }
3. POST /deliveries { project.id, itemType: 0, resource.id, workingDays, dailyRate, invoicedDays }
```

### Create a Fixed Price project with Batches (mode 2)
```
1. POST /projects  { mode: 2, showBatchesTab: 1, syncRemainsWithMarkers: 1 }
2. POST /deliveries { project.id, itemType: 0, resource.id, ... }
3. PUT  /projects/{id}/batches-markers  → add lots + jalons
```

### Add a subcontractor delivery (linked to a purchase)
```
POST /deliveries {
  project.id,
  itemType: 0,
  resource.id,          ← external resource
  contract.id,          ← resource's contract
  purchase.id           ← linked purchase
}
```

### Search active projects for a company
```
GET /projects?company={companyId}&state=1
```

### Get full productivity view
```
GET /projects/{id}/productivity
```

---

## Notes

- `TAB_MISSIONPROJET` covers both **deliveries** (resource or product lines) and **groupments** — distinguished by `ITEM_TYPE`.
- A **groupment** (types 5/6/7) is a virtual container aggregating deliveries; its `MP_CONDITIONS` field stores the list of included delivery IDs with distribution values.
- `remainsToBeDone` (`PRJ_RESTEAFAIRE`) is only meaningful for mode `2` and can be auto-synced from markers via `syncRemainsWithMarkers`.
- Projects created from an opportunity carry `opportunity.id`; the simulation tab mirrors the opportunity's simulation data.
- Dates follow ISO 8601: `YYYY-MM-DD`. Decimals use `.` as separator.
- The `included` array in `GET /projects/{id}` response typically contains: agency, pole, managers, company, contact, deliveries — avoiding extra calls.
