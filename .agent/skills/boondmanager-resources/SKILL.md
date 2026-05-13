---
name: boondmanager-resources
description: >
  Expert guide for interacting with the BoondManager API on the Resources (collaborateurs)
  domain. Use this skill whenever the user wants to search, read, create, or update resources
  (employees/consultants) in BoondManager, or when working with resource sub-resources such as
  contracts, technical documents (CV/TD), administrative data, absences, timesheets,
  expense reports, positionings, or advantages. Also triggers on French equivalents:
  "ressource", "collaborateur", "salarié", "consultant", "contrat RH", "données administratives",
  "fiche collaborateur", or any mention of BoondManager + personnel/people management.
---

# BoondManager — Resources (Collaborateurs)

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth (`Authorization: Basic base64(login:password)`) or JWT (`Authorization: Bearer <token>`)
- **Format**: JSON:API — responses have `data`, `included`, `meta` root keys
- **Resource type**: `resources` (maps to `TAB_PROFIL` with `PROFIL_MODEL = 'resource'`)

---

## Endpoints

### Search / List

```
GET /resources
```

**Key query parameters:**

| Parameter | Description |
|-----------|-------------|
| `keywords` | Search by name, email, reference |
| `typeOf` | Resource type (cf. `data.setting.typeOf.resource` from `/application/dictionary`) — value `1` = external |
| `state` | Resource state (cf. `data.setting.state.resource`) |
| `isAvailable` | `1` = available only |
| `startDate` / `endDate` | Availability window |
| `agency` | Agency ID (`TAB_SOCIETE.ID_SOCIETE`) |
| `pole` | Pole ID (`TAB_POLE.ID_POLE`) |
| `mainManager` | Manager ID (`TAB_USER.ID_USER`) |
| `page` | Pagination page (default 1) |
| `numberPerPage` | Results per page (default 25) |

---

### Get Default Values (before creation)

```
GET /resources/default
```
Returns default field values for a new resource — always call this before `POST /resources`.

---

### Create

```
POST /resources
Content-Type: application/json
```

**Minimal required body:**
```json
{
  "data": {
    "type": "resources",
    "attributes": {
      "lastName": "Dupont",
      "firstName": "Marie",
      "typeOf": 0
    }
  }
}
```

---

### Read Profile (all tabs)

```
GET /resources/{id}
```

Returns the full resource record. The response includes sub-tabs (see below) via the `included` array.

---

### Read Specific Tab

```
GET /resources/{id}/information
GET /resources/{id}/administrative
GET /resources/{id}/technical-data
GET /resources/{id}/times-reports
GET /resources/{id}/expenses-reports
GET /resources/{id}/absences-reports
GET /resources/{id}/positionings
GET /resources/{id}/projects
GET /resources/{id}/advantages
GET /resources/{id}/absences-accounts
GET /resources/{id}/followed-documents
GET /resources/{id}/actions
GET /resources/{id}/provider-invoices
```

---

### Update

```
PUT /resources/{id}/information       ← identity, contact, availability, tarif
PUT /resources/{id}/administrative    ← payroll, bank, admin data
PUT /resources/{id}/technical-data    ← CV, TD fields
```

**Body structure:**
```json
{
  "data": {
    "type": "resources",
    "id": "42",
    "attributes": {
      "fieldToUpdate": "value"
    }
  }
}
```

---

## Key Data Model (TAB_PROFIL — resource fields)

### Identity & Contact

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `lastName` | `PROFIL_NOM` | Varchar(100) | Last name |
| `firstName` | `PROFIL_PRENOM` | Varchar(100) | First name |
| `civility` | `PROFIL_CIVILITE` | Int | Cf. `data.setting.civility` from dictionary |
| `email` | `PROFIL_EMAIL` | Varchar(100) | Primary email (used for all comms) |
| `email2` | `PROFIL_EMAIL2` | Varchar(100) | Secondary email |
| `phone` | `PROFIL_TEL1` | Char(20) | Phone 1 |
| `phone2` | `PROFIL_TEL2` | Char(20) | Phone 2 |
| `address` | `PROFIL_ADR` | Varchar(250) | Address |
| `postcode` | `PROFIL_CP` | Char(10) | Postcode |
| `town` | `PROFIL_VILLE` | Varchar(100) | City |
| `country` | `PROFIL_PAYS` | Varchar(100) | Country (default: 'France') |
| `subdivision` | `PROFIL_SUBDIVISION` | Varchar(6) | ISO-3166-2 subdivision |
| `birthDate` | `PROFIL_DATENAISSANCE` | Date / null | Birth date |
| `birthPlace` | `PROFIL_LIEUNAISSANCE` | Varchar(100) | Place of birth |
| `nationality` | `PROFIL_NATIONALITE` | Varchar(100) | Nationality |
| `socialSecurityNumber` | `PROFIL_NUMSECU` | Char(21) | SSN |
| `familySituation` | `PROFIL_SITUATION` | Int | Cf. `data.setting.situation` from dictionary |
| `thumbnail` | `PROFIL_THUMBNAIL` | — | Profile photo |

