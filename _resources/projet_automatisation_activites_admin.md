# 📁 Projet d'Automatisation - Activités Administratives (Passation Stéphane)

---

## 1. Contexte & Objectifs
Ce document recense et structure l'ensemble des activités administratives actuellement prises en charge manuellement par **Stéphane** avant son prochain départ à la retraite. 
L'objectif est double :
1. **Assurer la continuité opérationnelle** en documentant clairement les processus de passation.
2. **Identifier les opportunités d'automatisation et d'optimisation** à intégrer dans la boîte à outils applicative `opsis_app` pour réduire le temps de traitement et sécuriser les processus.

---

## 2. Processus Opérationnels Détaillés

### 2.1 Gestion des Comptes Fournisseurs dans BoondManager

#### A. Nouveaux Fournisseurs "Digital"
* **Canal d'entrée** : Demande reçue via **Trello**.
* **Processus de création** :
  1. **Ressource** : Création de la fiche Ressource externe (`typeOf: 1`) à l'aide de l'extension Boond LinkedIn. Paramétrage complet du compte, activation et envoi des identifiants au prestataire.
  2. **Société** : Création de la fiche Société fournisseur dans Boond en se basant sur les informations publiques de **Pappers**.
  3. **Contact** : Création du contact via l'extension LinkedIn et rattachement à la fiche Société créée.
  4. **Suivi** : Création d'un fil de discussion dans Boond en mentionnant Marie pour initier la création de la prestation.

