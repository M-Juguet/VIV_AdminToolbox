---
name: boondmanager-webhooks
description: >
  Expert guide for interacting with the BoondManager API on the Webhooks domain.
  Use this skill whenever the user wants to register, list, update, or delete webhooks
  in BoondManager, configure which events trigger a webhook, or understand the webhook
  notification system (entities, event types, payload structure). Also triggers when the
  user wants to build event-driven integrations with BoondManager, react to creates/updates/
  deletes on resources, projects, invoices, timesheets, etc. Triggers on French equivalents:
  "webhook", "hook", "notification d'événement", "intégration événementielle",
  "écouter les événements BoondManager", or any mention of BoondManager + automatisation
  déclenchée par des changements de données.
---

# BoondManager — Webhooks

## Vue d'ensemble

Les webhooks BoondManager permettent à une application externe de **recevoir des notifications en temps réel** lorsqu'une entité est créée, modifiée ou supprimée dans BoondManager.

```
BoondManager  ──[événement]──▶  POST vers votre URL  ──▶  Votre système
   (source)                        (webhook call)          (récepteur)
```

Un webhook est composé de deux éléments :
- **`TAB_WEBHOOK`** : le webhook lui-même (nom, description, URL cible)
- **`TAB_WEBHOOK_EVENT`** : les souscriptions aux événements (entité × type d'action)

Un webhook peut avoir **plusieurs événements** : on souscrit séparément à `resource.create`, `resource.update`, `invoice.create`, etc.

---

## Endpoints

```
GET    /webhooks           ← liste tous les webhooks configurés
POST   /webhooks           ← créer un nouveau webhook
GET    /webhooks/{id}      ← détail d'un webhook (avec ses événements)
PUT    /webhooks/{id}      ← mettre à jour (nom, URL, événements)
DELETE /webhooks/{id}      ← supprimer un webhook
```

---

## Modèle de données

### Webhook (TAB_WEBHOOK)

| Champ API | Colonne DB | Type | Description |
|-----------|-----------|------|-------------|
| `name` | `WEBHOOK_NAME` | Varchar(250) | Nom du webhook (libre) |
| `description` | `WEBHOOK_DESCRIPTION` | Longtext | Description (libre) |
| `url` | `WEBHOOK_URL` | Varchar(512) | **URL cible** — doit être HTTPS, accessible publiquement |
| `creationDate` | `WEBHOOK_CREATIONDATE` | Datetime | Auto-set |
| `updateDate` | `WEBHOOK_UPDATEDATE` | Datetime | Dernière mise à jour |
| `creator.id` | `ID_CREATOR` | Int | Créateur du webhook (TAB_PROFIL) |

### Événements (TAB_WEBHOOK_EVENT)

Chaque événement souscrit est défini par la combinaison de deux valeurs :

| Champ API | Colonne DB | Valeurs |
|-----------|-----------|---------|
| `entity` | `EVENT_ENTITY` | Voir liste complète ci-dessous |
| `eventType` | `EVENT_TYPE` | `create` · `update` · `delete` |

---

## Liste exhaustive des entités disponibles

Toutes les valeurs autorisées pour `EVENT_ENTITY` (`TAB_WEBHOOK_EVENT.EVENT_ENTITY`) :

### RH & Collaborateurs
| Valeur | Entité |
|--------|--------|
| `resource` | Ressource (collaborateur) |
| `candidate` | Candidat |
| `contract` | Contrat |
| `advantage` | Avantage |
| `timesreport` | Feuille de temps |
| `expensesreport` | Note de frais |
| `absencesreport` | Demande d'absence |

### CRM & Commercial
| Valeur | Entité |
|--------|--------|
| `company` | Société CRM |
| `contact` | Contact CRM |
| `opportunity` | Opportunité (appel d'offres) |
| `positioning` | Positionnement |
| `action` | Action CRM |
| `quotation` | Devis (app Quotations) |

### Projets & Production
| Valeur | Entité |
|--------|--------|
| `project` | Projet |
| `delivery` | Livraison (mission) |
| `groupment` | Groupement |
| `inactivity` | Inactivité |
| `purchase` | Achat |

### Facturation & Finance
| Valeur | Entité |
|--------|--------|
| `order` | Bon de commande |
| `invoice` | Facture |
| `payment` | Paiement |

### Référentiel & Structure
| Valeur | Entité |
|--------|--------|
| `agency` | Agence |
| `pole` | Pôle |
| `businessunit` | Business unit |
| `role` | Rôle |
| `roletemplate` | Modèle de rôle |
| `target` | Objectif |

### Paramétrage & Autres
| Valeur | Entité |
|--------|--------|
| `product` | Produit |
| `validation` | Validation |
| `task` | Tâche |
| `todolist` | Liste de tâches |
| `followeddocument` | Document suivi |
| `savedsearch` | Recherche sauvegardée |
| `thread` | Fil de discussion |
| `actiontemplate` | Modèle d'action |
| `device` | Appareil |
| `app` | Application (marketplace) |
| `appentity` | Entité d'application |
| `vendor` | Vendeur |
| `customer` | Client |
| `architecture` | Architecture |

---

## Création d'un webhook

### Corps de la requête

```http
POST /webhooks
Content-Type: application/json
Authorization: Bearer {token}

{
  "data": {
    "type": "webhooks",
    "attributes": {
      "name": "Sync RH vers SIRH",
      "description": "Notifie notre SIRH à chaque création/modification de ressource ou contrat",
      "url": "https://mon-sirh.exemple.com/api/boondmanager/events",
      "events": [
        { "entity": "resource", "eventType": "create" },
        { "entity": "resource", "eventType": "update" },
        { "entity": "contract", "eventType": "create" },
        { "entity": "contract", "eventType": "update" },
        { "entity": "contract", "eventType": "delete" }
      ]
    }
  }
}
```

### Mise à jour des événements

```http
PUT /webhooks/{id}
{
  "data": {
    "type": "webhooks",
    "id": "{id}",
    "attributes": {
      "events": [
        { "entity": "invoice", "eventType": "create" },
        { "entity": "invoice", "eventType": "update" },
        { "entity": "payment", "eventType": "create" }
      ]
    }
  }
}
```

> ⚠️ La mise à jour des événements **remplace** la liste complète — il faut renvoyer tous les événements souhaités, pas seulement les nouveaux.

---

## Payload reçu par votre endpoint

Lorsqu'un événement se produit, BoondManager envoie une requête **HTTP POST** vers l'URL configurée.

### Structure du payload

```json
{
  "data": {
    "type": "{entity}",
    "id": "{entityId}",
    "attributes": {
      "eventType": "create|update|delete"
    }
  }
}
```

> Le payload contient l'**identifiant de l'entité** concernée et le **type d'événement**. Pour obtenir les données complètes de l'entité, il faut ensuite faire un appel `GET /{entity}s/{id}` à l'API.

### Headers envoyés par BoondManager

| Header | Description |
|--------|-------------|
| `Content-Type` | `application/json` |
| `User-Agent` | Identifiant BoondManager |

> ⚠️ BoondManager n'envoie **pas de signature cryptographique** dans ses headers (contrairement à GitHub ou Stripe). La sécurisation de l'endpoint repose sur l'utilisation d'un token secret dans l'URL (`https://mon-endpoint.com/webhook?token=secret`) ou d'un middleware d'authentification côté récepteur.

---

## Bonnes pratiques

### Répondre rapidement
Votre endpoint doit répondre **`200 OK` en moins de 5 secondes**. Si le traitement est long, accusez réception immédiatement (`200`) et traitez l'événement en arrière-plan (queue, worker).

### Gestion des doublons
BoondManager peut envoyer le même événement plusieurs fois en cas d'échec de livraison. Implémentez une logique d'**idempotence** côté récepteur (vérifier si l'ID a déjà été traité).

### Récupérer les données complètes
Le payload contient l'ID de l'entité mais pas ses données. Enchaîner sur un `GET` :

```
# Exemple : webhook "resource.update" reçu avec id=42
→ GET /resources/42/information  pour récupérer les données à jour
```

### Sécuriser l'URL
Inclure un token secret dans l'URL du webhook ou restreindre l'accès par IP :
```
https://mon-app.com/webhooks/boondmanager?secret=xxxxxxxxxxx
```

### Surveiller les échecs
Si BoondManager ne reçoit pas de `2xx`, il peut réessayer. Vérifier les logs de votre endpoint en cas d'événements manquants.

---

## Patterns de workflow courants

### Synchronisation RH bidirectionnelle
```
events: [
  { entity: "resource", eventType: "create" },
  { entity: "resource", eventType: "update" },
  { entity: "contract", eventType: "create" },
  { entity: "contract", eventType: "update" }
]
→ Sur réception : GET /resources/{id}/information + GET /contracts?resource={id}
```

### Notification de validation de feuille de temps
```
events: [
  { entity: "timesreport", eventType: "update" }
]
→ Sur réception : GET /times-reports/{id}
→ Si state == 1 (validée) : déclencher le calcul de paie
```

### Déclenchement de facturation automatique
```
events: [
  { entity: "timesreport", eventType: "update" }
]
→ Sur réception : vérifier état, si validée et clôturée → créer facture via POST /invoices
```

### Alertes sur nouvelles opportunités
```
events: [
  { entity: "opportunity", eventType: "create" }
]
→ Sur réception : GET /opportunities/{id} → notifier l'équipe commerciale (Slack, email…)
```

### Sync comptable en temps réel
```
events: [
  { entity: "invoice", eventType: "create" },
  { entity: "invoice", eventType: "update" },
  { entity: "payment", eventType: "create" }
]
→ Sur réception : GET /invoices/{id} ou GET /payments/{id} → pousser vers logiciel comptable
```

---

## Gestion des erreurs API

| Code HTTP | Signification |
|-----------|---------------|
| `200` | Succès |
| `422` | Validation — URL invalide, événement inconnu |
| `401` | Authentification échouée |
| `403` | Droits insuffisants |
| `404` | Webhook introuvable |

---

## Notes importantes

- Un webhook peut écouter **autant d'événements que nécessaire** — regrouper les événements liés dans un seul webhook plutôt que de créer un webhook par événement.
- La mise à jour des événements (`PUT`) **remplace** la liste existante — toujours renvoyer la liste complète.
- L'URL doit être **HTTPS** et accessible depuis les serveurs BoondManager (hébergés en France).
- Il n'y a pas de mécanisme de rejeu intégré documenté — prévoir une surveillance de la disponibilité de l'endpoint.
- Le payload ne contient que l'ID — toujours faire un `GET` complémentaire pour récupérer l'état actuel de l'entité.
- Pour les événements `delete`, le `GET` ne retournera pas l'entité (elle est supprimée) — capturer les données nécessaires au préalable si besoin d'archivage.