### Status & Classification

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `state` | `PROFIL_ETAT` | Int | Resource state — cf. `data.setting.state.resource` |
| `typeOf` | `PROFIL_TYPE` | Int | Resource type — cf. `data.setting.typeOf.resource` (**value `1` = external**) |
| `function` | `PROFIL_STATUT` | Varchar(100) | Function/title |
| `reference` | `PROFIL_REFERENCE` | Varchar(250) | Internal reference |
| `stateReason` | `PROFIL_STATE_REASON` | Int | End-of-process reason |
| `stateReasonComment` | `PROFIL_STATE_REASON_COMMENT` | Text | End-of-process comment |
| `isVisible` | `PROFIL_VISIBILITE` | Tinyint | `1` = visible |
| `creationSource` | `PROFIL_CREATIONSOURCE` | Varchar(20) | `'manual'`, `'import_csv'`, `'linkedin'`, `'api'`, `'other'` |

### Availability & Rates

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `availabilityDate` | `PARAM_DATEDISPO` | Date | Availability date |
| `availabilityType` | `PARAM_TYPEDISPO` | Int | `1` = immediate (synced), `2` = after date (synced), `3` = immediate (not synced), `4` = after date (not synced) |
| `averageDailyPrice` | `PARAM_TARIF1` | Decimal | Average daily rate excl. tax |
| `mobilityArea` | `PARAM_MOBILITE` | Text | Mobility zones — cf. `data.setting.mobilityArea` |
| `currency` | `PARAM_DEVISE` | Int | Currency — cf. `data.setting.currency` |
| `exchangeRate` | `PARAM_CHANGE` | Decimal | Exchange rate |

### Relations (Foreign Keys)

| API field | DB column | Description |
|-----------|-----------|-------------|
| `agency.id` | `ID_SOCIETE` | Agency (TAB_SOCIETE) |
| `pole.id` | `ID_POLE` | Pole (TAB_POLE) |
| `mainManager.id` | `ID_RESPMANAGER` | Main manager (TAB_USER) |
| `hrManager.id` | `ID_RESPRH` | HR manager (TAB_USER) |
| `technicalDocument.id` | `ID_DT` | Technical document (TAB_DT) |

### Administrative / GDPR

| API field | DB column | Description |
|-----------|-----------|-------------|
| `gdprState` | `PROFIL_ETATGDPR` | `0` = no consent, `1` = consent obtained |
| `gdprExpirationDate` | `PROFIL_DATEGDPR` | GDPR expiry date |
| `seniorityDate` | `PROFIL_DDCA` | Seniority date |
| `seniorityDateValidity` | `PROFIL_VALIDITYDDCA` | Seniority date validity |
| `isSeniorityDateForced` | `PROFIL_FORCEDDCA` | `0` = auto, `1` = forced |
| `allowTDChange` | `PROFIL_ALLOWCHANGE` | `1` = resource can edit own TD from intranet |

---

## Contracts Sub-resource (TAB_CONTRAT)

Contracts are accessed via: `GET /contracts?resource={id}` or as `included` in `GET /resources/{id}`.

