# TP 06 — Sécurité Active Directory — Correction

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h15

> Chapitres associés : [06. Sécurité Active Directory](https://cours.kaya.ovh/active-directory/ad/06-securite-ad/)

---

## Objectifs

- Configurer la stratégie de mot de passe du domaine
- Tester le verrouillage de compte et le déverrouiller
- Activer et lire les journaux d'audit
- Identifier les membres des groupes privilégiés

---

## Partie A — Stratégie de mot de passe (20 min)

**A1.** Affiche la stratégie de mot de passe actuelle du domaine :
```powershell
Get-ADDefaultDomainPasswordPolicy
```
Quelles sont les valeurs par défaut pour la longueur minimale et la complexité ?

> [!success]- Afficher la correction — A1
> ```powershell
> Get-ADDefaultDomainPasswordPolicy
> ```
> Valeurs par défaut Windows Server :
> - `MinPasswordLength` : **7** caractères
> - `ComplexityEnabled` : **True**
> - `MaxPasswordAge` : **42 jours**
> - `PasswordHistoryCount` : **24**
> - `LockoutThreshold` : **0** (pas de verrouillage par défaut)

**A2.** Via la **Default Domain Policy** (`gpmc.msc`), configure la stratégie suivante :

| Paramètre | Valeur |
|-----------|--------|
| Longueur minimale | 10 caractères |
| Complexité | Activée |
| Durée de vie maximale | 60 jours |
| Historique | 5 mots de passe |
| Seuil de verrouillage | 3 tentatives |
| Durée de verrouillage | 15 minutes |

> [!success]- Afficher la correction — A2
> Dans `gpmc.msc` → Default Domain Policy → Modifier :
> `Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies de compte`
>
> Ou via PowerShell :
> ```powershell
> Set-ADDefaultDomainPasswordPolicy `
>   -Identity "ad.fournil.lab" `
>   -MinPasswordLength 10 `
>   -ComplexityEnabled $true `
>   -MaxPasswordAge (New-TimeSpan -Days 60) `
>   -PasswordHistoryCount 5 `
>   -LockoutThreshold 3 `
>   -LockoutDuration (New-TimeSpan -Minutes 15) `
>   -LockoutObservationWindow (New-TimeSpan -Minutes 15)
> ```

**A3.** Force l'application de la GPO et vérifie que la stratégie est bien prise en compte :
```powershell
gpupdate /force
Get-ADDefaultDomainPasswordPolicy
```

> [!success]- Afficher la correction — A3
> ```powershell
> gpupdate /force
> Get-ADDefaultDomainPasswordPolicy
> ```
> Les nouvelles valeurs doivent apparaître dans le retour de la commande.
>
> > les valeurs posées par `Set-ADDefaultDomainPasswordPolicy` **survivent** au `gpupdate /force`. Windows les reporte dans le `GptTmpl.inf` de la Default Domain Policy (`MinimumPasswordLength = 10`, `LockoutBadCount = 3`…), donc GUI et PowerShell restent cohérents.
>
> > [!warning] Effet de bord sur la suite de la formation
> > Les mots de passe du lab (`P@ssw0rd!`) font **9 caractères**. Dès que la longueur minimale passe à 10, toute création de compte ou promotion de DC avec ce mot de passe échoue, y compris le mot de passe **DSRM** d'un nouveau DC (*« The Directory Services Restore Mode password does not meet the minimum password length requirement »*, constaté en lab). Il faut utiliser par exemple `P@ssw0rd!2026` à partir d'ici.

**A4.** Tente de créer un utilisateur avec un mot de passe ne respectant pas la complexité (`Password`). Que se passe-t-il ?

> [!success]- Afficher la correction — A4
> ```powershell
> New-ADUser -Name "Test User" -SamAccountName "testuser" `
>   -AccountPassword (ConvertTo-SecureString "Password" -AsPlainText -Force) -Enabled $true `
>   -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```
> Erreur retournée : `The password does not meet the length, complexity, or history requirement of the domain.`
> Le mot de passe `Password` ne respecte pas la complexité (pas de chiffre, pas de caractère spécial).
>
> > [!warning] Piège
> > Malgré l'erreur, **l'objet `testuser` est créé**, mais **désactivé** et sans mot de passe valide. `New-ADUser` crée d'abord l'objet, puis échoue en posant le mot de passe. À montrer, puis à nettoyer :
> > ```powershell
> > Get-ADUser testuser | Select-Object Name, Enabled   # Enabled : False
> > Remove-ADUser testuser -Confirm:$false
> > ```
> > Sinon, le compte réapparaît plus loin dans `Search-ADAccount -AccountDisabled` (E2).

## Partie B — Verrouillage de compte (20 min)

**B1.** Depuis une session sur le poste client (ou via `runas`), tente de te connecter avec le compte `jrenard` en entrant un mauvais mot de passe **4 fois de suite**. Que se passe-t-il à la 4ème tentative ?

> [!success]- Afficher la correction — B1
> Après 3 tentatives échouées (seuil = 3), le compte est **verrouillé**. La 4ème tentative retourne : *"Votre compte a été verrouillé. Contactez votre administrateur système."*
>
> > [!warning] Taper un mauvais mot de passe **différent** à chaque essai
> > Le même mauvais mot de passe répété n'est compté **qu'une fois** dans `badPwdCount` (constaté en lab : quatre fois `mauvais!` laissent le compte déverrouillé, alors que `faux1!`, `faux2!`, `faux3!` le verrouillent au 3ᵉ essai).

**B2.** Depuis le DC, vérifie si le compte est verrouillé :
```powershell
Get-ADUser -Identity "jrenard" -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
  Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
```

> [!success]- Afficher la correction — B2
> ```powershell
> Get-ADUser -Identity "jrenard" -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
>   Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
> ```
> `LockedOut : True` — `BadLogonCount : 3` (ou plus selon les tentatives).

**B3.** Déverrouille le compte `jrenard` via PowerShell.

> [!success]- Afficher la correction — B3
> ```powershell
> Unlock-ADAccount -Identity "jrenard"
> ```
> Vérification :
> ```powershell
> Get-ADUser -Identity "jrenard" -Properties LockedOut | Select-Object LockedOut
> # LockedOut : False
> ```

**B4.** Trouve la commande pour lister **tous** les comptes verrouillés du domaine.

> [!success]- Afficher la correction — B4
> ```powershell
> Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LockedOut
> ```

## Partie C — Audit et journaux (20 min)

**C1.** Ouvre l'**Observateur d'événements** (`eventvwr.msc`) → Journaux Windows → **Sécurité**. Filtre sur l'ID d'événement **4625** (échec de connexion). Retrouve les tentatives échouées de la partie B.

> [!success]- Afficher la correction — C1
> Dans l'Observateur d'événements → Journal Sécurité → Filtrer le journal actuel → ID : `4625`.
> Chaque tentative échouée apparaît avec le nom du compte cible, la machine source et le code d'échec (ex : `0xC000006A` = mauvais mot de passe, `0xC0000234` = compte verrouillé).
>
> > Les tentatives doivent venir d'une **ouverture de session sur le poste client** (ou d'un `runas`). on trouve alors des 4625 **sur le poste** et **sur le DC**. En revanche, des échecs provoqués autrement (script, bind LDAP) incrémentent bien le compteur et verrouillent le compte **sans produire de 4625** sur le DC. Par défaut, l'audit *Validation des informations d'identification* et *Service d'authentification Kerberos* n'enregistre que les **succès**.

