---
name: boondmanager-actions
description: >
  Expert guide for interacting with the BoondManager API on the Actions CRM domain.
  Use this skill whenever the user wants to search, read, create, update, or delete
  CRM actions (interactions tracées) in BoondManager — calls, emails, meetings, follow-ups,
  notes attached to any entity: companies, contacts, opportunities, resources, candidates,
  projects, orders, or invoices. Also covers action templates (/actions/templates).
  Triggers on French equivalents: "action CRM", "interaction", "suivi", "relance",
  "appel téléphonique tracé", "compte-rendu de réunion", "historique des échanges",
  "activité CRM", "note d'activité", or any mention of BoondManager + traçabilité
  des interactions commerciales ou RH.
---

# BoondManager — Actions CRM

## Vue d'ensemble

Une **action** (`TAB_ACTION`) est une **interaction tracée** attachée à une entité BoondManager. Elle répond à la question : *"Qui a fait quoi, quand, sur quelle fiche ?"*

```
Entité parente (société, contact, opportunité, ressource…)
    └── Action 1 : "Appel du 12/03 — intéressé pour une mission React"
    └── Action 2 : "Email de relance envoyé le 20/03"
    └── Action 3 : "Réunion de qualification planifiée le 28/03"
```

Les actions sont **polymorphes** : elles se rattachent à onze types d'entités différents via le même endpoint `/actions`. L'entité cible est déterminée par la valeur de `typeOf` (`ACTION_TYPE`), qui encode à la fois le **type d'interaction** et l'**entité parente**.

---

## Endpoints

```
GET    /actions                          ← liste / recherche transverse
POST   /actions                          ← créer une action
GET    /actions/{id}                     ← détail
PUT    /actions/{id}                     ← mettre à jour
DELETE /actions/{id}                     ← supprimer
```

Accès contextuel (retourné dans `included` ou via sous-endpoint) :
```
GET /companies/{id}/actions              ← actions d'une société
GET /contacts/{id}/actions               ← actions d'un contact
GET /opportunities/{id}/actions          ← actions d'une opportunité
GET /resources/{id}/actions              ← actions d'une ressource
GET /candidates/{id}/actions             ← actions d'un candidat
GET /projects/{id}/actions               ← actions d'un projet
GET /orders/{id}/actions                 ← actions d'un BDC
GET /invoices/{id}/actions               ← actions d'une facture (rare)
```

Templates :
```
GET    /actions/templates                ← liste des modèles
POST   /actions/templates                ← créer un modèle
GET    /actions/templates/{id}           ← détail
PUT    /actions/templates/{id}           ← mettre à jour
DELETE /actions/templates/{id}           ← supprimer
```

---

## Paramètres de recherche (`GET /actions`)

| Paramètre | Description |
|-----------|-------------|
| `keywords` | Recherche dans le texte |
| `typeOf` | Type d'action — cf. `data.setting.action` du dictionnaire |
| `startDate` / `endDate` | Plage de dates sur `date` de l'action |
| `agency` | ID agence |
| `pole` | ID pôle |
| `mainManager` | ID du responsable de l'action |
| `company` | Filtrer par société parente |
| `opportunity` | Filtrer par opportunité parente |
| `resource` | Filtrer par ressource parente |
| `candidate` | Filtrer par candidat parent |
| `project` | Filtrer par projet parent |
| `page` / `numberPerPage` | Pagination |

---

## Modèle de données — Action (TAB_ACTION)

### Champs principaux

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `typeOf` | `ACTION_TYPE` | Int | **Type d'action** — encode le type d'interaction ET l'entité cible (voir tableau ci-dessous) |
| `date` | `ACTION_DATE` | Datetime | Date et heure de l'action |
| `text` | `ACTION_TEXTE` | Text | Contenu libre : compte-rendu, notes, objet du mail… |
| `creationDate` | `ACTION_CREATEDAT` | Datetime | Auto-set |
| `updateDate` | `ACTION_UPDATEDAT` | Datetime | Dernière mise à jour |

### Relations

