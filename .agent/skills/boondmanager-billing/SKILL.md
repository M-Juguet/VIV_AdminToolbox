---
name: boondmanager-billing
description: >
  Expert guide for interacting with the BoondManager API on the Billing & Finance domain.
  Use this skill whenever the user wants to search, read, create, or update invoices,
  orders (bons de commande), or payments in BoondManager — including credit notes (avoirs),
  invoice items, billing schedules, PDF generation options, and e-invoicing. Also triggers
  for sub-resources: invoice line items, order-linked invoices, payment recording, and
  billing balance endpoints. Triggers on French equivalents: "facture", "bon de commande",
  "BDC", "avoir", "paiement", "encaissement", "facturation", "échéancier", "TVA",
  "règlement", or any mention of BoondManager + facturation/comptabilité/finance.
---

# BoondManager — Facturation & Finance

## API Overview

- **Base URL**: `https://ui.boondmanager.com/api/1.0`
- **Auth**: Basic Auth ou JWT Bearer token
- **Format**: JSON:API — réponses avec `data`, `included`, `meta`

## Cycle de facturation — Architecture

```
TAB_BONDECOMMANDE (order)          ← Bon de commande client (cadre contractuel)
    └── TAB_FACTURATION (invoice)  ← Facture émise sur ce BDC
            ├── TAB_ITEMFACTURE    ← Lignes de la facture (temps, frais, achats…)
            └── TAB_FACTURATION_PAIEMENT ← Encaissements liés à la facture

TAB_PAIEMENT                       ← Paiement fournisseur (lié à TAB_ACHAT)
```

> **Sens du flux** : Projet → Bon de commande → Facture(s) → Paiement(s)  
> Un BDC peut porter plusieurs factures. Une facture peut être un **avoir** (`isCreditNote = 1`), auquel cas `parentInvoice.id` pointe vers la facture d'origine.

---

## 1. ORDERS — Bons de commande (`/orders`)

### Endpoints

```
GET    /orders                        ← liste / recherche
GET    /orders/default                ← valeurs par défaut
POST   /orders                        ← créer un BDC
GET    /orders/{id}                   ← profil complet
GET    /orders/{id}/information       ← onglet informations
PUT    /orders/{id}/information       ← mettre à jour
GET    /orders/{id}/invoices          ← factures liées
GET    /orders/{id}/actions           ← actions CRM
GET    /orders/{id}/tasks             ← tâches
```

### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `keywords` | Recherche par référence, numéro client |
| `state` | État — cf. `data.setting.state.order` |
| `company` | ID société CRM |
| `project` | ID projet lié |
| `agency` | ID agence |
| `startDate` / `endDate` | Plage de dates |
| `page` / `numberPerPage` | Pagination |

### Modèle de données — Order (TAB_BONDECOMMANDE)

#### Informations générales

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `reference` | `BDC_REF` | Varchar(250) | Référence interne du BDC |
| `customerReference` | `BDC_REFCLIENT` | Varchar(250) | Numéro client (référence acheteur) |
| `state` | `BDC_ETAT` | Int | État — cf. `data.setting.state.order` |
| `date` | `BDC_DATE` | Date | Date du BDC |
| `startDate` | `BDC_DEBUT` | Date | Date de début |
| `endDate` | `BDC_FIN` | Date | Date de fin |
| `isStartEndDateForced` | `BDC_FORCE_DATE` | Tinyint | `1` = dates forcées (non liées au projet) |
| `amountExcludingTax` | `BDC_MONTANTHT` | Decimal(30,10) | Montant HT à facturer |
| `amountIncludingTax` | `BDC_MONTANTTTC` | Decimal(30,10) | Montant TTC à facturer |
| `taxRate` | `BDC_TAUXTVA` | Decimal(15,5) | Taux de TVA par défaut |
| `taxRates` | `BDC_LISTETAUXTVA` | Tinytext | Liste de taux TVA séparés par `\|` (ex: `"20\|10\|5.5"`) |
| `paymentMethod` | `BDC_TYPEPAYMENT` | Int | Mode de paiement par défaut — cf. `data.setting.paymentMethod` |
| `paymentTerm` | `BDC_CONDREGLEMENT` | Int | Conditions de règlement — cf. `data.setting.paymentTerm` |
| `billingType` | `BDC_TYPEREGLEMENT` | Tinyint | `0`=Échéancier · `1`=Mensuel |
| `language` | `BDC_LANGUE` | Char(3) | Langue PDF : `"fr"` ou `"en"` |
| `comments` | `BDC_COMMENTAIRE` | Text | Commentaires libres |
| `billingInstructions` | `BDC_BILLINGINSTRUCTIONS` | Text | Instructions de facturation |
| `legalMentions` | `BDC_MENTIONS` | Text | Mentions légales PDF |
| `isCustomerAgreementEnabled` | `BDC_ACCORDCLIENT` | Tinyint | `1` = accord client requis |