**C2.** Retrouve l'événement **4740** (verrouillage de compte). Quel compte a été verrouillé et depuis quelle machine ?

> [!success]- Afficher la correction — C2
> L'événement **4740** contient :
> - **Nom du compte** : `jrenard` (compte verrouillé)
> - **Appelant** : le DC qui a enregistré l'événement
> - **Machine source** : le nom du poste depuis lequel les tentatives ont eu lieu
>
> ![ad-tp06-evenement-4740](https://cours.kaya.ovh/active-directory/assets/supports/52ccd23d862b9d7bacc5.png)
> *Événement 4740 attendu. Le « Sujet » est `DC01$` (le DC qui verrouille), le compte verrouillé est `jrenard`, et **Nom de l’ordinateur de l’appelant** donne le poste d'origine : `PC-PROD-01`.*
>
> ```powershell
> Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 1 | Format-List TimeCreated, Message
> ```
>
> > En environnement multi-DC, l'événement 4740 est généré sur le DC qui a reçu les demandes d'authentification, mais aussi sur le PDC Emulator qui centralise les verrouillages.
>
> > [!warning] Aucun 4740 alors que le compte est bien verrouillé ?
> > Vérifier l'audit sur le DC : `auditpol /get /subcategory:"Gestion des comptes d'utilisateur"`. Si une **stratégie d'audit avancée** est configurée dans la *Default Domain Controllers Policy* (même pour une seule sous-catégorie), toutes les sous-catégories qu'elle ne mentionne pas passent à **Pas d'audit**, et les 4740 / 4720 disparaissent. Il faut alors y ajouter *Auditer la gestion des comptes d'utilisateur* (succès et échec).
> >
> > L'événement peut arriver avec **quelques secondes, voire une minute, de retard** sur le verrouillage effectif. Si la recherche ne renvoie rien, relancer avant de conclure.

**C3.** Via PowerShell, affiche les 5 derniers événements de type **4624** (connexion réussie) :
```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 5 |
  Select-Object TimeCreated, Message
```

> [!success]- Afficher la correction — C3
> ```powershell
> Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 5 |
>   Select-Object TimeCreated, Message
> ```
> Les connexions les plus récentes apparaissent en premier. On y voit le nom du compte, le type de connexion (2=interactif, 3=réseau, 10=remote) et la machine source.

**C4.** Crée un nouvel utilisateur `test_audit`. Dans les journaux de sécurité, retrouve l'événement correspondant à cette création (ID **4720**). Qui a créé le compte ?

> [!success]- Afficher la correction — C4
> ```powershell
> New-ADUser -Name "test_audit" -SamAccountName "test_audit" `
>   -AccountPassword (ConvertTo-SecureString "P@ssw0rd!2026" -AsPlainText -Force) `
>   -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" -Enabled $true
>
> Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4720} -MaxEvents 1 | Format-List TimeCreated, Message
> ```
> > Avec `P@ssw0rd!` (9 caractères), la création **échoue** depuis la partie A (longueur minimale 10). L'objet est tout de même créé désactivé, comme en A4.
> Dans les journaux, l'événement **4720** indique :
> - **Compte créé** : `test_audit`
> - **Par** : le compte admin utilisé pour créer l'utilisateur (ex: `FOURNIL\Administrateur`)
> - **Date/heure** de création

## Partie D — Moindre privilège (15 min)

**D1.** Liste les membres actuels du groupe `Domain Admins` :
```powershell
Get-ADGroupMember -Identity "Domain Admins" | Select-Object Name, SamAccountName
```
Y a-t-il des comptes qui ne devraient pas être là ?

> [!success]- Afficher la correction — D1
> Par défaut, `Domain Admins` contient uniquement `Administrateur`. Si d'autres comptes sont présents sans justification documentée, c'est un problème de sécurité. Le principe est : le moins de membres possible dans ce groupe.

**D2.** Crée un compte d'administration dédié pour l'admin système de Fournil :
- Nom : `adm.sysinfo`
- OU : `OU=Support,OU=Utilisateurs,OU=Fournil`
- Mot de passe : `Adm!Fournil@2025`
- Ne peut pas changer son mot de passe : Non
- Mot de passe n'expire jamais : Non

> [!success]- Afficher la correction — D2
> ```powershell
> New-ADUser `
>   -Name "adm.sysinfo" `
>   -SamAccountName "adm.sysinfo" `
>   -UserPrincipalName "adm.sysinfo@ad.fournil.lab" `
>   -Path "OU=Support,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "Adm!Fournil@2025" -AsPlainText -Force) `
>   -Enabled $true
> ```

**D3.** Ajoute `adm.sysinfo` au groupe `Account Operators` (gestion des comptes sans être Domain Admin). Quels droits cela lui confère-t-il ?

> [!success]- Afficher la correction — D3
> ```powershell
> Add-ADGroupMember -Identity "Account Operators" -Members "adm.sysinfo"
> ```
> `Account Operators` permet de :
> - Créer, modifier et supprimer des comptes utilisateurs et groupes (sauf dans les OUs protégées)
> - **Ne peut pas** modifier les membres de `Domain Admins`, `Administrators` ou `Account Operators`
> - **Ne peut pas** créer de comptes dans `CN=Users` et `CN=Computers` par défaut

**D4.** Crée un compte de service `svc_backup` dans une nouvelle OU `Services`, sous `OU=Fournil`, avec les options appropriées (cf. cours).

> [!success]- Afficher la correction — D4
> ```powershell
> New-ADOrganizationalUnit -Name "Services" -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
>
> New-ADUser `
>   -Name "svc_backup" `
>   -SamAccountName "svc_backup" `
>   -UserPrincipalName "svc_backup@ad.fournil.lab" `
>   -Path "OU=Services,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "Svc!Backup2025#" -AsPlainText -Force) `
>   -PasswordNeverExpires $true `
>   -CannotChangePassword $true `
>   -Enabled $true
> ```

## Partie E — Bonus

**E1.** Via PowerShell, affiche tous les comptes dont le mot de passe **n'expire jamais** :
```powershell
Get-ADUser -Filter {PasswordNeverExpires -eq $true} -Properties PasswordNeverExpires |
  Select-Object Name, SamAccountName
```
Est-ce normal pour tous ces comptes ?

> [!success]- Afficher la correction — E1
> ```powershell
> Get-ADUser -Filter {PasswordNeverExpires -eq $true} -Properties PasswordNeverExpires |
>   Select-Object Name, SamAccountName
> ```
> Comptes attendus avec mot de passe sans expiration :
> - `Administrateur` — normal (compte intégré)
> - `svc_backup` — normal (compte de service créé à l'instant)
> - `krbtgt` — normal (compte système Kerberos, ne jamais modifier manuellement)
>
> Tous les autres comptes utilisateurs avec `PasswordNeverExpires = True` sont à justifier.

**E2.** Affiche tous les comptes **désactivés** du domaine :
```powershell
Search-ADAccount -AccountDisabled | Select-Object Name, SamAccountName
```

> [!success]- Afficher la correction — E2
> ```powershell
> Search-ADAccount -AccountDisabled | Select-Object Name, SamAccountName, DistinguishedName
> ```
> `mlebrun` doit apparaître (désactivé au TP 03). Le compte `Invité` est aussi désactivé par défaut — c'est normal et recommandé.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/06-securite-ad/tp)
