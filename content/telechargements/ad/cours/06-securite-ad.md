# 06. Sécurité Active Directory

> **Objectif** : Configurer la stratégie de mot de passe du domaine, analyser les bonnes pratiques avec le BPA, appliquer le principe de moindre privilège et sécuriser les comptes privilégiés.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01`

**Outils abordés :** `gpmc.msc`, `dsa.msc`, `dsac.exe`, Gestionnaire de serveur (BPA)
**Concepts clés :** stratégie de mot de passe, verrouillage de compte, Best Practices Analyzer, moindre privilège, comptes de service

---

## 1. La stratégie de mot de passe du domaine

La stratégie de mot de passe s'applique à **tous les comptes du domaine**. Elle est définie dans la **Default Domain Policy**.

### Paramètres disponibles

| Paramètre | Description | Valeur recommandée |
|-----------|-------------|-------------------|
| Longueur minimale | Nombre de caractères minimum | 12 caractères |
| Complexité | Majuscule + minuscule + chiffre + symbole | Activée |
| Durée de vie maximale | Nombre de jours avant expiration | 90 jours (ou désactivée avec MFA) |
| Durée de vie minimale | Empêche le changement immédiat | 1 jour |
| Historique | Nombre d'anciens mots de passe mémorisés | 24 |

> [!NOTE] Tendance 2024-2025
> Le NIST et l'ANSSI recommandent désormais de **ne plus forcer l'expiration régulière** si les mots de passe sont longs et forts, et si une détection de compromission est en place. L'expiration forcée pousse souvent les utilisateurs à choisir des mots de passe prévisibles (`Janvier2024!`, `Janvier2025!`).

**Référence Microsoft :** [Stratégies de mot de passe AD](https://learn.microsoft.com/fr-fr/windows-server/security/kerberos/passwords-technical-overview)

### Configurer via la Default Domain Policy

1. Ouvrir `gpmc.msc`
2. Clic droit sur **Default Domain Policy** → Modifier
3. `Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies de compte → Stratégie de mot de passe`

### Via PowerShell

```powershell
# Afficher la stratégie actuelle
Get-ADDefaultDomainPasswordPolicy

# Modifier la stratégie
Set-ADDefaultDomainPasswordPolicy `
  -Identity "ad.fournil.lab" `
  -MinPasswordLength 12 `
  -ComplexityEnabled $true `
  -MaxPasswordAge (New-TimeSpan -Days 90) `
  -MinPasswordAge (New-TimeSpan -Days 1) `
  -PasswordHistoryCount 24 `
  -LockoutThreshold 5 `
  -LockoutDuration (New-TimeSpan -Minutes 30) `
  -LockoutObservationWindow (New-TimeSpan -Minutes 30)
```

**Référence Microsoft :** [Set-ADDefaultDomainPasswordPolicy](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/set-addefaultdomainpasswordpolicy)

---

## 2. Verrouillage de compte

Quand un utilisateur dépasse le nombre de tentatives autorisées, son compte est verrouillé.

| Paramètre | Description |
|-----------|-------------|
| **Seuil de verrouillage** | Nombre de tentatives avant blocage |
| **Durée de verrouillage** | Temps avant déblocage automatique (0 = manuel) |
| **Fenêtre d'observation** | Délai de réinitialisation du compteur |

### Déverrouiller un compte

```powershell
# Voir les comptes verrouillés
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LockedOut

# Déverrouiller un compte
Unlock-ADAccount -Identity "amartin"

# Déverrouiller tous les comptes verrouillés
Search-ADAccount -LockedOut | Unlock-ADAccount
```

### Retrouver d'où vient le verrouillage

Avant de déverrouiller, on cherche **la source** : un téléphone ou un script avec un ancien mot de passe va reverrouiller le compte aussitôt. Le DC enregistre l'événement **4740** dans le journal *Sécurité* :

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 1 | Format-List TimeCreated, Message
```

![ad-tp06-evenement-4740](https://cours.kaya.ovh/active-directory/assets/supports/e48090a5bd8f9b154a88.png)
*Le champ **Caller Computer Name** donne le poste d'où viennent les mauvais mots de passe (ici `PC-PROD-01`).*

**Référence Microsoft :** [Stratégie de verrouillage de compte](https://learn.microsoft.com/fr-fr/windows-server/security/kerberos/account-lockout-policy)

---

## 3. Best Practices Analyzer (BPA) — Scanner les bonnes pratiques

Le **Best Practices Analyzer** est un outil intégré au Gestionnaire de serveur qui analyse la configuration de vos rôles et détecte les problèmes de sécurité ou de configuration. Il compare votre serveur aux **recommandations officielles de Microsoft** et remonte 3 niveaux de résultats :

| Niveau | Signification |
|--------|--------------|
| **Erreur** | Problème de sécurité ou de configuration à corriger rapidement |
| **Avertissement** | Point d'attention qui peut poser problème |
| **Information** | Vérification réussie, tout est conforme |

### Via le Gestionnaire de serveur (GUI)

1. Ouvrir le **Gestionnaire de serveur**
2. Cliquer sur le rôle à analyser (ex : **AD DS**)
3. Dans la section **Best Practices Analyzer**, cliquer sur **Tâches** → **Commencer l'analyse BPA**
4. Attendre la fin du scan puis consulter les résultats

### Via PowerShell

Les cmdlets BPA ne fonctionnent qu'en **Windows PowerShell 5.1** (pas PowerShell 7). Utiliser `powershell.exe` :

```powershell
# Lister tous les modèles BPA disponibles sur le serveur
powershell.exe -Command "Get-BpaModel | Select-Object Id, Name | Format-Table -AutoSize"
```

Modèles BPA les plus utiles :

| Modèle | Id |
|--------|-----|
| **Active Directory** | `Microsoft/Windows/DirectoryServices` |
| **DNS** | `Microsoft/Windows/DNSServer` |
| **DHCP** | `Microsoft/Windows/DHCPServer` |
| **Serveur de fichiers** | `Microsoft/Windows/FileServices` |
| **Hyper-V** | `Microsoft/Windows/Hyper-V` |

```powershell
# Lancer un scan BPA sur Active Directory
powershell.exe -Command "Invoke-BpaModel -ModelId 'Microsoft/Windows/DirectoryServices'"