#### Options PDF des factures (héritées du BDC)

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `showOrderNumber` | `BDC_SHOWNUMBER` | Afficher le numéro BDC sur les factures PDF |
| `showResourceNames` | `BDC_SHOWINTNAME` | Afficher les noms des ressources |
| `showDailyRates` | `BDC_SHOWTARIFJRS` | Afficher les TJM |
| `showWorkingDays` | `BDC_SHOWJRSOUVRES` | Afficher le nb de jours ouvrés |
| `showVatNumber` | `BDC_SHOWTVAIC` | Afficher le n° TVA |
| `showBankDetails` | `BDC_SHOWRIB` | Afficher les coordonnées bancaires |
| `showFooter` | `BDC_SHOWFOOTER` | Afficher le pied de page |
| `showComments` | `BDC_SHOWCOMMENTS` | Afficher les commentaires |
| `showFactor` | `BDC_SHOWFACTOR` | Afficher la section "Factor" |
| `showProjectReference` | `BDC_SHOWPRJREFERENCE` | Afficher la référence projet |
| `copyCommentsToInvoices` | `BDC_COPYCOMMENTS` | Copier les commentaires BDC dans chaque facture |
| `groupDeliveries` | `BDC_GROUPMISSION` | Regrouper les lignes de livraison sur facture |
| `groupExpenses` | `BDC_GROUPEXPENSES` | Regrouper les lignes de frais |
| `separateExceptionalActivities` | `BDC_SEPARATEAE` | Factures séparées pour activités exceptionnelles |
| `separateTimesExpensesPurchases` | `BDC_SEPARATETPSFRS` | Factures séparées temps/frais/achats |
| `attachExpenses` | `BDC_ATTACH_EXPENSES` | Joindre les notes de frais à la facture |
| `attachSignedTimesheets` | `BDC_ATTACH_SIGNED_TIMESHEETS` | Joindre les CRA signés |
| `attachUnsignedTimesheets` | `BDC_ATTACH_UNSIGNED_TIMESHEETS` | Joindre les CRA non signés (si pas de signé) |
| `requestTimesheetsSignature` | `BDC_REQUEST_TIMESHEETS_SIGNATURE` | Demander la signature des CRA |
| `mergeInvoiceAttachments` | `BDC_MERGE_INVOICE_ATTACHMENTS` | Fusionner les pièces jointes dans le PDF |

#### Types d'éléments facturables (`BDC_BILLABLE_ITEM_TYPES`)

Liste pipe-séparée des types inclus dans les factures de ce BDC :

| Valeur | Description |
|--------|-------------|
| `1` | Temps réguliers |
| `2` | Temps exceptionnels |
| `3` | CA additionnel |
| `4` | Achats |
| `5` | Frais |

#### Relations

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `company.id` | `ID_CRMSOCIETE` | Société cliente (facteur) |
| `billingDetails.id` | `ID_COORDONNEES` | Coordonnées de facturation |
| `headOffice.id` | `ID_HEADOFFICE` | Siège social |
| `project.id` | `ID_PROJET` | Projet lié |
| `bankDetails.id` | `ID_RIB` | Coordonnées bancaires (RIB) |
| `mainManager.id` | `ID_RESPUSER` | Responsable (TAB_USER) |