| Champ API | Colonne DB | Description |
|-----------|-----------|-------------|
| `author.id` | `ID_RESPUSER` | Auteur de l'action (TAB_USER) |
| `creator.id` | `ID_CREATOR` | Créateur (peut différer de l'auteur) |
| `parentAction.id` | `ID_PARENTACTION` | Action parente (pour sous-actions / fils de discussion) |
| **entité parente** | `ID_PARENT` | ID de l'entité cible — dépend de `typeOf` (voir ci-dessous) |
| **entité secondaire** | `ID_OTHER` | ID d'une entité secondaire selon certains types (société associée) |

---

## Le champ `typeOf` — Concept central

`ACTION_TYPE` est un **entier qui code deux informations en une** : le type d'interaction (appel, email, réunion…) et l'entité à laquelle l'action est rattachée.

### Plages de valeurs par entité parente

| Plage `typeOf` | Entité parente (`ID_PARENT`) | Entité secondaire (`ID_OTHER`) |
|---|---|---|
| `0–1, 12–13, 40–45` | **Candidat** (`TAB_PROFIL.ID_PROFIL`) | — |
| `2–3, 10–11, 60–65` | **Contact CRM** (`TAB_CRMCONTACT.ID_CRMCONTACT`) | **Société CRM** (`TAB_CRMSOCIETE.ID_CRMSOCIETE`) |
| `4–5, 8–9, 80–85` | **Ressource** (`TAB_PROFIL.ID_PROFIL`) | — |
| `20–29` | **Bon de commande** (`TAB_BONDECOMMANDE.ID_BONDECOMMANDE`) | — |
| `30–39, 90` | **Projet** (`TAB_PROJET.ID_PROJET`) | — |
| `50–59` | **Opportunité** (`TAB_AO.ID_AO`) | — |
| `70–79` | **Facture** (`TAB_FACTURATION.ID_FACTURATION`) | — |
| `101` | **Société CRM** (`TAB_CRMSOCIETE.ID_CRMSOCIETE`) | **Société CRM** (`TAB_CRMSOCIETE.ID_CRMSOCIETE`) |

> ⚠️ **Point critique** : il n'y a pas de champ séparé `entityType` + `entityId`. C'est la valeur de `typeOf` seule qui détermine quelle FK utiliser dans `ID_PARENT`. Les valeurs exactes par type d'interaction (appel, email, réunion…) sont configurées dans `data.setting.action` du dictionnaire — elles varient selon l'instance.

### Récupérer les types disponibles

```
GET /application/dictionary
→ data.setting.action  ← liste des types d'actions avec leurs id, label et entité associée
```

Chaque entrée du dictionnaire indique à quelle entité le type est destiné, permettant de filtrer les types pertinents selon le contexte.

---

## Création d'une action

### Sur un contact (avec sa société associée)
```http
POST /actions
{
  "data": {
    "type": "actions",
    "attributes": {
      "typeOf": 10,                     ← type "Appel sortant - Contact" (cf. dictionnaire)
      "date": "2025-03-15T14:30:00",
      "text": "Appel de qualification. Intéressé pour une mission en avril. Relancer début avril."
    },
    "relationships": {
      "contact":  { "data": { "type": "contacts",  "id": "55" } },
      "company":  { "data": { "type": "companies", "id": "12" } },
      "author":   { "data": { "type": "users",     "id": "3"  } }
    }
  }
}
```

### Sur une opportunité
```http
POST /actions
{
  "data": {
    "type": "actions",
    "attributes": {
      "typeOf": 52,                     ← type "Réunion - Opportunité" (cf. dictionnaire)
      "date": "2025-03-20T09:00:00",
      "text": "Réunion de soutenance. Décision attendue sous 2 semaines."
    },
    "relationships": {
      "opportunity": { "data": { "type": "opportunities", "id": "84" } },
      "author":      { "data": { "type": "users",         "id": "3"  } }
    }
  }
}
```

### Sur une ressource (suivi RH)
```http
POST /actions
{
  "data": {
    "type": "actions",
    "attributes": {
      "typeOf": 81,                     ← type "Entretien - Ressource" (cf. dictionnaire)
      "date": "2025-03-18T11:00:00",
      "text": "Entretien annuel. Souhait d'évolution vers un rôle de lead technique."
    },
    "relationships": {
      "resource": { "data": { "type": "resources", "id": "42" } },
      "author":   { "data": { "type": "users",     "id": "3"  } }
    }
  }
}
```

### Sous-action (rattachée à une action parente)
```http
POST /actions
{
  "data": {
    "type": "actions",
    "attributes": {
      "typeOf": 10,
      "date": "2025-03-22T16:00:00",
      "text": "Relance téléphonique suite à l'appel du 15/03."
    },
    "relationships": {
      "contact":      { "data": { "type": "contacts", "id": "55" } },
      "parentAction": { "data": { "type": "actions",  "id": "201" } }
    }
  }
}
```

---

## Action Templates (TAB_ACTIONTPL)

Les modèles permettent de préparer des contenus d'actions réutilisables (scripts d'appel, trames de compte-rendu, emails types…).