# Afficher les résultats
powershell.exe -Command "Get-BpaResult -ModelId 'Microsoft/Windows/DirectoryServices' | Select-Object Severity, Category, Title, Problem | Format-List"
```

### Filtrer les résultats par gravité

Pour ne voir que les erreurs et avertissements (les points à corriger) :

```powershell
# Afficher uniquement les erreurs et avertissements
powershell.exe -Command "Get-BpaResult -ModelId 'Microsoft/Windows/DirectoryServices' | Where-Object { \`$_.Severity -in 'Erreur','Avertissement' } | Select-Object Severity, Title, Problem | Format-List"
```

### Exemple de résultats sur notre lab

Voici ce que le BPA remonte sur notre DC `DC01` :

| Niveau | Problème détecté |
|--------|-----------------|
| **Erreur** | L'émulateur PDC n'est pas configuré pour synchroniser l'heure depuis une source de temps valide |
| **Avertissement** | Certaines OU ne sont pas protégées contre la suppression accidentelle |
| **Avertissement** | Le DC s'exécute sur une machine virtuelle (recommandations spécifiques à suivre) |

> [!TIP] Quand lancer un scan BPA ?
> - Après l'installation d'un nouveau rôle
> - Après des modifications importantes de configuration
> - Régulièrement dans le cadre de la maintenance (ex : une fois par mois)

---

## 4. Surveiller les dernières connexions des utilisateurs

Connaître la date de dernière connexion de chaque utilisateur permet de détecter les comptes inactifs (risque de sécurité) et de vérifier l'activité réelle.

### `LastLogonDate` vs `LastLogon` : une distinction importante

Active Directory propose **deux propriétés** pour la dernière connexion, et elles ne fonctionnent pas de la même manière :

| Propriété | Répliquée entre DC ? | Précision | Usage |
|-----------|---------------------|-----------|-------|
| `LastLogonDate` (alias de `LastLogonTimestamp`) | **Oui** | Mise à jour uniquement si la valeur précédente date de **plus de ~14 jours** | Détecter les comptes inactifs depuis longtemps |
| `LastLogon` | **Non** (propre à chaque DC) | Mise à jour à **chaque connexion** | Connaître la date exacte de dernière connexion |

> [!WARNING] Piège courant
> `LastLogonDate` n'est **pas mise à jour à chaque connexion**. C'est un choix de Microsoft pour limiter le trafic de réplication entre contrôleurs de domaine. Si un utilisateur s'est connecté il y a 3 jours, la valeur affichée peut toujours dater de 2 semaines. Ne vous fiez pas à cette propriété pour un suivi précis des connexions récentes.

### Méthode simple — `LastLogonDate` (suffisant pour détecter les comptes inactifs)

```powershell
Get-ADUser -Filter * -Properties LastLogonDate |
    Select-Object Name, SamAccountName, LastLogonDate |
    Sort-Object LastLogonDate -Descending
```

### Méthode précise — `LastLogon` (date exacte de dernière connexion)

Puisque `LastLogon` n'est pas répliqué, chaque DC a sa propre valeur. Avec **un seul DC** (comme dans notre lab) :

```powershell
Get-ADUser -Filter * -Properties LastLogon |
    Select-Object Name, SamAccountName,
        @{N='DerniereConnexion'; E={[DateTime]::FromFileTime($_.LastLogon)}} |
    Sort-Object DerniereConnexion -Descending
```

En **environnement multi-DC** (production), il faut interroger chaque DC et garder la date la plus récente :

```powershell
$users = @{}
$dcs = Get-ADDomainController -Filter *