### Key Contract Fields

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `startDate` | `CTR_DEBUT` | Date | Contract start date |
| `endDate` | `CTR_FIN` | Date | Contract end date |
| `typeOf` | `CTR_TYPE` | Int | Contract type — cf. `data.setting.typeOf.contract` |
| `employeeCategory` | `CTR_CATEGORIE` | Int | Employee category — cf. `data.setting.typeOf.employee` |
| `classification` | `CTR_CLASSIFICATION` | Varchar(250) | Classification — cf. `data.setting.classification` |
| `workingTime` | `CTR_TPSTRAVAIL` | Int | Working time type — cf. `data.setting.typeOf.workingTime` |
| `weeklyDuration` | `CTR_DUREEHEBDOMADAIRE` | Decimal | Weekly hours |
| `workingDays` | `CTR_NBJRSOUVRE` | Decimal | Working days per month |
| `monthlyGrossSalary` | `CTR_SALAIREMENSUEL` | Decimal | Monthly gross salary |
| `hourlyGrossSalary` | `CTR_SALAIREHEURE` | Decimal | Hourly gross salary |
| `averageDailyCost` | `CTR_CJMCONTRAT` | Decimal | Average daily cost |
| `averageDailyCostProduction` | `CTR_CJMPRODUCTION` | Decimal | Average daily cost (production) |
| `dailyExpenses` | `CTR_FRSJOUR` | Decimal | Daily net expenses |
| `monthlyExpenses` | `CTR_FRSMENSUEL` | Decimal | Monthly net expenses |
| `probationEndDate` | `CTR_DATEPE1` | Date / null | End of probation period |
| `probationRenewalEndDate` | `CTR_DATEPE2` | Date / null | End of renewed probation |
| `probationState` | `CTR_ETAT_PE` | Smallint | Cf. `data.setting.state.probation` |
| `endReason` | `CTR_MOTIF_FIN_CONTRAT` | Int | Contract end reason |
| `comments` | `CTR_COMMENTAIRES` | Text | Comments |
| `calendar` | `CTR_CALENDRIER` | Varchar(100) | Calendar reference |
| `activityRate` | `CTR_TAUXACTIVITE` | Decimal | Activity rate |

---

## Comments & Free Text

| API field | DB column | Description |
|-----------|-----------|-------------|
| `informationComments` | `PARAM_COMMENTAIRE` | Info comments (visible tab) |
| `administrativeComments` | `PARAM_COMMENTAIRE2` | Admin comments (restricted) |

---

## Enumeration References

All integer codes for state/type fields are resolved via:
```
GET /application/dictionary
```

Key dictionary keys for resources:
- `data.setting.state.resource` — resource states
- `data.setting.typeOf.resource` — resource types (⚠️ `1` = external)
- `data.setting.typeOf.contract` — contract types (CDI, CDD, etc.)
- `data.setting.typeOf.employee` — employee categories
- `data.setting.typeOf.workingTime` — working time types
- `data.setting.civility` — civility values
- `data.setting.situation` — family situations
- `data.setting.currency` — currencies
- `data.setting.mobilityArea` — mobility zones
- `data.setting.classification` — classification levels
- `data.setting.state.probation` — probation states
- `data.setting.availability` — availability types

---

## Error Handling

| HTTP Code | Meaning |
|-----------|---------|
| `200` | Success |
| `422` | Validation error — check `errors` array in response body |
| `401` | Auth failure |
| `403` | Insufficient rights |
| `404` | Resource not found |
| `500` | Server error |

On `422`, the response body contains:
```json
{
  "errors": [
    { "title": "field_name", "detail": "error message" }
  ]
}
```

---

## Workflow Patterns

### Search for available consultants
```
GET /resources?state=1&isAvailable=1&keywords=react
```

### Create a new internal resource
1. `GET /resources/default` → get defaults
2. `POST /resources` with `typeOf = 0` (internal), name, email
3. `PUT /resources/{id}/information` to enrich

### Create an external resource (freelance/subcontractor)
Same as above but `typeOf = 1`, also set `providerContact.id` and `providerCompany.id`

### Update availability
```
PUT /resources/{id}/information
Body: { "data": { "type": "resources", "id": "{id}", "attributes": { "availabilityType": 1, "availabilityDate": null } } }
```

### Attach a contract
```
POST /contracts
Body: { "data": { "type": "contracts", "attributes": { "startDate": "2025-01-01", "typeOf": 1 }, "relationships": { "resource": { "data": { "type": "resources", "id": "{id}" } } } } }
```

---

## Notes

- `TAB_PROFIL` is shared between **resources** and **candidates**; always filter by `PROFIL_MODEL = 'resource'` when querying directly (the API handles this automatically via `/resources` vs `/candidates`).
- External resources (`typeOf = 1`) can be linked to a CRM company (`providerCompany`) and contact (`providerContact`).
- The `included` array in responses may contain related objects (agency, pole, manager, contracts, etc.) to avoid extra round-trips.
- Dates follow ISO 8601 format: `YYYY-MM-DD`.
- Monetary amounts are `Decimal(30,10)` — use strings or high-precision numbers.