### Champs d'un modèle

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `title` | `ACTIONTPL_TITLE` | Varchar(100) | Titre du modèle |
| `content` | `ACTIONTPL_CONTENT` | Longtext | Contenu du modèle (texte libre, peut contenir des variables) |
| `typeOf` | `ACTIONTPL_TYPE` | Int | Type d'action associé — même référentiel que `ACTION_TYPE` |
| `isActive` | `ACTIONTPL_ACTIVE` | Tinyint | `1`=actif · `0`=inactif |
| `creationDate` | `ACTIONTPL_CREATED` | Datetime | Auto-set |
| `updateDate` | `ACTIONTPL_LASTUPDATE` | Datetime | Dernière mise à jour |
| `creator.id` | `ID_CREATOR` | Int | Créateur (TAB_PROFIL) |

---

## Patterns de workflow courants

### Historiser un appel commercial entrant
```
1. Identifier le contact via GET /contacts?keywords=nom+prenom
2. POST /actions { typeOf: [valeur appel entrant contact], date, text, contact.id, company.id }
```

### Lister toutes les relances planifiées pour la semaine
```
GET /actions?typeOf={typeRelance}&startDate=2025-03-24&endDate=2025-03-28&mainManager={userId}
```

### Récupérer l'historique complet d'une société cliente
```
GET /companies/{id}/actions
```

### Ajouter un compte-rendu de réunion sur un projet
```
POST /actions { typeOf: [valeur réunion projet], date, text, project.id }
```

### Tracer un entretien candidat
```
POST /actions { typeOf: [valeur entretien candidat], date, text, candidate.id }
```

---

## Enumeration References

| Source | Utilisation |
|--------|-------------|
| `data.setting.action` | **Source unique** des types d'actions disponibles, avec leur entité cible et leur libellé — via `GET /application/dictionary` |

---

## Gestion des erreurs

| Code HTTP | Signification |
|-----------|---------------|
| `200` | Succès |
| `422` | Validation — `typeOf` incompatible avec l'entité fournie, ou champ requis manquant |
| `401` | Authentification échouée |
| `403` | Droits insuffisants |
| `404` | Action introuvable |

---

## Notes importantes

- **`typeOf` encode à la fois le type d'interaction ET l'entité cible** — il n'y a pas de champ séparé. La valeur détermine quelle FK utiliser dans `ID_PARENT`. Toujours consulter `data.setting.action` du dictionnaire pour connaître les valeurs disponibles sur l'instance.
- Une action sur un **contact** porte aussi systématiquement la société (`ID_OTHER`) — les deux IDs sont attendus à la création.
- `ID_PARENTACTION` permet de créer une **hiérarchie d'actions** (sous-actions, fils de discussion, relances liées à un premier contact).
- Les actions n'ont pas de champ "statut" (planifiée/réalisée) dans le modèle de base — cet aspect est géré via `typeOf` (certains types sont par convention des actions planifiées vs réalisées).
- Les modèles d'actions (`/actions/templates`) sont partagés à l'échelle de l'instance et permettent de standardiser les trames de compte-rendu.
- `author` (`ID_RESPUSER`) désigne la personne qui a **réalisé** l'interaction, `creator` (`ID_CREATOR`) la personne qui l'a **saisie** dans le système — ils peuvent différer (ex : un assistant saisit pour le compte d'un commercial).
