# TP 02 — Structure logique : OUs et délégation — Correction

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

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

> [!success]- Afficher la correction — A1
> Structure attendue (ou équivalente) :
> ```
> ad.fournil.lab
> ├── OU=Utilisateurs
> │   ├── OU=Direction
> │   ├── OU=Production
> │   ├── OU=Commercial
> │   └── OU=Support
> └── OU=Ordinateurs
>     ├── OU=Postes
>     └── OU=Serveurs
> ```
> Justification de la séparation utilisateurs/ordinateurs : les **GPO de configuration ordinateur** (scripts de démarrage, sécurité système) s'appliquent au démarrage de la machine. Les **GPO utilisateur** (fond d'écran, lecteurs réseau) s'appliquent à la connexion. Mélanger les deux dans la même OU complique le ciblage des GPO.

**A2.** Quelle est la différence entre un conteneur (comme `Computers`) et une OU ? Pourquoi ne pas utiliser les conteneurs par défaut ?

> [!success]- Afficher la correction — A2
> Un **conteneur** (`CN=Computers`, `CN=Users`) est un objet AD natif, créé par Windows. Il ne supporte pas l'application de GPO ni la délégation fine. Une **OU** est créée par l'administrateur et supporte les deux. En production, on ne laisse jamais les objets dans les conteneurs par défaut.

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

> [!success]- Afficher la correction — B1
> Via `dsa.msc` : clic droit sur `ad.fournil.lab` → Nouveau → Unité d'organisation → `Utilisateurs`, puis idem pour `Ordinateurs`.

**B2.** Crée les sous-OUs de `Utilisateurs` via **PowerShell**.

> [!success]- Afficher la correction — B2
> ```powershell
> New-ADOrganizationalUnit -Name "Direction"  -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab"
> New-ADOrganizationalUnit -Name "Production" -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab"
> New-ADOrganizationalUnit -Name "Commercial" -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab"
> New-ADOrganizationalUnit -Name "Support"    -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab"
> ```

**B3.** Crée les sous-OUs de `Ordinateurs` via **PowerShell**.

> [!success]- Afficher la correction — B3
> ```powershell
> New-ADOrganizationalUnit -Name "Postes"   -Path "OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"
> New-ADOrganizationalUnit -Name "Serveurs" -Path "OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"
> ```

**B4.** Liste toutes les OUs créées avec PowerShell. Quelle est la commande ?