---

## 2. INVOICES — Factures (`/invoices`)

### Endpoints

```
GET    /invoices                      ← liste / recherche
GET    /invoices/default              ← valeurs par défaut
POST   /invoices                      ← créer une facture
GET    /invoices/{id}                 ← profil complet
GET    /invoices/{id}/information     ← onglet informations
PUT    /invoices/{id}/information     ← mettre à jour
DELETE /invoices/{id}                 ← supprimer (si non clôturée)
```

### Paramètres de recherche

| Paramètre | Description |
|-----------|-------------|
| `keywords` | Référence, numéro |
| `state` | État — cf. `data.setting.state.invoice` |
| `order` | ID du bon de commande |
| `company` | ID société CRM |
| `agency` | ID agence |
| `startDate` / `endDate` | Plage sur la date de facture |
| `isClosed` | `1` = factures clôturées |
| `isCreditNote` | `1` = avoirs uniquement |
| `page` / `numberPerPage` | Pagination |

### Modèle de données — Invoice (TAB_FACTURATION)

#### Identité & Statut

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `reference` | `FACT_REF` | Varchar(250) | Référence / numéro de facture |
| `state` | `FACT_ETAT` | Int | État — cf. `data.setting.state.invoice` |
| `isCreditNote` | `FACT_AVOIR` | Tinyint | `1` = avoir (note de crédit) |
| `isClosed` | `FACT_CLOTURE` | Tinyint | `1` = clôturée (immuable) |
| `sendingState` | `FACT_ETAT_ENVOI` | Tinyint | État d'envoi de la facture |
| `nature` | `FACT_NATURE` | Tinyint | `0` = Service · `1` = Biens |
| `typeOf` | `FACT_TYPE_OF` | Tinyint | Type d'éléments inclus à la création — voir tableau ci-dessous |
| `discountRate` | `FACT_TAUXREMISE` | Decimal(15,5) | Taux de remise (%) |

#### `typeOf` — Contenu de la facture à la création

| Valeur | Contenu |
|--------|---------|
| `-1` | Non défini (facture manuelle) |
| `0` | Tout (temps + frais + achats) |
| `1` | Temps uniquement |
| `2` | Frais uniquement |
| `3` | Achats uniquement |
| `4` | Frais + Achats |
| `5` | Activité normale + Frais + Achats |
| `6` | Activité normale uniquement |
| `7` | Activité exceptionnelle uniquement |

#### Dates

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `date` | `FACT_DATE` | Date | Date de la facture |
| `startDate` | `FACT_DEBUT` | Date | Période de début |
| `endDate` | `FACT_FIN` | Date | Période de fin |
| `expectedPaymentDate` | `FACT_DATEREGLEMENTATTENDUE` | Date | Date de règlement attendue |
| `isExpectedPaymentDateForced` | `FACT_FORCEDATEREGLEMENTATTENDUE` | Tinyint | `1` = date forcée manuellement |
| `performedPaymentDate` | `FACT_DATEREGLEMENTRECUE` | Date / null | Date de règlement effectif |

#### Montants & Paiement

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `totalExcludingTax` | `FACT_TOTALHT` | Decimal(30,10) | Total HT (valeur de sauvegarde) |
| `totalIncludingTax` | `FACT_TOTALTTC` | Decimal(30,10) | Total TTC (valeur de sauvegarde) |
| `amountPayable` | `FACT_AMOUNT_PAYABLE` | Decimal(30,10) | Montant restant à payer TTC |
| `paymentMethod` | `FACT_TYPEPAYMENT` | Int | Mode de paiement — cf. `data.setting.paymentMethod` |
| `paymentTerm` | `FACT_CONDREGLEMENT` | Tinyint | Conditions de règlement (valeur de sauvegarde) |
| `currency` | `FACT_DEVISE` | Int | Devise — cf. `data.setting.currency` |
| `exchangeRate` | `FACT_CHANGE` | Decimal(30,10) | Taux de change |

