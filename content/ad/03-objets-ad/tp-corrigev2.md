---
title: "TP 03 — Objets AD : utilisateurs, ordinateurs, groupes — Correction"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/03-objets-ad"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/03-objets-ad-corrigev2.md">↓ Télécharger le corrigé (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>
<nav class="exercise-resources" aria-label="Ressources du TP"><a href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/tp">Énoncé</a><a class="exercise-correction" href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/tp-corrigev2" aria-current="page">Corrigé</a></nav>

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h30

> Chapitres associés : [03. Objets AD : utilisateurs, ordinateurs, groupes](https://cours.kaya.ovh/active-directory/ad/03-objets-ad/)

---

## Objectifs

- Créer des comptes utilisateurs via l'interface graphique et PowerShell
- Importer des utilisateurs en masse depuis un fichier CSV
- Gérer les comptes ordinateurs
- Créer des groupes et appliquer le modèle AGDLP

---

## Contexte

Tu continues sur le domaine `ad.fournil.lab` de la société **Fournil**. La structure d'OUs du TP 02 doit être en place (Direction, Production, Commercial, Support).

---

## Partie A — Comptes utilisateurs (25 min)

**A1.** Crée les utilisateurs suivants via **`dsa.msc`** dans les bonnes OUs :

| Prénom | Nom | Pôle | Login |
|--------|-----|------|-------|
| Claire | Fontaine | Direction | `cfontaine` |
| Marc | Lebrun | Production | `mlebrun` |

Options : mot de passe `P@ssw0rd!`, changer le mot de passe à la prochaine connexion.

> [!success]- Afficher la correction — A1
> Via `dsa.msc` : clic droit sur l'OU cible → Nouveau → Utilisateur → remplir les champs.

**A2.** Crée les utilisateurs suivants via **PowerShell** :

| Prénom | Nom | Pôle | Login |
|--------|-----|------|-------|
| Sophie | Dupont | Production | `sdupont` |
| Thomas | Vidal | Commercial | `tvidal` |
| Julie | Renard | Support | `jrenard` |

> [!success]- Afficher la correction — A2
> ```powershell
> New-ADUser -Name "Sophie Dupont" -GivenName "Sophie" -Surname "Dupont" `
>   -SamAccountName "sdupont" -UserPrincipalName "sdupont@ad.fournil.lab" `
>   -Path "OU=Production,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>   -ChangePasswordAtLogon $true -Enabled $true
>
> New-ADUser -Name "Thomas Vidal" -GivenName "Thomas" -Surname "Vidal" `
>   -SamAccountName "tvidal" -UserPrincipalName "tvidal@ad.fournil.lab" `
>   -Path "OU=Commercial,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>   -ChangePasswordAtLogon $true -Enabled $true
>
> New-ADUser -Name "Julie Renard" -GivenName "Julie" -Surname "Renard" `
>   -SamAccountName "jrenard" -UserPrincipalName "jrenard@ad.fournil.lab" `
>   -Path "OU=Support,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>   -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>   -ChangePasswordAtLogon $true -Enabled $true
> ```

**A3.** Vérifie que tous les comptes sont créés :
```powershell
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" -SearchScope Subtree | Select-Object Name, SamAccountName, Enabled
```

> [!success]- Afficher la correction — A3
> ```powershell
> Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" -SearchScope Subtree |
>   Select-Object Name, SamAccountName, Enabled
> ```
> **6** utilisateurs attendus : Claire, Marc, Sophie, Thomas, Julie **et `helpdesk`**, créé au TP 02 dans `OU=Support` (la recherche est en `Subtree`).

**A4.** Le compte de `Marc Lebrun` doit être temporairement désactivé (arrêt maladie longue durée). Désactive-le via PowerShell.

> [!success]- Afficher la correction — A4
> ```powershell
> Disable-ADAccount -Identity "mlebrun"
> ```
> Vérification :
> ```powershell
> Get-ADUser -Identity "mlebrun" | Select-Object Enabled
> # Enabled : False
> ```

**A5.** Réinitialise le mot de passe de `Julie Renard` à `NewP@ss2025!` sans forcer le changement au prochain logon.

> [!success]- Afficher la correction — A5
> ```powershell
> Set-ADAccountPassword -Identity "jrenard" `
>   -NewPassword (ConvertTo-SecureString "NewP@ss2025!" -AsPlainText -Force) -Reset
> Set-ADUser -Identity "jrenard" -ChangePasswordAtLogon $false
> ```

## Partie B — Import en masse (20 min)

**B1.** Crée le fichier `C:\import_users.csv` avec le contenu suivant :

```
Prenom,Nom,OU
Laura,Morin,Support
Kevin,Garnier,Production
Nathalie,Bouchard,Direction
Pierre,Aubert,Commercial
```

> [!success]- Afficher la correction — B1
> Création du fichier CSV :
> ```powershell
> @"
> Prenom,Nom,OU
> Laura,Morin,Support
> Kevin,Garnier,Production
> Nathalie,Bouchard,Direction
> Pierre,Aubert,Commercial
> "@ | Out-File "C:\import_users.csv" -Encoding UTF8
> ```

**B2.** Écris le script PowerShell qui importe ces utilisateurs. Le login doit être construit automatiquement : première lettre du prénom + nom en minuscules (ex : `lmorin`).

> [!success]- Afficher la correction — B2
> ```powershell
> Import-Csv "C:\import_users.csv" | ForEach-Object {
>     $sam = ($_.Prenom[0] + $_.Nom).ToLower()
>     New-ADUser `
>       -Name "$($_.Prenom) $($_.Nom)" `
>       -GivenName $_.Prenom `
>       -Surname $_.Nom `
>       -SamAccountName $sam `
>       -UserPrincipalName "$sam@ad.fournil.lab" `
>       -Path "OU=$($_.OU),OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>       -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>       -ChangePasswordAtLogon $true `
>       -Enabled $true
> }
> ```

**B3.** Vérifie l'import. Combien d'utilisateurs sont maintenant présents dans l'OU `Utilisateurs` (toutes sous-OUs confondues) ?

> [!success]- Afficher la correction — B3
> ```powershell
> (Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" -SearchScope Subtree).Count
> ```
> **10** utilisateurs attendus (5 créés en partie A + `helpdesk` du TP 02 + 4 importés). Si tu as aussi gardé `test.deleg` (TP 02, D3), il en trouve 11.

## Partie C — Jonction Windows 11 et comptes ordinateurs (30 min)

> **Contexte réseau** : DC01 est sur le réseau interne Hyper-V `192.168.3.0/24`. Le poste Windows 11 que tu vas joindre sera `PC-PROD-01` à l'adresse `192.168.3.100`.

**C1.** Configure l'adresse IP fixe de ta machine Windows 11. Via PowerShell (administrateur local) :

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.3.100 -PrefixLength 24 -DefaultGateway 192.168.3.254
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.3.10
```

Ou via l'interface graphique : **Paramètres → Réseau et Internet → Ethernet → Modifier** → attribution manuelle.

| Paramètre | Valeur |
|-----------|--------|
| Adresse IP | `192.168.3.100` |
| Masque | `255.255.255.0` |
| Passerelle | `192.168.3.254` |
| DNS préféré | `192.168.3.10` (DC01) |

> [!success]- Afficher la correction — C1
> Commandes de l'énoncé. Le point qui compte : **DNS préféré = `192.168.3.10` (DC01)**, et rien d'autre.

**C2.** Avant de joindre, vérifie la connectivité depuis Windows 11 :

```powershell
# Le DC doit répondre
Test-NetConnection 192.168.3.10

# Le domaine doit se résoudre
Resolve-DnsName ad.fournil.lab
```

Que retourne `Resolve-DnsName ad.fournil.lab` ? Sur quelle IP pointe le domaine ? Que se passerait-il si le DNS était 8.8.8.8 ?

> [!success]- Afficher la correction — C2
> ```powershell
> Test-NetConnection 192.168.3.10        # PingSucceeded : True
> Resolve-DnsName ad.fournil.lab         # ad.fournil.lab  A  192.168.3.10
> ```
> Le domaine pointe sur l'IP du DC. Avec `8.8.8.8` en DNS, la réponse serait **« DNS name does not exist »** (à tester avec `Resolve-DnsName ad.fournil.lab -Server 8.8.8.8`) : `ad.fournil.lab` n'existe que dans le DNS du DC, et la jonction échouerait avec *« Un contrôleur de domaine pour le domaine ad.fournil.lab n'a pas pu être contacté »*.

**C3.** Joins la machine au domaine `ad.fournil.lab` via l'interface graphique :

1. Clic droit sur **Démarrer → Système**
2. Cliquer sur **Renommer ce PC (Paramètres avancés)**
3. Onglet **Nom de l'ordinateur** → **Modifier**
4. Cocher **Domaine** → saisir `ad.fournil.lab`
5. S'authentifier avec le compte `Administrateur` du domaine
6. **Redémarrer** — indispensable : sans redémarrage, le poste se considère encore en `WORKGROUP` et n'applique aucune GPO

Ou via PowerShell (le redémarrage sera automatique) :

```powershell
Add-Computer -DomainName "ad.fournil.lab" -Credential (Get-Credential) -Restart
```

> [!success]- Afficher la correction — C3
> ```powershell
> Add-Computer -DomainName "ad.fournil.lab" -Credential (Get-Credential) -Restart
> ```
> Message *« Bienvenue dans le domaine ad.fournil.lab »*, puis **redémarrage obligatoire**.
>
> > Attention : tant que le poste n'a pas redémarré, il se présente encore comme `WORKGROUP\PC-PROD-01$` et `gpresult` affiche *« Group Policy was applied from: N/A »*, sans aucune GPO. Le TP 05 ne fonctionnera pas sur un poste non redémarré.

**C4.** Après le redémarrage, connecte-toi avec un compte de domaine :
- Clique sur **Autre utilisateur**
- Saisis `FOURNIL\cfontaine` (compte créé en Partie A)
- Dans quel chemin le profil local est-il créé ?

> [!success]- Afficher la correction — C4
> Connexion avec `FOURNIL\cfontaine`. Le compte a l'option « changer le mot de passe à la prochaine ouverture de session » (partie A) : Windows demande donc d'abord un **nouveau mot de passe**. Le profil local est créé dans **`C:\Users\cfontaine`**.

**C5.** Depuis **DC01**, vérifie la présence du compte ordinateur :

```powershell
Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
```

Dans quelle OU le compte a-t-il atterri ? Pourquoi ? (Pense à ce que tu as fait au TP 02, partie C.)

S'il est resté dans `CN=Computers` (redirection non faite), déplace-le dans `OU=Postes,OU=Ordinateurs` via `dsa.msc` (glisser-déposer) ou PowerShell :

```powershell
Get-ADComputer PC-PROD-01 | Move-ADObject -TargetPath "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"
```

> [!success]- Afficher la correction — C5
> ```powershell
> Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
> ```
> Résultat attendu :
> ```
> Name            DistinguishedName
> ----            -----------------
> DC01            CN=DC01,OU=Domain Controllers,DC=ad,DC=fournil,DC=lab
> PC-DIRECTION-01 CN=PC-DIRECTION-01,OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab
> PC-PROD-01      CN=PC-PROD-01,OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab
> ```
> `PC-PROD-01` arrive **directement dans `OU=Postes`** grâce au `redircmp` du TP 02 : il n'y a rien à déplacer. Sans redirection, il serait dans `CN=Computers`.
>
> > Piège : la commande `Move-ADObject -Identity "CN=PC-PROD-01,CN=Computers,…"` échoue alors avec **« Directory object not found »**, puisque l'objet n'y est pas. Pour déplacer sans connaître l'emplacement exact : `Get-ADComputer PC-PROD-01 | Move-ADObject -TargetPath "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"`.

**C6.** Pré-crée un second compte ordinateur `PC-DIRECTION-01` directement dans la bonne OU :

```powershell
New-ADComputer -Name "PC-DIRECTION-01" `
               -Path "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab" `
               -Enabled $true
```

Quel est l'avantage de pré-créer le compte avant de joindre la machine physique ?

> [!success]- Afficher la correction — C6
> ```powershell
> New-ADComputer -Name "PC-DIRECTION-01" `
>                -Path "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab" `
>                -Enabled $true
> ```
> Avantages de la pré-création :
> - le compte est **directement dans la bonne OU** : les GPO s'appliquent **dès le premier démarrage** ;
> - on peut **déléguer la jonction** (onglet *Utilisateur ou groupe autorisé à joindre…*) à un technicien qui n'est pas Admin du domaine ;
> - on maîtrise le **nommage** des postes avant leur arrivée.

## Partie D — Groupes et AGDLP (30 min)

**D1.** Crée les groupes suivants via PowerShell dans `OU=Groupes` (à créer si elle n'existe pas) :

| Nom | Portée | Type |
|-----|--------|------|
| `GG_Direction` | Global | Sécurité |
| `GG_Production` | Global | Sécurité |
| `GG_Commercial` | Global | Sécurité |
| `GG_Support` | Global | Sécurité |
| `DL_Partage_Production_Lecture` | Domaine local | Sécurité |
| `DL_Partage_Production_Ecriture` | Domaine local | Sécurité |

> [!success]- Afficher la correction — D1
> ```powershell
> # Créer l'OU Groupes si elle n'existe pas
> New-ADOrganizationalUnit -Name "Groupes" -Path "DC=ad,DC=fournil,DC=lab"
>
> # Groupes globaux
> New-ADGroup -Name "GG_Direction"  -GroupScope Global      -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
> New-ADGroup -Name "GG_Production" -GroupScope Global      -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
> New-ADGroup -Name "GG_Commercial" -GroupScope Global      -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
> New-ADGroup -Name "GG_Support"    -GroupScope Global      -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
>
> # Groupes domaine local
> New-ADGroup -Name "DL_Partage_Production_Lecture"  -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
> New-ADGroup -Name "DL_Partage_Production_Ecriture" -GroupScope DomainLocal -GroupCategory Security -Path "OU=Groupes,DC=ad,DC=fournil,DC=lab"
> ```

**D2.** Ajoute les utilisateurs dans les groupes globaux correspondants à leur pôle.

> [!success]- Afficher la correction — D2
> ```powershell
> # Direction
> Add-ADGroupMember -Identity "GG_Direction"  -Members "cfontaine","nbouchard"
>
> # Production
> Add-ADGroupMember -Identity "GG_Production" -Members "mlebrun","sdupont","kgarnier"
>
> # Commercial
> Add-ADGroupMember -Identity "GG_Commercial" -Members "tvidal","paubert"
>
> # Support
> Add-ADGroupMember -Identity "GG_Support"    -Members "jrenard","lmorin"
> ```

**D3.** Imbrique les groupes globaux dans les groupes domaine local :
- `GG_Production` → `DL_Partage_Production_Ecriture`

> [!success]- Afficher la correction — D3
> ```powershell
> Add-ADGroupMember -Identity "DL_Partage_Production_Lecture"  -Members "GG_Production"
> Add-ADGroupMember -Identity "DL_Partage_Production_Ecriture" -Members "GG_Production"
> ```

**D4.** Crée le dossier `C:\Partages\fournil\Production` sur le DC, puis applique les permissions NTFS :
- `DL_Partage_Production_Lecture` → droit **Lecture**
- `DL_Partage_Production_Ecriture` → droit **Modification**

> [!success]- Afficher la correction — D4
> ```powershell
> New-Item -ItemType Directory -Path "C:\Partages\fournil\Production" -Force
>
> # Lecture pour DL_Partage_Production_Lecture
> $acl = Get-Acl "C:\Partages\fournil\Production"
> $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
>     "FOURNIL\DL_Partage_Production_Lecture", "Read", "ContainerInherit,ObjectInherit", "None", "Allow")
> $acl.AddAccessRule($rule)
>
> # Modification pour DL_Partage_Production_Ecriture
> $rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule(
>     "FOURNIL\DL_Partage_Production_Ecriture", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
> $acl.AddAccessRule($rule2)
>
> Set-Acl "C:\Partages\fournil\Production" $acl
> ```

**D5.** Explique en une phrase pourquoi on n'attribue pas directement les permissions aux utilisateurs ou aux groupes globaux.

> [!success]- Afficher la correction — D5
> On n'attribue pas les permissions directement aux utilisateurs car quand un employé change de pôle, il faudrait modifier manuellement chaque ressource. Avec AGDLP, il suffit de le retirer d'un groupe global et de l'ajouter à un autre : toutes les permissions suivent automatiquement.

## Partie E — Bonus

**E1.** Trouve la commande PowerShell pour lister tous les groupes dont `jrenard` est membre.

> [!success]- Afficher la correction — E1
> ```powershell
> Get-ADPrincipalGroupMembership -Identity "jrenard" | Select-Object Name, GroupScope, GroupCategory
> ```

**E2.** L'utilisatrice `sdupont` quitte la Production pour rejoindre le pôle Commercial. Quelles actions dois-tu effectuer dans AD pour que ses accès suivent automatiquement son changement de pôle ?

> [!success]- Afficher la correction — E2
> Actions à réaliser :
> 1. Déplacer l'objet utilisateur vers `OU=Commercial,OU=Utilisateurs` :
> ```powershell
> Move-ADObject -Identity (Get-ADUser "sdupont").DistinguishedName `
>               -TargetPath "OU=Commercial,OU=Utilisateurs,DC=ad,DC=fournil,DC=lab"
> ```
> 2. Retirer du groupe `GG_Production` :
> ```powershell
> Remove-ADGroupMember -Identity "GG_Production" -Members "sdupont" -Confirm:$false
> ```
> 3. Ajouter au groupe `GG_Commercial` :
> ```powershell
> Add-ADGroupMember -Identity "GG_Commercial" -Members "sdupont"
> ```
> Grâce à AGDLP, les accès aux partages Production sont révoqués et ceux du Commercial sont accordés automatiquement. Aucune modification sur les ressources n'est nécessaire.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/03-objets-ad/tp)