#### B. Nouveaux Fournisseurs "SI & Design"
* **Canal d'entrée** : Demande reçue par **e-mail**.
* **Processus de création** :
  1. **Ressource** : Le candidat a déjà été créé et converti en ressource par le manager. Stéphane intervient pour paramétrer le compte (tarifs, agence), activer les accès et les envoyer au prestataire.
  2. **Société** : Création de la fiche Société à partir des données **Pappers** (le candidat existant n'y étant pas lié).
  3. **Contact** : Création du contact via l'extension LinkedIn et association à la société.

#### C. Maintenance et Cycle de vie des Ressources
* **Inactivité (Sortie)** : Les ressources n'ayant eu aucune activité depuis **2 mois** doivent être passées en état **« Sortie »** pour couper leurs accès.
* **Réactivation** : Les ressources qui redeviennent actives doivent faire l'objet d'un reparamétrage complet (nouvelles dates de dispo, re-tarification, etc.).

---

### 2.2 Gestion Contractuelle
* **Initialisation** : Envoi au fournisseur de l'e-mail type *« Demande docs admin pour nouveau contrat »*.
* **Suivi & Relances** : 
  * Suivi du statut des pièces d'onboarding sur **Trello**.
  * En cas de relance infructueuse, notification à Nicole ou au manager concerné pour qu'ils relancent directement le fournisseur.
* **Finalisation** :
  * À réception, vérification de la validité et de la complétude des pièces.
  * Mise à jour de la fiche Société dans Boond.
  * Création du contrat dans l'onglet **« Administratif »** de la ressource.
  * Envoi du contrat signé via l'e-mail type *« Envoi contrat »*.
* **Renouvellements Annuels** : 
  * Clôture du contrat de l'année précédente dans BoondManager.
  * Création du nouveau contrat pour l'exercice à venir.

---

### 2.3 Suivi de la Conformité (Provigis)
> [!IMPORTANT]
> C'est l'un des processus les plus chronophages du périmètre (estimé à 3 jours par mois). Il présente un enjeu de conformité légale majeur (solidarité financière).

* **Contrôle Initial** : Vérification de la conformité du dossier du prestataire sur la plateforme Provigis dès la réception des documents administratifs. Suivi du statut dans Trello.
* **Contrôle Récurrent (Tous les 15 jours)** :
  * Extraction et état des lieux global des dossiers fournisseurs sur Provigis.
  * Point de suivi avec les managers sur les dossiers "à risque".
  * Envoi de l'e-mail type *« Important - Mise à jour de votre dossier sur Provigis »* aux prestataires en anomalie.
  * **Sanction** : Si aucune régularisation n'est constatée, Stéphane demande à Marie de **suspendre les paiements** du fournisseur.
* **Support Technique** : Relation avec Paola (contact support chez Provigis) pour résoudre les cas complexes (doublons de comptes, erreurs de téléchargement, comptes hors ligne).

---

### 2.4 Création des Tiers dans "Compta & Paie"
* **Déclenchement** : Envoi d'un e-mail de demande de référence fournisseur.
* **Configuration manuelle** :
  1. Connexion à l'application **Compta & Paie**.
  2. Accès à l'onglet **Paiement** -> **Paramètres**.
  3. Recherche de la société concernée.
  4. Saisie des coordonnées de paiement et des références fournisseurs dans le compte tiers.

---

### 2.5 Gestion des Bons de Commande (BDC) Fournisseurs
*(Note : Ce module est actuellement traité à part dans le cadre d'un développement en cours dans l'application).*

* **BDC Manuels** : 
  * Premier BDC standard généré depuis la fiche ressource BoondManager et envoyé par e-mail.
  * Cas des sociétés de portage : Création de BDC complexes regroupant plusieurs ressources et ajout des lignes de mission (MIS) correspondantes.
* **BDC Mensuels (Flux de masse)** :
  * Processus actuel : Extraction Power BI -> Tri des prestations -> Émission automatisée de **~250 BDC** par mois via un programme développé par "Découp".
  * **Point critique** : Ce programme requiert une documentation technique claire (fonctionnement, anomalies, exécution) pour être pérennisé.

---

### 2.6 Sécurité : Validation des RIB
> [!CAUTION]
> Mesure de sécurité critique visant à prévenir les fraudes au virement (fraude au changement de RIB).

* **Protocole** : En cas de demande de modification des coordonnées bancaires d'un fournisseur, un **appel téléphonique de contrôle** doit systématiquement être passé auprès du fournisseur pour valider oralement les nouvelles coordonnées avant tout changement dans le système de paiement.

---

## 3. Synthèse des Outils et Acteurs

### Outils Utilisés
* **ERP** : BoondManager (et son extension Chrome LinkedIn).
* **Suivi & Organisation** : Trello, Messagerie Outlook (modèles d'e-mails).
* **Vérification Légale** : Provigis, Pappers.
* **Comptabilité** : Outil interne ou tiers "Compta & Paie".
* **Automatisation BDC** : Programme "Découp".

### Parties Prenantes
* **Marie** : Responsable de la création des prestations, destinataire des alertes de suspension de paiement.
* **Nicole** : Relai pour les relances administratives.
* **Managers** : Initiateurs de l'onboarding SI & Design, intermédiaires pour les relances et la validation des risques.
* **Paola** : Support technique Provigis.

---

## 4. Métriques et Estimation de la Charge

* **Flux Nouveaux Fournisseurs** : ~6 nouveaux + ~5 réactivations = **11 dossiers/mois** *(Charge : 1 jour/mois)*.
* **Suivi Provigis** : ~50 fournisseurs sous contrôle permanent *(Charge : 3 jours/mois)*.
* **BDC Manuels** : ~6 boîtes de portage *(Charge : 0,5 jour/mois)*.
* **BDC Mensuels (Masse)** : ~250 BDC émis par le programme Découp *(Charge : 1 jour/mois)*.
* **Temps improductif constaté** : **20 % du temps total** perdu en relances et en double saisie.
* **Charge globale brute** : **6 à 7 jours par mois**.

---

## 5. Opportunités d'Automatisation prioritaires dans `opsis_app`

Pour optimiser le départ de Stéphane, voici les modules fonctionnels envisageables dans `opsis_app` en exploitant les API BoondManager :

| N° | Module Cible | Solution d'Automatisation | Gain de Temps / Sécurité | Faisabilité |
| :--- | :--- | :--- | :---: | :---: |
| **1** | **Portail d'Onboarding** | Formulaire avec saisie SIRET -> Appel API Pappers -> Création automatique Société + Ressource + Contact liés dans Boond. | Suppression de la saisie manuelle et des erreurs. | **Élevée** |
| **2** | **Suivi Provigis API** | Tâche d'arrière-plan interrogeant l'API Provigis pour mettre à jour automatiquement les statuts dans Boond et générer des alertes. | Gain de **2,5 jours/mois** ; sécurité juridique. | **Moyenne** |
| **3** | **Relances Docs Automatiques** | Relances e-mails automatiques programmées tant que le dossier fournisseur n'est pas complet/conforme. | Réduction des **20% de temps improductif**. | **Élevée** |
| **4** | **Workflow RIB Sécurisé** | Blocage du nouveau RIB en état "Non vérifié" avec obligation de remplir un compte-rendu d'appel de contrôle pour valider l'IBAN. | **Protection absolue contre la fraude au RIB**. | **Élevée** |
| **5** | **Gestion d'Inactivité** | Détection automatique des ressources inactives (60j sans temps ni mission) et passage automatisé (ou après confirmation) en statut "Sortie". | Sécurisation des accès informatiques. | **Moyenne** |