#### PDF & Affichage

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `comments` | `FACT_COMMENTAIRE` | Commentaires |
| `showComments` | `FACT_SHOWCOMMENTAIRE` | `1` = afficher commentaires sur PDF |
| `legalMentions` | `FACT_MENTIONS` | Mentions légales (valeur de sauvegarde) |
| `ibanBackup` | `FACT_RIB_IBAN` | IBAN de sauvegarde |
| `bicBackup` | `FACT_RIB_BIC` | BIC de sauvegarde |

#### E-invoicing (facturation électronique)

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `taxReportState` | `FACT_ETAT_TAX_REPORT` | État du dépôt fiscal |
| `taxReportUrl` | `FACT_TAX_REPORT_URL` | URL externe du rapport fiscal |
| `taxReportErrors` | `FACT_TAX_REPORT_ERRORS` | Erreurs de dépôt (JSON) |
| `refuseReason` | `FACT_REFUSE_REASON` | Motif de refus (e-invoicing) |
| `providerId` | `FACT_PROVIDER_ID` | ID dans la base du prestataire e-invoicing |
| `invoicingConnection.id` | `ID_INVOICING_CONNECTION` | Connexion de facturation électronique utilisée |

#### Relations

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `order.id` | `ID_BONDECOMMANDE` | Bon de commande parent |
| `parentInvoice.id` | `ID_PARENT_FACTURATION` | Facture d'origine (pour les avoirs) |
| `schedule.id` | `ID_ECHEANCIER` | Échéancier lié |
| `pdfDocument.id` | `ID_DOCUMENT_PDF` | Dernière version PDF générée |
| `facturxDocument.id` | `ID_DOCUMENT_FACTURX` | Fichier Factur-X |
| `ciiDocument.id` | `ID_DOCUMENT_CII` | Fichier CII (Cross Industry Invoice) |

---

## 3. PAYMENTS — Paiements (`/payments`)

Les paiements couvrent deux cas distincts :
- **Encaissements clients** (`/invoices/{id}` → `payments`) : liés à une facture via `TAB_FACTURATION_PAIEMENT`
- **Règlements fournisseurs** (`/payments`) : liés à un achat (`TAB_ACHAT`) via `TAB_PAIEMENT`

### Endpoints

```
GET    /payments                      ← liste tous les paiements fournisseurs
GET    /payments/default              ← valeurs par défaut
POST   /payments                      ← créer un paiement fournisseur
GET    /payments/{id}                 ← profil
GET    /payments/{id}/information     ← onglet informations
PUT    /payments/{id}/information     ← mettre à jour
```

### Modèle de données — Payment (TAB_PAIEMENT)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `state` | `PMT_ETAT` | Int | État — cf. `data.setting.state.payment` |
| `date` | `PMT_DATE` | Date | Date du paiement |
| `startDate` | `PMT_DEBUT` | Date | Période de début |
| `endDate` | `PMT_FIN` | Date | Période de fin |
| `expectedPaymentDate` | `PMT_DATEPAIEMENTATTENDU` | Date | Date de règlement attendue |
| `performedPaymentDate` | `PMT_DATEPAIEMENTEFFECTUE` | Date / null | Date de règlement effectif |
| `amountExcludingTax` | `PMT_MONTANTHT` | Decimal(30,10) | Montant HT |
| `amountIncludingTax` | `PMT_MONTANTTTC` | Decimal(30,10) | Montant TTC |
| `taxRate` | `PMT_TAUXTVA` | Decimal(15,5) | Taux de TVA |
| `taxRates` | `PMT_LISTETAUXTVA` | Tinytext | Liste de taux TVA pipe-séparés |
| `paymentMethod` | `PMT_TYPEPAYMENT` | Int | Mode de paiement — cf. `data.setting.paymentMethod` |
| `providerReference` | `PMT_REFPROVIDER` | Varchar(250) | Référence fournisseur |
| `comments` | `PMT_COMMENTAIRES` | Varchar(150) | Commentaires |
| `purchase.id` | `ID_ACHAT` | Int | Achat lié (TAB_ACHAT) |

