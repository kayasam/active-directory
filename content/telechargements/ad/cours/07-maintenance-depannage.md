# 07 — Maintenance et dépannage

> **Objectif** : Sauvegarder et restaurer Active Directory, diagnostiquer l'état d'un contrôleur de domaine, connaître les rôles FSMO et les outils de surveillance.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01`

**Outils abordés :** Windows Server Backup, `wbadmin`, `dcdiag`, `netdiag`, `repadmin`, Observateur d'événements
**Concepts clés :** sauvegarde état du système, restauration non-autoritaire, FSMO, réplication AD

---

## 1. Pourquoi sauvegarder AD ?

Active Directory est la colonne vertébrale du réseau Windows. Sa perte ou sa corruption entraîne :
- impossibilité de se connecter sur les postes du domaine
- perte des GPO, des comptes, des groupes
- interruption de tous les services qui s'appuient sur l'authentification

> [!WARNING] Sauvegarder l'état du système, pas seulement les fichiers
> La base AD (`NTDS.dit`) ne peut pas être copiée à chaud. Il faut sauvegarder l'**état du système** (System State), qui inclut la base AD, SYSVOL, le registre et les fichiers de démarrage.

**Référence Microsoft :** [Sauvegarde et récupération AD DS](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/ad-ds-simplified-administration)

---

## 2. Sauvegarder l'état du système

### Prérequis : installer Windows Server Backup

```powershell
Install-WindowsFeature -Name Windows-Server-Backup
```

### Via l'interface graphique

1. Ouvrir **Windows Server Backup** (`wbadmin.msc`)
2. **Planification de sauvegarde** ou **Sauvegarde unique**
3. Type de configuration : **Personnalisé**
4. Ajouter les éléments : **État du système**
5. Choisir la destination (volume local dédié ou partage réseau)
6. Lancer la sauvegarde

### Via PowerShell / wbadmin

```powershell
# Sauvegarde de l'état du système vers un volume local
wbadmin start systemstatebackup -backuptarget:E: -quiet

# Lister les sauvegardes disponibles
wbadmin get versions

# Voir le détail d'une sauvegarde
wbadmin get items -version:01/01/2025-02:00
```

> [!TIP] Fréquence recommandée
> Sauvegarder l'état du système **quotidiennement**, idéalement avant minuit. Conserver au moins 7 jours de rétention.

**Référence Microsoft :** [wbadmin start systemstatebackup](https://learn.microsoft.com/fr-fr/windows-server/administration/windows-commands/wbadmin-start-systemstatebackup)

---

## 3. Restaurer Active Directory

Il existe deux modes de restauration :

| Mode | Usage | Effet sur la réplication |
|------|-------|------------------------|
| **Non autoritaire** | Restaurer un DC après panne matérielle | Les données sont répliquées depuis les autres DC |
| **Autoritaire** | Restaurer des objets supprimés accidentellement | Force les autres DC à accepter les données restaurées |

### Restauration non autoritaire (cas courant)

1. Redémarrer le DC en **Mode de restauration des services d'annuaire (DSRM)**
   - Au démarrage : F8 → Mode de restauration des services d'annuaire
   - Ou via PowerShell avant redémarrage :
   ```powershell
   bcdedit /set safeboot dsrepair
   Restart-Computer
   ```
2. Se connecter avec le **mot de passe DSRM** (défini lors de la promotion)
3. Lancer la restauration :
   ```powershell
   wbadmin start systemstaterecovery -version:01/01/2025-02:00 -quiet
   ```
4. Redémarrer normalement :
   ```powershell
   bcdedit /deletevalue safeboot
   Restart-Computer
   ```
5. AD se synchronise automatiquement avec les autres DC s'il en existe

**Référence Microsoft :** [Restaurer un contrôleur de domaine](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/ad-forest-recovery-restore-the-first-writeable-dc)

---

## 4. Diagnostiquer avec dcdiag

`dcdiag` est l'outil de référence pour diagnostiquer l'état d'un contrôleur de domaine.

```powershell
# Diagnostic complet
dcdiag /v

# Test DNS uniquement
dcdiag /test:dns /v

