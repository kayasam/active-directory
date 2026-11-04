# TP 02 — Structure logique : OUs et délégation

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
└── OU=Fournil
    ├── OU=Utilisateurs
    │   ├── OU=Direction
    │   ├── OU=Production
    │   ├── OU=Commercial
    │   └── OU=Support
    └── OU=Ordinateurs
        ├── OU=Postes
        └── OU=Serveurs
```

**B1.** Crée l'OU racine `Fournil`, puis ses deux sous-OUs `Utilisateurs` et `Ordinateurs`, via l'interface graphique.

**B2.** Crée les sous-OUs de `Utilisateurs` via **PowerShell**.

**B3.** Crée les sous-OUs de `Ordinateurs` via **PowerShell**.

**B4.** Liste toutes les OUs créées avec PowerShell. Quelle est la commande ?

---

## Partie C — Déplacer des objets (15 min)

**C1.** Dans `dsa.msc`, localise les conteneurs par défaut `CN=Computers` et `CN=Users`. Que contiennent-ils ?

**C2.** Le DC `DC01` est dans l'OU `Domain Controllers`. Est-ce correct ? Faut-il le déplacer ?

**C3.** Redirige le conteneur `Computers` par défaut vers `OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab`. Quelle commande utilises-tu ?

**C4.** Vérifie que la redirection est bien prise en compte :
```powershell
Get-ADDomain | Select-Object ComputersContainer
```
Quel résultat obtiens-tu ?

---

## Partie D — Délégation (30 min)

**D1.** Crée un utilisateur `helpdesk` dans `OU=Support,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab` (via `dsa.msc` ou PowerShell).

**D2.** Via l'**assistant de délégation** sur l'OU `Utilisateurs`, délègue à `helpdesk` la tâche : **"Réinitialiser les mots de passe utilisateur et forcer le changement au prochain accès"**.

**D3.** Pour tester la délégation :
- Ouvre une session PowerShell **en tant que** `helpdesk` :
```powershell
$cred = Get-Credential "FOURNIL\helpdesk"
```
- En tant qu'`Administrateur`, crée d'abord un compte de test `test.deleg` dans `OU=Direction,OU=Utilisateurs,OU=Fournil` (aucun autre utilisateur n'existe encore à ce stade du TP).
- Avec `$cred`, réinitialise le mot de passe de `test.deleg`.
- Avec `$cred`, tente de réinitialiser le mot de passe d'un compte **en dehors** de cette OU (ex : `Administrateur`, dans le conteneur `Users`). Que se passe-t-il ?

**D4.** La délégation est-elle visible dans les propriétés de l'OU ? Où peut-on la consulter dans `dsa.msc` ?

---

## Partie E — Bonus

**E1.** Supprime l'OU `OU=Commercial` sous `Utilisateurs`. Que se passe-t-il ? Comment contourner la protection ?

**E2.** Recrée l'OU supprimée avec PowerShell en désactivant la protection.

---

[Ouvrir la correction](https://cours.kaya.ovh/active-directory/ad/02-structure-logique/tp-corrigev2)


[Afficher les corrections](https://cours.kaya.ovh/active-directory/ad/02-structure-logique/tp-corrigev2)
