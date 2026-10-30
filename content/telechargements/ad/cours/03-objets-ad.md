# 03 — Objets AD : utilisateurs, ordinateurs, groupes

> **Objectif** : Créer et gérer les objets Active Directory essentiels : comptes utilisateurs, comptes ordinateurs, groupes. Appliquer le modèle AGDLP.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01`

**Outils abordés :** `dsa.msc`, `dsac.exe`, module PowerShell `ActiveDirectory`
**Concepts clés :** UPN, SAMAccountName, types de groupes, portée, AGDLP

---

## 1. Les comptes utilisateurs

Les comptes utilisateurs permettent :
- la connexion au domaine
- l'accès aux ressources partagées
- l'application des GPO côté utilisateur

- [Gérer des comptes d'utilisateur — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage-user-accounts-in-windows-server)
- [Utilisateurs — RDR-IT](https://rdr-it.com/course/active-directory-les-bases/utilisateurs/)

### Attributs essentiels

| Attribut | Exemple | Rôle |
|----------|---------|------|
| **SAMAccountName** | `cfontaine` | Connexion legacy (`FOURNIL\cfontaine`) |
| **UPN** (User Principal Name) | `cfontaine@ad.fournil.lab` | Connexion moderne (format email) |
| **Nom complet** (DisplayName) | `Claire Fontaine` | Affiché dans l'annuaire |
| **Mot de passe** | — | Doit respecter la stratégie du domaine |
| **OU** (path) | `OU=Gerance,OU=Direction,OU=Fournil` | Localisation dans l'annuaire |

> [!TIP] SAMAccountName vs UPN
> Le SAMAccountName est limité à 20 caractères et reste pour la compatibilité. L'UPN est le format moderne, utilisé notamment pour Azure AD Connect et l'authentification Microsoft 365.

### Créer un compte utilisateur

#### Via `dsa.msc` (GUI)

1. Clic droit sur l'OU cible → **Nouveau → Utilisateur**
2. Renseigner prénom, nom, nom d'ouverture de session
3. Définir le mot de passe et les options

Options de compte courantes :

| Option | Usage |
|--------|-------|
| L'utilisateur doit changer le mot de passe à la prochaine connexion | Nouveaux comptes |
| L'utilisateur ne peut pas changer le mot de passe | Comptes de service |
| Le mot de passe n'expire jamais | Comptes de service / technique |
| Le compte est désactivé | Pré-création, départs |

#### Via PowerShell

```powershell
New-ADUser `
  -Name              "Claire Fontaine" `
  -GivenName         "Claire" `
  -Surname           "Fontaine" `
  -SamAccountName    "cfontaine" `
  -UserPrincipalName "cfontaine@ad.fournil.lab" `
  -Path              "OU=Gerance,OU=Direction,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
  -AccountPassword   (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
  -ChangePasswordAtLogon $true `
  -Enabled           $true
```

- [New-ADUser — Microsoft Learn](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/new-aduser)

### Gérer les comptes utilisateurs

```powershell
# Lister les utilisateurs d'une OU
Get-ADUser -Filter * -SearchBase "OU=Production,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Modifier un attribut
Set-ADUser -Identity "mlebrun" -Title "Chef Boulanger" -Department "Production"

# Désactiver un compte (arrêt maladie)
Disable-ADAccount -Identity "mlebrun"

# Réinitialiser un mot de passe
Set-ADAccountPassword -Identity "jrenard" `
  -NewPassword (ConvertTo-SecureString "NouveauP@ss!" -AsPlainText -Force) -Reset

# Déverrouiller un compte
Unlock-ADAccount -Identity "jrenard"

# Supprimer un compte
Remove-ADUser -Identity "testuser" -Confirm:$false
```

### Créer plusieurs comptes en masse depuis un CSV

Fichier `utilisateurs-fournil.csv` :

```
Prenom,Nom,Pole,Service,Login,Email
Claire,Fontaine,Direction,Gerance,cfontaine,cfontaine@ad.fournil.lab
Marc,Lebrun,Production,Boulangerie,mlebrun,mlebrun@ad.fournil.lab
```

```powershell
Import-Csv "C:\utilisateurs-fournil.csv" | ForEach-Object {
    New-ADUser `
      -Name              "$($_.Prenom) $($_.Nom)" `
      -GivenName         $_.Prenom `
      -Surname           $_.Nom `
      -SamAccountName    $_.Login `
      -UserPrincipalName $_.Email `
      -Path              "OU=$($_.Service),OU=$($_.Pole),OU=Fournil,DC=ad,DC=fournil,DC=lab" `
      -AccountPassword   (ConvertTo-SecureString "Fournil2025!" -AsPlainText -Force) `
      -ChangePasswordAtLogon $true `
      -Enabled           $true
}
```

---

## 2. Les comptes ordinateurs

Quand un ordinateur rejoint le domaine, un **compte ordinateur** est créé dans AD. Ce compte permet :
- l'authentification Kerberos de la machine
- l'application des GPO ordinateur
- la gestion centralisée (inventaire, scripts, déploiement)

### Prérequis réseau

Avant toute jonction, le poste client doit **résoudre le nom du domaine via le DNS du DC**. Si le DNS pointe vers 8.8.8.8 ou un autre serveur externe, `ad.fournil.lab` sera introuvable et la jonction échouera.

| Paramètre | Valeur (lab Hyper-V) |
|-----------|---------------------|
| Adresse IP | `192.168.3.100` |
| Masque | `255.255.255.0` |
| Passerelle | `192.168.3.254` (carte hôte Hyper-V) |
| DNS préféré | `192.168.3.10` (DC01) |

Configuration via PowerShell depuis le client Windows 11 (en tant qu'administrateur local) :

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.3.100 -PrefixLength 24 -DefaultGateway 192.168.3.254
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.3.10
```

Vérification avant de joindre :

```powershell
# Le domaine doit se résoudre sur l'IP du DC
Resolve-DnsName ad.fournil.lab

# Le DC doit être joignable sur le port LDAP
Test-NetConnection 192.168.3.10 -Port 389
```

### Joindre un ordinateur au domaine

#### Via l'interface Windows 11 (GUI)

1. **Clic droit sur Démarrer → Système**
2. Cliquer sur **Renommer ce PC (Paramètres avancés)**
3. Onglet **Nom de l'ordinateur** → **Modifier**
4. Cocher **Domaine** → saisir `ad.fournil.lab`
5. S'authentifier avec le compte `Administrateur` du domaine
6. Redémarrer

Après le redémarrage, à l'écran de connexion, cliquer sur **Autre utilisateur** et saisir `FOURNIL\nomutilisateur`.

#### Via PowerShell

```powershell
Add-Computer -DomainName "ad.fournil.lab" `
             -Credential (Get-Credential) `
             -Restart
```

> [!NOTE] Droits de jonction
> Par défaut, tout utilisateur du domaine peut joindre jusqu'à **10 machines**. En production, on délègue ce droit à un groupe dédié ou on le limite via la GPO (attribut `ms-DS-MachineAccountQuota`).

> [!WARNING] Emplacement du compte ordinateur
> Par défaut, la machine atterrit dans le conteneur `CN=Computers`, pas dans les OUs personnalisées. Il faut soit la déplacer manuellement dans `dsa.msc`, soit pré-créer le compte dans la bonne OU avant la jonction.

### Pré-créer un compte ordinateur

```powershell
New-ADComputer -Name "PC-DIRECTION-01" `
               -Path "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab" `
               -Enabled $true
```

- [Comptes d'ordinateurs AD — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/understand-computer-accounts)

---

## 3. Les groupes

Les groupes Active Directory permettent d'accorder des permissions de manière centralisée. Ils sont composés de deux notions : le **type** et la **portée**.

- [Les différents types de groupe de l'Active Directory — IT-Connect](https://www.it-connect.fr/chapitres/les-differents-types-de-groupe-de-lactive-directory/)
- [Groupes de sécurité AD — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/understand-security-groups)

### Type de groupe

| Type | Usage |
|------|-------|
| **Sécurité** | Attribuer des permissions (partages, NTFS, imprimantes, applications) |
| **Distribution** | Listes de diffusion mail uniquement (Exchange) — non utilisé dans ce cours |

### Portée du groupe

| Portée | Peut contenir | Utilisation | Portée effective |
|--------|--------------|------------|-----------------|
| **Local domaine** | Users, Global, Universal | Droits sur les ressources | Domaine local |
| **Global** | Utilisateurs du domaine | Regrouper les utilisateurs par service | Tout le domaine |
| **Universel** | Users + Groupes globaux | Environnements multi-domaines | Toute la forêt |

> [!TIP] Règle simple pour une forêt à domaine unique
> En PME avec un seul domaine, l'essentiel est d'utiliser des groupes de **sécurité** et de respecter AGDLP. Les groupes universels concernent les grandes entreprises multi-domaines.

### Groupes prédéfinis importants

Il existe des **groupes prédéfinis** dans le conteneur `Users`, créés automatiquement par AD. L'administrateur peut ajouter ou retirer des membres, mais leur rôle ne doit pas être modifié.

| Groupe | Rôle |
|--------|------|
| **Domain Admins** | Administration complète du domaine |
| **Domain Users** | Tous les utilisateurs du domaine |
| **Domain Computers** | Tous les postes joints au domaine |

### Créer et gérer des groupes

#### Via GUI

Dans `dsa.msc` : clic droit sur l'OU → **Nouveau → Groupe** → choisir le type et la portée.

#### Via PowerShell

```powershell
# Groupe global de service (regroupe les utilisateurs)
New-ADGroup -Name "GG_Production" `
            -GroupScope Global `
            -GroupCategory Security `
            -Path "OU=GG,OU=Groupes,DC=ad,DC=fournil,DC=lab"

# Groupe domaine local (associé à une ressource)
New-ADGroup -Name "DL_Fournil_Production_RW" `
            -GroupScope DomainLocal `
            -GroupCategory Security `
            -Path "OU=DL,OU=Groupes,DC=ad,DC=fournil,DC=lab" `
            -Description "Lecture+écriture dossier Production"

# Ajouter des membres
Add-ADGroupMember -Identity "GG_Production" -Members "mlebrun","sdupont","kgarnier"

# Lister les membres
Get-ADGroupMember -Identity "GG_Production"

# Retirer un membre
Remove-ADGroupMember -Identity "GG_Production" -Members "sdupont" -Confirm:$false
```

- [New-ADGroup — Microsoft Learn](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/new-adgroup)

---

## 4. Le modèle AGDLP

AGDLP décrit la façon dont les objets sont imbriqués pour attribuer des permissions sur les ressources :

```
Accounts → Global groups → Domain Local groups → Permissions
```

| Sigle | Contient | Rôle |
|-------|----------|------|
| **A** — Account | Comptes utilisateurs | Qui a besoin d'accès |
| **G** — Global group | Comptes du même domaine | Regroupe les utilisateurs par service |
| **DL** — Domain Local | Groupes globaux | Associé à une ressource |
| **P** — Permission | Droits NTFS sur la ressource | Ce qu'on peut faire |

### Exemple concret — accès au dossier Production

Scénario : les boulangers doivent pouvoir lire et écrire dans `\\DC01\fournil\Production\Boulangerie`.

```
mlebrun, rdubois, lmartin  (A — comptes dans OU=Boulangerie)
    └── GG_Production_Boulangerie  (G — groupe global)
            └── DL_Fournil_Boulangerie_RW  (DL — groupe domaine local)
                    └── Modify sur \\DC01\fournil\Production\Boulangerie  (P — permission NTFS)
```

```powershell
# 1. Créer le groupe global (regroupe les boulangers)
New-ADGroup -Name "GG_Production_Boulangerie" -GroupScope Global -GroupCategory Security `
            -Path "OU=GG,OU=Groupes,DC=ad,DC=fournil,DC=lab"

# 2. Créer le groupe domaine local (associé au dossier)
New-ADGroup -Name "DL_Fournil_Boulangerie_RW" -GroupScope DomainLocal -GroupCategory Security `
            -Path "OU=DL,OU=Groupes,DC=ad,DC=fournil,DC=lab"

# 3. Ajouter les utilisateurs dans le groupe global
Add-ADGroupMember -Identity "GG_Production_Boulangerie" -Members "mlebrun","rdubois","lmartin"

# 4. Imbriquer le groupe global dans le groupe domaine local
Add-ADGroupMember -Identity "DL_Fournil_Boulangerie_RW" -Members "GG_Production_Boulangerie"

# 5. Appliquer la permission NTFS sur le dossier
$acl  = Get-Acl "C:\Partages\fournil\Production\Boulangerie"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "FOURNIL\DL_Fournil_Boulangerie_RW", "Modify",
    "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "C:\Partages\fournil\Production\Boulangerie" $acl
```

> [!NOTE] Pourquoi cette complexité ?
> Sans AGDLP, si un boulanger change de service, il faut modifier les permissions sur chaque dossier manuellement. Avec AGDLP, on le retire du groupe global `GG_Production_Boulangerie` et ses accès disparaissent automatiquement sur toutes les ressources associées.

- [Defining a Security Group Nesting Policy — Microsoft Learn](https://learn.microsoft.com/fr-fr/previous-versions/windows/it-pro/windows-server-2003/cc783634(v=ws.10))

---

> [!NOTE] À retenir
>
> - Les **OUs** organisent les objets ; les **groupes** centralisent les permissions.
> - Trois portées de groupes : **Local domaine** (ressources), **Global** (utilisateurs par service), **Universel** (multi-domaines).
> - Le **Distinguished Name (DN)** identifie précisément chaque objet AD — indispensable en PowerShell.
> - Avec AGDLP, un changement de service = un changement de groupe, toutes les permissions suivent.
> - PowerShell (`New-ADUser`, `New-ADGroup`, `Import-Csv`) permet d'automatiser toute la gestion de l'annuaire.

---

## Résumé commandes

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Créer un utilisateur | `dsa.msc` → Nouveau → Utilisateur | `New-ADUser` |
| Désactiver un compte | Clic droit → Désactiver | `Disable-ADAccount` |
| Réinitialiser mot de passe | Clic droit → Réinitialiser | `Set-ADAccountPassword` |
| Import en masse | — | `Import-Csv` + `New-ADUser` |
| Joindre un PC | Paramètres Système | `Add-Computer` |
| Créer un groupe | `dsa.msc` → Nouveau → Groupe | `New-ADGroup` |
| Gérer les membres | Propriétés → Membres | `Add-ADGroupMember` |