# Tests essentiels
dcdiag /test:replications    # état de la réplication
dcdiag /test:netlogons       # service NETLOGON
dcdiag /test:services        # services AD essentiels
dcdiag /test:fsmocheck       # titulaires des rôles FSMO
dcdiag /test:sysvol          # partage SYSVOL
```

Sortie type d'un test réussi :
```
Starting test: Replications
   * Replications Check
   ......................... DC01 passed test Replications
```

> [!TIP] En cas d'échec
> `dcdiag` indique le test en échec et une description de l'erreur. Chercher le code d'erreur dans la documentation Microsoft ou les journaux de l'Observateur d'événements.

**Référence Microsoft :** [Dcdiag](https://learn.microsoft.com/fr-fr/windows-server/administration/windows-commands/dcdiag)

---

## 5. Surveiller la réplication

Dans un environnement avec plusieurs DC, la **réplication** synchronise les modifications entre eux. Un problème de réplication peut entraîner des incohérences (mot de passe modifié sur un DC mais pas sur l'autre).

```powershell
# Afficher l'état de la réplication
repadmin /showrepl

# Forcer la réplication immédiate
repadmin /syncall /AdeP

# Résumé de la réplication (plus lisible)
repadmin /replsummary
```

**Référence Microsoft :** [Repadmin](https://learn.microsoft.com/fr-fr/windows-server/administration/windows-commands/repadmin)

---

## 6. Les rôles FSMO

Dans un domaine AD, certaines opérations ne peuvent être effectuées que par **un seul DC** à la fois. Ces rôles exclusifs s'appellent **FSMO** (Flexible Single Master Operations).

> [!TIP] Illustration des rôles FSMO
> Pour un schéma visuel des 5 rôles et leur portée (forêt vs domaine) : [Understand FSMO roles — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/understand-fsmo-roles)
> Explication détaillée de chaque rôle : [FSMO roles explained — Microsoft Learn](https://learn.microsoft.com/fr-fr/archive/technet-wiki/28967.active-directory-flexible-single-master-operation-fsmo-roles-explained)

### Les 5 rôles FSMO

| Rôle | Portée | Rôle |
|------|--------|------|
| **Schema Master** | Forêt | Modifie le schéma AD |
| **Domain Naming Master** | Forêt | Ajoute/supprime des domaines dans la forêt |
| **PDC Emulator** | Domaine | Synchronisation du temps, verrouillages, GPO |
| **RID Master** | Domaine | Distribue les pools de RID aux DC |
| **Infrastructure Master** | Domaine | Gère les références inter-domaines |

> [!NOTE] Pour un TSSR en PME
> Avec un seul DC, tous les rôles FSMO sont sur ce DC. Avec deux DC, c'est une bonne pratique de répartir les rôles. En pratique, un technicien TSSR n'a généralement pas à transférer ces rôles — c'est une opération rare.

### Identifier les titulaires des rôles FSMO

```powershell
# Via AD PowerShell
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster

# Via netdom
netdom query fsmo
```

**Référence Microsoft :** [Rôles FSMO](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/planning-operations-master-role-placement)

---

## 7. Journaux et surveillance

### Journaux essentiels à surveiller

| Journal | Emplacement dans l'Observateur | Contenu |
|---------|-------------------------------|---------|
| **Directory Service** | Journaux des applications et services Windows | Erreurs AD DS, réplication |
| **DNS Server** | Journaux des applications et services Windows | Erreurs DNS |
| **Security** | Journaux Windows | Authentifications, audits |
| **System** | Journaux Windows | Erreurs système, services |

```powershell
# Dernières erreurs du journal Directory Service
Get-WinEvent -LogName "Directory Service" -MaxEvents 20 |
  Where-Object { $_.LevelDisplayName -eq "Erreur" }

# Événements de réplication AD (ID 1566 = erreur réplication)
Get-WinEvent -FilterHashtable @{LogName='Directory Service'; Level=2} -MaxEvents 10
```

---

## Résumé

| Action | Commande / Outil |
|--------|-----------------|
| Installer Windows Server Backup | `Install-WindowsFeature Windows-Server-Backup` |
| Sauvegarder l'état du système | `wbadmin start systemstatebackup` |
| Lister les sauvegardes | `wbadmin get versions` |
| Diagnostic complet DC | `dcdiag /v` |
| État de la réplication | `repadmin /showrepl` |
| Titulaires FSMO | `netdom query fsmo` |
| Démarrer en mode DSRM | `bcdedit /set safeboot dsrepair` |