> [!success]- Afficher la correction — B4
> ```powershell
> Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Sort-Object DistinguishedName
> ```
>
> ![ad-tp02-arborescence-ou](https://cours.kaya.ovh/active-directory/assets/supports/ea7583a37414984cd3ee.png)
> *Résultat attendu dans `dsa.msc` : les OUs (icône dossier + annuaire) à côté des conteneurs par défaut (dossier simple).*

## Partie C — Déplacer des objets (15 min)

**C1.** Dans `dsa.msc`, localise les conteneurs par défaut `CN=Computers` et `CN=Users`. Que contiennent-ils ?

> [!success]- Afficher la correction — C1
> - `CN=Computers` contient les ordinateurs joints au domaine qui n'ont pas été placés dans une OU.
> - `CN=Users` contient les comptes et groupes créés par défaut lors de l'installation (Administrateur, Invité, groupes Domain Admins, etc.).

**C2.** Le DC `DC01` est dans l'OU `Domain Controllers`. Est-ce correct ? Faut-il le déplacer ?

> [!success]- Afficher la correction — C2
> Non, le DC `DC01` est bien dans `OU=Domain Controllers` — c'est correct. Cette OU est créée automatiquement lors de la promotion et est dédiée aux contrôleurs de domaine. Ne jamais la supprimer ni déplacer les DC dans une autre OU sans raison.

**C3.** Redirige le conteneur `Computers` par défaut vers `OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab`. Quelle commande utilises-tu ?

> [!success]- Afficher la correction — C3
> ```powershell
> redircmp "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"
> ```

**C4.** Vérifie que la redirection est bien prise en compte :
```powershell
Get-ADDomain | Select-Object ComputersContainer
```
Quel résultat obtiens-tu ?

> [!success]- Afficher la correction — C4
> ```powershell
> Get-ADDomain | Select-Object ComputersContainer
> ```
> Résultat attendu :
> ```
> ComputersContainer
> ------------------
> OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab
> ```
> Les prochains ordinateurs joints au domaine arriveront directement dans `OU=Postes`.

## Partie D — Délégation (30 min)

**D1.** Crée un utilisateur `helpdesk` dans `OU=Support,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab` (via `dsa.msc` ou PowerShell).

> [!success]- Afficher la correction — D1
> ```powershell
> New-ADUser -Name "helpdesk" `
>            -SamAccountName "helpdesk" `
>            -UserPrincipalName "helpdesk@ad.fournil.lab" `
>            -Path "OU=Support,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>            -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>            -Enabled $true
> ```

**D2.** Via l'**assistant de délégation** sur l'OU `Utilisateurs`, délègue à `helpdesk` la tâche : **"Réinitialiser les mots de passe utilisateur et forcer le changement au prochain accès"**.

> [!success]- Afficher la correction — D2
> Via `dsa.msc` : clic droit sur `OU=Utilisateurs` → **Déléguer le contrôle** → Ajouter `helpdesk` → Cocher **"Réinitialiser les mots de passe utilisateur et forcer le changement au prochain accès"** → Terminer.
>
> ![ad-tp02-menu-deleguer](https://cours.kaya.ovh/active-directory/assets/supports/5aa8beb53668c0431a7f.png)
>
> ![ad-tp02-assistant-delegation](https://cours.kaya.ovh/active-directory/assets/supports/1619745c6175b2ae115d.png)
> *Deuxième case de la liste, et elle seule : la première (« Créer, supprimer et gérer les comptes ») donnerait bien plus de droits au support.*

**D3.** Pour tester la délégation :
- Ouvre une session PowerShell **en tant que** `helpdesk` :
```powershell
$cred = Get-Credential "FOURNIL\helpdesk"
```
- En tant qu'`Administrateur`, crée d'abord un compte de test `test.deleg` dans `OU=Direction,OU=Utilisateurs` (aucun autre utilisateur n'existe encore à ce stade du TP).
- Avec `$cred`, réinitialise le mot de passe de `test.deleg`.
- Avec `$cred`, tente de réinitialiser le mot de passe d'un compte **en dehors** de cette OU (ex : `Administrateur`, dans le conteneur `Users`). Que se passe-t-il ?

> [!success]- Afficher la correction — D3
> ```powershell
> # En tant qu'Administrateur : un compte de test dans l'OU déléguée
> New-ADUser -Name "test.deleg" -Path "OU=Direction,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Enabled $true
>
> # En tant que helpdesk
> $cred = Get-Credential "FOURNIL\helpdesk"
>
> # Dans l'OU Utilisateurs : fonctionne
> Set-ADAccountPassword -Identity test.deleg -Reset `
>   -NewPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -Credential $cred
>
> # Hors de l'OU (conteneur Users) : refusé
> Set-ADAccountPassword -Identity Administrateur -Reset `
>   -NewPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -Credential $cred
> # → Set-ADAccountPassword : Access is denied   (« Accès refusé »)
> ```
> La délégation porte sur l'OU `Utilisateurs` et ses sous-OUs uniquement. réinitialisation acceptée dans l'OU, **Access is denied** en dehors.
>
> > Hors de l'OU, on cible un **utilisateur** (`Administrateur`, dans `CN=Users`) : `Domain Controllers` ne contient que des comptes ordinateurs.

**D4.** La délégation est-elle visible dans les propriétés de l'OU ? Où peut-on la consulter dans `dsa.msc` ?

> [!success]- Afficher la correction — D4
> La délégation n'est pas visible directement dans les propriétés standard. Il faut activer **Affichage → Fonctionnalités avancées** dans `dsa.msc`, puis ouvrir les propriétés de l'OU → onglet **Sécurité**. On y voit les ACE (Access Control Entries) ajoutées pour le compte `helpdesk`.

## Partie E — Bonus

**E1.** Supprime l'OU `OU=Commercial` sous `Utilisateurs`. Que se passe-t-il ? Comment contourner la protection ?

> [!success]- Afficher la correction — E1
> Tentative de suppression → refus :
> - dans `dsa.msc` : *« Vous ne disposez pas de privilèges suffisants pour supprimer Commercial, ou cet objet est protégé contre la suppression accidentelle »* ;
> - en PowerShell (`Remove-ADOrganizationalUnit`) : simplement **`Access is denied`** (« Accès refusé »), même en Admin du domaine.
>
> > Le message PowerShell est trompeur : la protection est en réalité une **ACE « Refuser — Supprimer »** pour *Tout le monde* posée sur l'OU. Elle est visible dans l'onglet **Sécurité** (fonctionnalités avancées).
>
> Pour contourner : dans `dsa.msc` avec les fonctionnalités avancées activées, ouvrir les propriétés de l'OU → onglet **Objet** → décocher **"Protéger l'objet contre une suppression accidentelle"**.
>
> Via PowerShell :
> ```powershell
> Set-ADOrganizationalUnit -Identity "OU=Commercial,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>                          -ProtectedFromAccidentalDeletion $false
>
> Remove-ADOrganizationalUnit -Identity "OU=Commercial,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" -Confirm:$false
> ```

**E2.** Recrée l'OU supprimée avec PowerShell en désactivant la protection.

> [!success]- Afficher la correction — E2
> ```powershell
> New-ADOrganizationalUnit -Name "Commercial" `
>                          -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>                          -ProtectedFromAccidentalDeletion $false
> ```

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/02-structure-logique/tp)