foreach ($dc in $dcs) {
    Get-ADUser -Filter * -Properties LastLogon -Server $dc.HostName | ForEach-Object {
        $logon = [DateTime]::FromFileTime($_.LastLogon)
        if (-not $users[$_.SamAccountName] -or $logon -gt $users[$_.SamAccountName].DerniereConnexion) {
            $users[$_.SamAccountName] = [PSCustomObject]@{
                Name              = $_.Name
                SamAccountName    = $_.SamAccountName
                DerniereConnexion = $logon
            }
        }
    }
}

$users.Values | Sort-Object DerniereConnexion -Descending | Format-Table -AutoSize
```

### Trouver les comptes inactifs depuis plus de 90 jours

```powershell
$limite = (Get-Date).AddDays(-90)
Search-ADAccount -AccountInactive -DateTime $limite -UsersOnly |
    Select-Object Name, SamAccountName, LastLogonDate
```

**Référence Microsoft :** [Search-ADAccount](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/search-adaccount)

---

## 5. Principe de moindre privilège

> [!TIP] liens microsoft
> Pour un guide complet sur les modèles d'administration à moindre privilège dans AD : [Implementing Least-Privilege Administrative Models — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/security-best-practices/implementing-least-privilege-administrative-models)

> [!WARNING] Le compte Administrateur du domaine ne doit pas servir au quotidien
> `Domain Admins` est le compte le plus puissant du domaine. L'utiliser pour des tâches courantes augmente considérablement la surface d'attaque. En cas de compromission, c'est tout le domaine qui tombe.

### Règles de base

1. **Compte admin séparé du compte quotidien** — `t.bernard` pour le travail courant, `adm.tbernard` pour l'administration
2. **Déléguer plutôt qu'élever** — utiliser la délégation AD (TP 02) pour les tâches répétitives
3. **Groupes d'administration spécialisés** — ne pas tout mettre dans `Domain Admins`

> [!TIP] Aller plus loin : le tiering
> Ces règles sont la première marche du **cloisonnement par niveaux** (Tier 0 / 1 / 2) : un compte d'administration par niveau, et des GPO qui l'empêchent de se connecter sur une machine moins protégée. C'est l'objet du [chapitre 08](https://cours.kaya.ovh/active-directory/ad/08-tiering/).

### Groupes privilégiés intégrés à connaître

| Groupe | Droits | Règle |
|--------|--------|-------|
| **Domain Admins** | Contrôle total du domaine | Membres = 2-3 personnes max |
| **Administrators** | Admin local sur tous les DC | Idem |
| **Account Operators** | Gérer les comptes (pas les admins) | Délégation helpdesk |
| **Backup Operators** | Sauvegarder/restaurer les fichiers | Comptes de sauvegarde dédiés |
| **Server Operators** | Gérer les services sur les DC | À éviter si possible |

```powershell
# Lister les membres de Domain Admins
Get-ADGroupMember -Identity "Domain Admins" | Select-Object Name, SamAccountName

# Lister tous les membres de tous les groupes privilégiés
$groups = "Domain Admins","Administrators","Account Operators","Backup Operators"
foreach ($g in $groups) {
    Write-Host "=== $g ===" -ForegroundColor Cyan
    Get-ADGroupMember -Identity $g | Select-Object Name, SamAccountName
}
```

**Référence Microsoft :** [Groupes de sécurité AD par défaut](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/understand-security-groups#default-active-directory-security-groups)

---

## 6. Comptes de service

Un compte de service est un compte utilisateur utilisé par une application ou un service Windows pour s'authentifier sur le réseau.

### Bonnes pratiques

- Créer un compte dédié par service (`svc_sql`, `svc_backup`)
- Placer ces comptes dans une OU dédiée (`OU=Services`)
- Cocher **"Le mot de passe n'expire jamais"** (et le documenter)
- Cocher **"L'utilisateur ne peut pas changer le mot de passe"**
- Attribuer uniquement les droits nécessaires (moindre privilège)

```powershell
New-ADUser `
  -Name "svc_backup" `
  -SamAccountName "svc_backup" `
  -UserPrincipalName "svc_backup@ad.fournil.lab" `
  -Path "OU=Services,DC=ad,DC=fournil,DC=lab" `
  -AccountPassword (ConvertTo-SecureString "Svc!Backup2025#" -AsPlainText -Force) `
  -PasswordNeverExpires $true `
  -CannotChangePassword $true `
  -Enabled $true
```

---

## Résumé

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Stratégie de mot de passe | Default Domain Policy → GPMC | `Set-ADDefaultDomainPasswordPolicy` |
| Voir comptes verrouillés | `dsa.msc` (filtre avancé) | `Search-ADAccount -LockedOut` |
| Déverrouiller un compte | Clic droit → Déverrouiller | `Unlock-ADAccount` |
| Scanner les bonnes pratiques | Gestionnaire de serveur → BPA | `Invoke-BpaModel` / `Get-BpaResult` |
| Dernière connexion (approx.) | — | `Get-ADUser` + `LastLogonDate` |
| Dernière connexion (exacte) | — | `Get-ADUser` + `LastLogon` |
| Comptes inactifs | — | `Search-ADAccount -AccountInactive` |
| Membres de Domain Admins | `dsa.msc` | `Get-ADGroupMember` |
