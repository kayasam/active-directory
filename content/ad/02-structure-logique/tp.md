---
title: "TP 02 — Structure logique : OUs et délégation"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/02-structure-logique"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/02-structure-logique/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/02-structure-logique/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/02-structure-logique.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 1h15

> Chapitres associés : [02. Structure logique : OUs, outils, délégation](https://cours.kaya.ovh/active-directory/ad/02-structure-logique/)

---

## Objectifs

- Concevoir une structure d'OUs adaptée à Fournil
- Créer les OUs via l'interface graphique et PowerShell
- Déplacer des objets dans les bonnes OUs
- Mettre en place une délégation administrative simple

---

## Contexte

Tu administres le domaine `ad.fournil.lab` de la société **Fournil**. L'entreprise est organisée en 4 pôles :
- **Direction** — gérance et secrétariat
- **Production** — boulangerie, pâtisserie et conditionnement
- **Commercial** — ventes et marketing
- **Support** — RH et Informatique

Tu dois construire la structure d'OUs qui reflétera cette organisation.

---

## Partie A — Concevoir la structure (10 min)

**A1.** Sur papier (ou dans un fichier texte), dessine l'arborescence d'OUs que tu vas créer pour Fournil. Justifie ton choix : pourquoi séparer ordinateurs et utilisateurs ?

**A2.** Quelle est la différence entre un conteneur (comme `Computers`) et une OU ? Pourquoi ne pas utiliser les conteneurs par défaut ?

---

## Partie B — Créer les OUs (20 min)

Crée la structure suivante dans `ad.fournil.lab` via **`dsa.msc`** :

```
ad.fournil.lab
├── OU=Utilisateurs
│   ├── OU=Direction
│   ├── OU=Production
│   ├── OU=Commercial
│   └── OU=Support
└── OU=Ordinateurs
    ├── OU=Postes
    └── OU=Serveurs
```

**B1.** Crée les deux OUs racines (`Utilisateurs` et `Ordinateurs`) via l'interface graphique.

**B2.** Crée les sous-OUs de `Utilisateurs` via **PowerShell**.

**B3.** Crée les sous-OUs de `Ordinateurs` via **PowerShell**.

**B4.** Liste toutes les OUs créées avec PowerShell. Quelle est la commande ?

---

## Partie C — Déplacer des objets (15 min)

**C1.** Dans `dsa.msc`, localise les conteneurs par défaut `CN=Computers` et `CN=Users`. Que contiennent-ils ?

**C2.** Le DC `DC01` est dans l'OU `Domain Controllers`. Est-ce correct ? Faut-il le déplacer ?

**C3.** Redirige le conteneur `Computers` par défaut vers `OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab`. Quelle commande utilises-tu ?

**C4.** Vérifie que la redirection est bien prise en compte :
```powershell
Get-ADDomain | Select-Object ComputersContainer
```
Quel résultat obtiens-tu ?

---

## Partie D — Délégation (30 min)

**D1.** Crée un utilisateur `helpdesk` dans `OU=Support,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab` (via `dsa.msc` ou PowerShell).

**D2.** Via l'**assistant de délégation** sur l'OU `Utilisateurs`, délègue à `helpdesk` la tâche : **"Réinitialiser les mots de passe utilisateur et forcer le changement au prochain accès"**.

**D3.** Pour tester la délégation :
- Ouvre une session PowerShell **en tant que** `helpdesk` :
```powershell
$cred = Get-Credential "FOURNIL\helpdesk"
```
- En tant qu'`Administrateur`, crée d'abord un compte de test `test.deleg` dans `OU=Direction,OU=Utilisateurs` (aucun autre utilisateur n'existe encore à ce stade du TP).
- Avec `$cred`, réinitialise le mot de passe de `test.deleg`.
- Avec `$cred`, tente de réinitialiser le mot de passe d'un compte **en dehors** de cette OU (ex : `Administrateur`, dans le conteneur `Users`). Que se passe-t-il ?

**D4.** La délégation est-elle visible dans les propriétés de l'OU ? Où peut-on la consulter dans `dsa.msc` ?

---

## Partie E — Bonus

**E1.** Supprime l'OU `OU=Commercial` sous `Utilisateurs`. Que se passe-t-il ? Comment contourner la protection ?

**E2.** Recrée l'OU supprimée avec PowerShell en désactivant la protection.

---