---

## Enumeration References

| Clé dictionnaire | Utilisation |
|-----------------|-------------|
| `data.setting.state.order` | États du BDC |
| `data.setting.state.invoice` | États de la facture |
| `data.setting.state.payment` | États du paiement |
| `data.setting.paymentMethod` | Modes de paiement (virement, chèque, prélèvement…) |
| `data.setting.paymentTerm` | Conditions de règlement (30j, 45j, fin de mois…) |
| `data.setting.taxRate` | Taux de TVA disponibles |
| `data.setting.currency` | Devises |

---

## Gestion des erreurs

| Code HTTP | Signification |
|-----------|---------------|
| `200` | Succès |
| `422` | Erreur de validation — vérifier `errors[].title` + `errors[].detail` |
| `401` | Authentification échouée |
| `403` | Droits insuffisants |
| `404` | Introuvable |

---

## Workflow Patterns

### Créer un bon de commande sur un projet
```
1. GET /orders/default
2. POST /orders {
     reference, date, startDate, endDate,
     taxRate: 20, language: "fr",
     billingType: 1,                          ← mensuel
     billableItemTypes: "1|2|3",              ← temps + exceptionnel + CA additionnel
     company.id, project.id, mainManager.id
   }
```

### Créer une facture depuis un BDC (tous les temps du mois)
```
1. GET /invoices/default
2. POST /invoices {
     date: "2025-03-31",
     startDate: "2025-03-01", endDate: "2025-03-31",
     typeOf: 1,                                ← temps uniquement
     order.id: "{bdcId}"
   }
```

### Créer un avoir (note de crédit)
```
POST /invoices {
  date: "2025-03-31",
  isCreditNote: 1,
  parentInvoice.id: "{invoiceId}",
  order.id: "{bdcId}"
}
```

### Enregistrer un encaissement sur une facture
```
PUT /invoices/{id}/information {
  data: {
    type: "invoices", id: "{id}",
    attributes: {
      performedPaymentDate: "2025-04-15",
      state: 3                              ← état "payée" cf. dictionnaire
    }
  }
}
```

### Lister les factures impayées d'une société
```
GET /invoices?company={companyId}&state=2   ← state "envoyée" ou "en attente"
```

### Lister les factures en retard de paiement
```
GET /invoices?state=2&endDate=2025-03-27   ← expectedPaymentDate < aujourd'hui
```

---

## Notes importantes

- Une facture **clôturée** (`isClosed = 1`) est **immuable** — elle ne peut plus être modifiée ni supprimée, même par un administrateur.
- Les champs `FACT_*_backup` (agence, société, coordonnées bancaires…) sont des **instantanés au moment de la création** de la facture. Ils ne sont pas mis à jour si les données sources changent — c'est intentionnel pour la traçabilité comptable.
- Le champ `typeOf` sur la facture détermine **quels éléments billables sont automatiquement intégrés** lors de la création. Une valeur `-1` crée une facture vide (saisie manuelle des lignes).
- `amountPayable` (`FACT_AMOUNT_PAYABLE`) est calculé automatiquement : `totalIncludingTax - encaissements reçus`.
- Les **avoirs** (`isCreditNote = 1`) doivent référencer la facture d'origine via `parentInvoice.id`. Ils n'annulent pas automatiquement la facture d'origine — la réconciliation est manuelle ou via l'UI.
- `taxRates` (liste pipe-séparée) et `taxRate` (taux unique par défaut) coexistent : le taux unique est appliqué à toutes les lignes par défaut, mais plusieurs taux peuvent être configurés au niveau du BDC.
- La facturation électronique (Factur-X, CII, e-invoicing) est gérée via `ID_INVOICING_CONNECTION` et les champs `taxReport*`. Ces fonctionnalités requièrent une connexion de facturation configurée dans l'instance.
