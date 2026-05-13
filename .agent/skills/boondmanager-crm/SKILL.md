---
name: boondmanager-crm
description: >
  Expert guide for interacting with the BoondManager API on the CRM domain: companies,
  contacts, and opportunities. Use this skill whenever the user wants to search, read,
  create, or update CRM records in BoondManager — including companies (clients, prospects,
  providers, partners), their contacts, and opportunities (appels d'offres). Also triggers
  for sub-resources: company actions, contacts list, positionings, projects, invoices, and
  opportunity simulation or positionings. Triggers on French equivalents: "société CRM",
  "client", "prospect", "fournisseur", "contact", "opportunité", "appel d'offres", "AO",
  "pipeline commercial", or any mention of BoondManager + prospection/CRM/commercial.
---

# BoondManager — CRM (Companies, Contacts, Opportunities)

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth or JWT Bearer token
- **Format**: JSON:API — responses have `data`, `included`, `meta` root keys
- **3 core entities**: `companies` (TAB_CRMSOCIETE) · `contacts` (TAB_CRMCONTACT) · `opportunities` (TAB_AO)

---

## CRM Relationships — Key Architecture

```
TAB_CRMSOCIETE (company)
    ├── has many TAB_CRMCONTACT (contacts)        ID_CRMSOCIETE → contacts
    ├── has many TAB_AO (opportunities)            ID_CRMSOCIETE → opportunities
    ├── has one  TAB_CRMSOCIETE (mother company)   ID_RESPSOC   → parent
    └── referenced by TAB_PROJET, TAB_PROFIL (provider), TAB_FACTURATION...

TAB_AO (opportunity)
    ├── belongs to TAB_CRMSOCIETE                  ID_CRMSOCIETE
    ├── belongs to TAB_CRMCONTACT                  ID_CRMCONTACT
    └── can spawn  TAB_PROJET                      (via conversion)
```

---

## 1. COMPANIES (`/companies`)

### Endpoints

```
GET    /companies                    ← search / list
GET    /companies/default            ← default values before creation
POST   /companies                    ← create
GET    /companies/{id}               ← full profile
GET    /companies/{id}/information   ← information tab
PUT    /companies/{id}/information   ← update information
```

#### Sub-resource tabs (read-only)
```
GET /companies/{id}/contacts         ← linked contacts
GET /companies/{id}/opportunities    ← linked opportunities
GET /companies/{id}/projects         ← linked projects
GET /companies/{id}/actions          ← CRM actions
GET /companies/{id}/invoices         ← invoices
GET /companies/{id}/tasks            ← tasks
```

### Search Parameters

| Parameter | Description |
|-----------|-------------|
| `keywords` | Search by name, SIREN, VAT, reference |
| `state` | Company state — cf. `data.setting.state.company` |
| `agency` | Agency ID |
| `pole` | Pole ID |
| `mainManager` | Main manager resource ID |
| `page` / `numberPerPage` | Pagination |

### Company Data Model (TAB_CRMSOCIETE)

#### Identity & Legal

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `name` | `CSOC_SOCIETE` | Varchar(100) | Company name |
| `state` | `CSOC_TYPE` | Int | Cf. `data.setting.state.company` (client, prospect, provider…) |
| `legalStatus` | `CSOC_STATUT` | Varchar(100) | Legal form (SARL, SAS, SA…) |
| `siren` | `CSOC_SIREN` | Varchar(100) | National identification number (SIREN) |
| `vat` | `CSOC_TVA` | Varchar(100) | VAT number |
| `ape` | `CSOC_NAF` | Varchar(100) | APE/NAF code |
| `nic` | `CSOC_NIC` | Char(5) | Internal ranking number |
| `rcs` | `CSOC_RCS` | Varchar(100) | Registered office |
| `staff` | `CSOC_EFFECTIF` | Int(6) | Number of employees |
| `website` | `CSOC_WEB` | Varchar(100) | Website URL |
| `providerNumber` | `CSOC_NUMERO` | Varchar(250) | Provider number |
| `thumbnail` | `CSOC_THUMBNAIL` | Varchar(100) | Company logo/photo |

#### Address & Contact

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `address` | `CSOC_ADR` | Varchar(250) | Address |
| `postcode` | `CSOC_CP` | Char(10) | Postcode |
| `town` | `CSOC_VILLE` | Varchar(100) | City |
| `country` | `CSOC_PAYS` | Varchar(100) | Country (default: 'France') |
| `subdivision` | `CSOC_SUBDIVISION` | Varchar(6) | ISO-3166-2 |
| `phone` | `CSOC_TEL` | Char(20) | Main phone |
| `fax` | `CSOC_FAX` | Char(20) | Fax |

#### Business Information

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `expertiseArea` | `CSOC_INTERVENTION` | Text | Expertise areas — cf. `data.setting.expertiseArea` |
| `informationComments` | `CSOC_METIERS` | Text | Information comments / business description |
| `departments` | `CSOC_SERVICES` | Text | Departments list, pipe-separated (e.g. `"engineering\|purchases"`) |
| `originType` | `CSOC_TYPESOURCE` | Int | Origin type — cf. `data.setting.origin` |
| `originDetail` | `CSOC_SOURCE` | Varchar(100) | Origin detail |

#### Relations

| API field | DB column | Description |
|-----------|-----------|-------------|
| `agency.id` | `ID_SOCIETE` | Agency (TAB_SOCIETE) |
| `pole.id` | `ID_POLE` | Pole (TAB_POLE) |
| `mainManager.id` | `ID_PROFIL` | Main manager (resource) |
| `accountManager.id` | `ID_RESPSOC` | Mother company (self-referencing FK) |

#### Timestamps

| API field | DB column | Description |
|-----------|-----------|-------------|
| `creationDate` | `CSOC_DATE` | Auto-set on creation |
| `updateDate` | `CSOC_DATEUPDATE` | Last update |

---

## 2. CONTACTS (`/contacts`)

### Endpoints

```
GET    /contacts                     ← search / list
GET    /contacts/default             ← default values
POST   /contacts                     ← create
GET    /contacts/{id}                ← full profile
GET    /contacts/{id}/information    ← information tab
PUT    /contacts/{id}/information    ← update
```

#### Sub-resource tabs
```
GET /contacts/{id}/opportunities     ← linked opportunities
GET /contacts/{id}/actions           ← CRM actions
GET /contacts/{id}/tasks             ← tasks
```

### Search Parameters

| Parameter | Description |
|-----------|-------------|
| `keywords` | Search by name, email, function |
| `state` | Contact state — cf. `data.setting.state.contact` |
| `company` | Filter by company ID |
| `agency` | Agency ID |
| `pole` | Pole ID |
| `mainManager` | Main manager resource ID |
| `page` / `numberPerPage` | Pagination |

### Contact Data Model (TAB_CRMCONTACT)

#### Identity

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `lastName` | `CCON_NOM` | Varchar(100) | Last name |
| `firstName` | `CCON_PRENOM` | Varchar(100) | First name |
| `civility` | `CCON_CIVILITE` | Int | Cf. `data.setting.civility` |
| `function` | `CCON_FONCTION` | Varchar(100) | Job title / function |
| `department` | `CCON_SERVICE` | Varchar(100) | Department (free text or from company's departments list) |
| `state` | `CCON_TYPE` | Int | Contact state — cf. `data.setting.state.contact` |
| `types` | `CCON_TYPES` | Text | Multiple types, pipe-separated (e.g. `"1\|2"`) |
| `thumbnail` | `CCON_THUMBNAIL` | Varchar(100) | Photo |
| `creationSource` | `CCON_CREATIONSOURCE` | Varchar(20) | `'manual'`, `'import_csv'`, `'linkedin'`, `'api'`, `'other'` |

#### Contact Details

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `email` | `CCON_EMAIL` | Varchar(100) | Primary email |
| `email2` | `CCON_EMAIL2` | Varchar(100) | Secondary email |
| `email3` | `CCON_EMAIL3` | Varchar(100) | Tertiary email |
| `phone` | `CCON_TEL1` | Char(20) | Phone 1 |
| `phone2` | `CCON_TEL2` | Char(20) | Phone 2 |
| `fax` | `CCON_FAX` | Char(20) | Fax |
| `address` | `CCON_ADR` | Varchar(250) | Address |
| `postcode` | `CCON_CP` | Char(10) | Postcode |
| `town` | `CCON_VILLE` | Varchar(100) | City |
| `country` | `CCON_PAYS` | Varchar(100) | Country (default: 'France') |
| `subdivision` | `CCON_SUBDIVISION` | Varchar(6) | ISO-3166-2 |

#### Business Profile

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `activityAreas` | `CCON_APPLICATIONS` | Text | Activity areas, pipe-separated — cf. `data.setting.activityArea` |
| `tools` | `CCON_OUTILS` | Text | Tools list, pipe-separated — cf. `data.setting.tool` |
| `informationComments` | `CCON_COMMENTAIRE` | Varchar(250) | Free-text comments |
| `originType` | `CCON_TYPESOURCE` | Int | Origin type — cf. `data.setting.origin` |
| `originDetail` | `CCON_SOURCE` | Varchar(100) | Origin detail |

#### GDPR

| API field | DB column | Description |
|-----------|-----------|-------------|
| `gdprState` | `CCON_ETATGDPR` | `0` = no consent, `1` = consent obtained |
| `gdprExpirationDate` | `CCON_DATEGDPR` | GDPR expiry date |

#### Relations

| API field | DB column | Description |
|-----------|-----------|-------------|
| `company.id` | `ID_CRMSOCIETE` | Parent company (TAB_CRMSOCIETE) |
| `agency.id` | `ID_SOCIETE` | Agency |
| `pole.id` | `ID_POLE` | Pole |
| `mainManager.id` | `ID_PROFIL` | Main manager (resource) |

---

## 3. OPPORTUNITIES (`/opportunities`)

### Endpoints

```
GET    /opportunities                     ← search / list
GET    /opportunities/default             ← default values
POST   /opportunities                     ← create
GET    /opportunities/{id}                ← full profile
GET    /opportunities/{id}/information    ← information tab
PUT    /opportunities/{id}/information    ← update information
GET    /opportunities/{id}/simulation     ← financial simulation
PUT    /opportunities/{id}/simulation     ← update simulation
```

#### Sub-resource tabs
```
GET /opportunities/{id}/positionings      ← candidate/resource positionings
GET /opportunities/{id}/projects         ← projects created from this opportunity
GET /opportunities/{id}/actions          ← CRM actions
GET /opportunities/{id}/tasks            ← tasks
```

### Search Parameters

| Parameter | Description |
|-----------|-------------|
| `keywords` | Search by title, reference |
| `state` | Opportunity state — cf. `data.setting.state.opportunity` |
| `typeOf` | Opportunity type — cf. `data.setting.typeOf.project` |
| `startDate` / `endDate` | Date range |
| `company` | Filter by company ID |
| `agency` | Agency ID |
| `pole` | Pole ID |
| `mainManager` | Main manager ID |
| `page` / `numberPerPage` | Pagination |

### Opportunity Data Model (TAB_AO)

#### Identity & Status

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `title` | `AO_TITLE` | Varchar(150) | Opportunity title |
| `reference` | `AO_REF` | Varchar(250) | Reference |
| `state` | `AO_ETAT` | Int | State — cf. `data.setting.state.opportunity` |
| `typeOf` | `AO_TYPEREF` | Int | Type — cf. `data.setting.typeOf.project` |
| `mode` | `AO_TYPE` | Int | Mode — cf. `data.setting.typeOf.project` (same key as projects) |
| `stateReason` | `AO_STATE_REASON` | Int | End-of-process reason |
| `stateReasonComment` | `AO_STATE_REASON_COMMENT` | Text | End-of-process comment |
| `isVisible` | `AO_VISIBILITE` | Tinyint | `1` = visible |
| `creationSource` | `AO_CREATIONSOURCE` | Varchar(20) | `'manual'`, `'import_csv'`, `'linkedin'`, `'api'`, `'other'` |

#### Dates

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `startDate` | `AO_DEBUT` | Date | Mission start date |
| `endDate` | `AO_FIN` | Date | Mission end date |
| `startType` | `AO_TYPEDEBUT` | Tinyint | `1` = immediate, `2` = after `startDate` |
| `dueDate` | `AO_DATELIMITE` | Date / null | Response due date |
| `closingDate` | `AO_DATECLOSING` | Date / null | Closing date |
| `creationDate` | `AO_DEPOT` | Datetime | Auto-set |
| `updateDate` | `AO_DATEUPDATE` | Datetime | Last update |
| `lastActivityDate` | `AO_DATELASTACTIVITY` | Datetime | Last CRM activity |

#### Commercial & Financial

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `weighting` | `AO_PROBA` | Tinyint(2) | Win probability (%) |
| `isWeightingForced` | `AO_FORCEPROBA` | Tinyint | `1` = manual, `0` = auto-calculated |
| `workUnitRate` | `AO_TAUXHORAIRE` | Decimal(15,5) | Work unit rate |
| `estimatedTurnover` | `AO_CA` | Decimal(30,10) | Estimated turnover |
| `budget` | `AO_BUDGET` | Decimal(30,10) | Budget estimate |
| `additionalTurnover` | `AO_TARIFADDITIONNEL` | Decimal(30,10) | Additional turnover |
| `additionalInvestment` | `AO_INVESTISSEMENT` | Decimal(30,10) | Additional investment |
| `syncSimulation` | `AO_CORRELATIONPOS` | Tinyint | `1` = lock `estimatedTurnover`, auto-calculated from simulation |
| `currency` | `AO_DEVISE` | Int | Cf. `data.setting.currency` |
| `exchangeRate` | `AO_CHANGE` | Decimal(30,10) | Exchange rate |

#### Qualification

| API field | DB column | Type | Description |
|-----------|-----------|------|-------------|
| `description` | `AO_DESCRIPTION` | Text | Opportunity description |
| `criterias` | `AO_CRITERES` | Text | Selection criteria |
| `activityAreas` | `AO_APPLICATIONS` | Text | Activity areas, pipe-separated — cf. `data.setting.activityArea` |
| `expertiseArea` | `AO_INTERVENTION` | Text | Expertise area — cf. `data.setting.activityArea` |
| `tools` | `AO_OUTILS` | Text | Tools, format: `"tool1\|level#tool2\|level"` (level 1–5) |
| `mobilityArea` | `AO_LIEU` | Text | Location/mobility — cf. `data.setting.mobilityArea` |
| `duration` | `AO_DUREE` | Int | Duration — cf. `data.setting.duration` |
| `originType` | `AO_TYPESOURCE` | Int | Origin type — cf. `data.setting.origin` |
| `originDetail` | `AO_SOURCE` | Varchar(100) | Origin detail |
| `shield` | `AO_SHIELD` | Tinyint | Completion: `0`=incomplete, `1`=minimum, `2`=complete |

#### Relations

| API field | DB column | Description |
|-----------|-----------|-------------|
| `company.id` | `ID_CRMSOCIETE` | Client company (TAB_CRMSOCIETE) |
| `contact.id` | `ID_CRMCONTACT` | Client contact (TAB_CRMCONTACT) |
| `agency.id` | `ID_SOCIETE` | Agency |
| `pole.id` | `ID_POLE` | Pole |
| `mainManager.id` | `ID_PROFIL` | Main manager (resource) |
| `hrManager.id` | `ID_PROFILRH` | HR manager (resource) |

---

## Enumeration References

Resolve all integer codes via `GET /application/dictionary`:

| Dictionary key | Used for |
|---|---|
| `data.setting.state.company` | Company states (client, prospect, provider, partner…) |
| `data.setting.state.contact` | Contact states |
| `data.setting.state.opportunity` | Opportunity states (open, won, lost…) |
| `data.setting.typeOf.project` | Opportunity/project types and modes |
| `data.setting.civility` | Civility (M., Mme…) |
| `data.setting.origin` | Origin types (inbound, referral, event…) |
| `data.setting.expertiseArea` | Expertise areas for companies |
| `data.setting.activityArea` | Activity areas for contacts & opportunities |
| `data.setting.tool` | Technology/tool list |
| `data.setting.mobilityArea` | Geographic mobility areas |
| `data.setting.duration` | Duration values |
| `data.setting.currency` | Currencies |

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

### Create a new client company with its first contact
```
1. GET /companies/default
2. POST /companies { name, state (=client), agency.id, mainManager.id }
3. GET /contacts/default
4. POST /contacts { lastName, firstName, function, email, company.id }
```

### Create an opportunity linked to a company & contact
```
1. GET /opportunities/default
2. POST /opportunities {
     title, startDate, endDate,
     company.id, contact.id,
     mainManager.id, weighting: 50, isWeightingForced: 1
   }
```

### Convert an opportunity to a project
```
→ Not a direct API call: done from the UI or via POST /projects with opportunity.id
POST /projects {
  data: {
    type: "projects",
    attributes: { startDate, endDate, mode: 0, reference },
    relationships: {
      opportunity: { data: { type: "opportunities", id: "{aoId}" } },
      company:     { data: { type: "companies",     id: "{companyId}" } },
      mainManager: { data: { type: "resources",     id: "{resourceId}" } }
    }
  }
}
```

### Search open opportunities for a company
```
GET /opportunities?company={companyId}&state=1
```

### Search prospects (companies not yet clients)
```
GET /companies?state=0    ← state value for "prospect" from dictionary
```

### Get all contacts for a company
```
GET /contacts?company={companyId}
```

### Update opportunity weighting & state
```
PUT /opportunities/{id}/information
Body: { data: { type: "opportunities", id: "{id}", attributes: { weighting: 80, state: 2 } } }
```

---

## Notes

- A **contact** (`CCON_SERVICE`) can reference a department either as free text or from the parent company's `departments` list (`CSOC_SERVICES`).
- A company can have a **mother company** (`accountManager.id` → `ID_RESPSOC`), enabling hierarchical group structures.
- The `tools` field on opportunities uses a composite format: `"toolId|level#toolId|level"` (level 1–5), different from the contacts format (just `"toolId|toolId"`).
- `syncSimulation` (`AO_CORRELATIONPOS = 1`) locks `estimatedTurnover` and makes it auto-calculated from the simulation tab — don't set `estimatedTurnover` manually when this is enabled.
- The `shield` field reflects conditional field completion: `0` = missing required fields, `1` = required OK but recommended missing, `2` = fully complete.
- Dates follow ISO 8601: `YYYY-MM-DD`. All timestamps are UTC.
