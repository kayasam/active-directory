---
title: "TP 07 — Maintenance et dépannage — Correction"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/07-maintenance-depannage"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/07-maintenance-depannage-corrigev2.md">↓ Télécharger le corrigé (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>
<nav class="exercise-resources" aria-label="Ressources du TP"><a href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/tp">Énoncé</a><a class="exercise-correction" href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/tp-corrigev2" aria-current="page">Corrigé</a></nav>

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h30

> Chapitres associés : [07. Maintenance et dépannage](https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/)

---

## Objectifs

- Installer Windows Server Backup et sauvegarder l'état du système
- Diagnostiquer l'état du DC avec `dcdiag`
- Identifier les titulaires des rôles FSMO
- Lire les journaux AD et identifier des erreurs

---

## Partie A — Sauvegarde de l'état du système (30 min)

**A1.** Installe la fonctionnalité Windows Server Backup si elle n'est pas présente :
```powershell
Get-WindowsFeature -Name Windows-Server-Backup
Install-WindowsFeature -Name Windows-Server-Backup
```

> [!success]- Afficher la correction — A1
> ```powershell
> Get-WindowsFeature -Name Windows-Server-Backup
> # Si InstallState = Available :
> Install-WindowsFeature -Name Windows-Server-Backup
> ```

**A2.** Prépare une **cible de sauvegarde dédiée** : `wbadmin` refuse un dossier, et refuse aussi un volume inclus dans la sauvegarde (comme `C:`).
- Ajoute à la VM DC01 un **second disque virtuel** de 40 Go (Hyper-V : *Paramètres → Contrôleur SCSI → Disque dur → Ajouter*, ou sur l'hôte `Add-VMHardDiskDrive`) ;
- dans DC01, initialise-le et formate-le en `E:` :
```powershell
Get-Disk | Where-Object PartitionStyle -eq 'RAW'
Initialize-Disk -Number 1 -PartitionStyle GPT
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E |
  Format-Volume -FileSystem NTFS -NewFileSystemLabel Sauvegardes
```

> [!WARNING] En production
> On ne sauvegarde jamais sur le même disque que le système : volume dédié, ou partage réseau (`-backuptarget:\\serveur\partage`).

> [!success]- Afficher la correction — A2
> Sur l'hôte Hyper-V :
> ```powershell
> New-VHD -Path D:\HyperV\DC01-sauvegarde.vhdx -SizeBytes 40GB -Dynamic
> Add-VMHardDiskDrive -VMName DC01 -Path D:\HyperV\DC01-sauvegarde.vhdx
> ```
> Dans DC01 :
> ```powershell
> $d = Get-Disk | Where-Object PartitionStyle -eq 'RAW'
> Initialize-Disk -Number $d.Number -PartitionStyle GPT
> New-Partition -DiskNumber $d.Number -UseMaximumSize -DriveLetter E |
>   Format-Volume -FileSystem NTFS -NewFileSystemLabel Sauvegardes
> ```

**A3.** Lance une sauvegarde de l'état du système via `wbadmin` :
```powershell
wbadmin start systemstatebackup -backuptarget:E: -quiet
```
Combien de temps prend l'opération ? Quelle taille fait la sauvegarde ?

*Pour comprendre la contrainte, essaie aussi `-backuptarget:C:\Sauvegardes` puis `-backuptarget:C:`. Quels messages obtiens-tu ?*

> [!success]- Afficher la correction — A3
> ```powershell
> wbadmin start systemstatebackup -backuptarget:E: -quiet
> ```
> Fin de sortie attendue :
> ```
> The backup operation successfully completed.
> The backup of the system state successfully completed [10/30/2026 12:13 PM].
> ```
> Durée constatée : **environ 35 minutes** sur un DC tout neuf (WS2025, disque virtuel dynamique). Prévoir de lancer la sauvegarde **avant la pause** et d'enchaîner sur la partie B pendant qu'elle tourne. Taille typique : **plusieurs Go** (NTDS.dit, SYSVOL, registre, fichiers de démarrage, partitions EFI et WinRE).
>
> Les deux essais « pour comprendre » échouent :
>
> | Cible | Message |
> |---|---|
> | `-backuptarget:C:\Sauvegardes\AD` | `ERROR - The specified backup location could not be found or is not a supported backup storage location.` La cible doit être un **volume** ou un **partage UNC**, pas un dossier. |
> | `-backuptarget:C:` | `The backup storage location is invalid. You cannot use a volume that is included in the backup as a storage location.` `C:` fait partie de l'état du système. |
>
> > Contournement possible (registre `AllowSSBToAnyVolume`), mais **à éviter** : une sauvegarde sur le disque qu'elle protège ne sert à rien en cas de panne disque.

**A4.** Liste les sauvegardes disponibles :
```powershell
wbadmin get versions
```
Note l'**identifiant de version** (format `JJ/MM/AAAA-HH:MM`) — il sera nécessaire pour une restauration.

> [!success]- Afficher la correction — A4
> ```powershell
> wbadmin get versions
> ```
> Sortie attendue :
> ```
> Backup time: 10/30/2026 11:37 AM
> Backup target: Fixed Disk labeled E:
> Version identifier: 10/30/2026-11:37
> Can recover: Volume(s), File(s), Application(s), System State
> ```
> L'identifiant de version est utilisé comme paramètre `-version` lors d'une restauration.

**A5.** Quelle est la différence entre une sauvegarde de l'état du système et une sauvegarde complète du serveur ?

> [!success]- Afficher la correction — A5
> | | Sauvegarde état du système | Sauvegarde complète |
> |-|--------------------------|---------------------|
> | Contenu | NTDS.dit, SYSVOL, registre, boot | Tout le volume (OS + données + état système) |
> | Taille | 3-8 Go | Plusieurs dizaines de Go |
> | Restauration | DSRM requis pour AD | Restauration bare-metal possible |
> | Usage | Récupération AD ciblée | Reconstruction complète du serveur |
>
> En production, on fait les deux : la sauvegarde d'état du système quotidiennement pour AD, et une sauvegarde complète hebdomadaire.

## Partie B — Diagnostic avec dcdiag (25 min)

**B1.** Lance le diagnostic complet du DC :
```powershell
dcdiag /v 2>&1 | Out-File C:\dcdiag_complet.txt
notepad C:\dcdiag_complet.txt
```
Combien de tests sont effectués ? Tous passent-ils ?

> [!success]- Afficher la correction — B1
> `dcdiag /v` effectue une vingtaine de tests. Les tests les plus importants : `Replications`, `NCSecDesc`, `NetLogons`, `Services`, `DNS`.
>
> Résultat attendu sur un DC neuf et sain : **26 tests `passed`** et 2 échecs :
> ```
> ......................... DC01 failed test DFSREvent
> ......................... DC01 failed test SystemLog
> ```
> Ces deux tests ne vérifient pas l'état actuel. Ils signalent qu'il existe des **avertissements ou erreurs dans les journaux des dernières 24 h** (DFSR au moment de l'initialisation de SYSVOL, redémarrages de la promotion…). Sur un lab tout juste monté, c'est **normal**. Le bon réflexe est de lire les événements cités (`dcdiag /test:DFSREvent /v`) avant de conclure, et non de « réparer » à l'aveugle.

**B2.** Lance le test DNS spécifiquement :
```powershell
dcdiag /test:dns /v
```
Quels sous-tests DNS sont effectués ? Y a-t-il des avertissements ?

> [!success]- Afficher la correction — B2
> Sous-tests DNS effectués par `dcdiag /test:dns /v` :
> - `CheckDynamicRegistration` — les enregistrements SRV sont-ils présents ?
> - `CheckForwarders` — les redirecteurs DNS sont-ils configurés ?
> - `CheckDelegation` — la délégation DNS est-elle en place ? (avertissement normal en lab)
> - `CheckRecordRegistration` — les enregistrements A du DC sont-ils corrects ?
>
> L'avertissement `DNS delegation` est attendu en lab (pas de DNS parent configuré).

**B3.** Lance le test de réplication :
```powershell
dcdiag /test:replications
```
Avec un seul DC, quel est le résultat attendu ?

> [!success]- Afficher la correction — B3
> ```
> Starting test: Replications
>    * Replications Check
>    ......................... DC01 passed test Replications
> ```
> Avec un seul DC, il n'y a rien à répliquer. Le test passe donc sans erreur.

**B4.** Vérifie l'état du service NETLOGON et du partage SYSVOL :
```powershell
dcdiag /test:netlogons
dcdiag /test:sysvol
```
Que contient le partage SYSVOL et pourquoi est-il important ?

> [!success]- Afficher la correction — B4
> ```
> Starting test: NetLogons
>    * Network Logons Privileges Check
>    ......................... DC01 passed test NetLogons
> ```
> Le partage **SYSVOL** (`\\ad.fournil.lab\SYSVOL`) contient :
> - Les **scripts de connexion** des utilisateurs
> - Les **fichiers de modèles de GPO** (ADMX/ADML)
> - Les **modèles GPO** (GPC — Group Policy Container) sont dans AD, les **GPT** (Group Policy Template) sont dans SYSVOL
>
> SYSVOL est répliqué entre DC via DFSR (DFS Replication). Son indisponibilité empêche l'application des GPO.

## Partie C — Rôles FSMO (15 min)

**C1.** Identifie les titulaires des 5 rôles FSMO de ton domaine :
```powershell
netdom query fsmo
```

> [!success]- Afficher la correction — C1
> ```
> netdom query fsmo
> ```
> Exemple de sortie :
> ```
> Maître de schéma                           DC01.ad.fournil.lab
> Maître d'attribution des noms de domaine   DC01.ad.fournil.lab
> PDC                                        DC01.ad.fournil.lab
> Maître RID                                 DC01.ad.fournil.lab
> Maître d'infrastructure                    DC01.ad.fournil.lab
> ```
> Avec un seul DC, tous les rôles sont sur `DC01`.

**C2.** Récupère les mêmes informations via PowerShell AD :
```powershell
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
```

> [!success]- Afficher la correction — C2
> ```powershell
> Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
> Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
> ```

**C3.** Explique le rôle du **PDC Emulator** dans le contexte de la gestion des mots de passe et des verrouillages de compte.

> [!success]- Afficher la correction — C3
> Le **PDC Emulator** joue un rôle central dans la gestion des mots de passe :
> - Quand un mot de passe est modifié, la modification est immédiatement répliquée sur le PDC Emulator (avant les autres DC)
> - Quand un DC reçoit un échec d'authentification, il vérifie d'abord sur le PDC Emulator si le mot de passe a été changé récemment
> - Les **verrouillages de compte** sont centralisés sur le PDC Emulator (il reçoit les notifications de tous les DC)
> - La **synchronisation de l'heure** est gérée par le PDC Emulator (référence de temps du domaine)

**C4.** Dans un environnement avec 2 DC, sur quel DC placerait-on le rôle PDC Emulator de préférence ? Pourquoi ?

> [!success]- Afficher la correction — C4
> En environnement bi-DC, le PDC Emulator doit être placé sur le **DC le plus puissant et le plus disponible**, car il traite plus de requêtes que les autres rôles. Il doit aussi être le DC le mieux connecté au réseau si les postes clients sont sur plusieurs sites.

## Partie D — Journaux et surveillance (20 min)

**D1.** Dans l'Observateur d'événements, ouvre le journal **Directory Service** :
`Observateur d'événements → Journaux des applications et services → Directory Service`

Filtre sur les événements de niveau **Erreur** et **Avertissement**. Y en a-t-il ?

> [!success]- Afficher la correction — D1
> Sur un DC fraîchement installé, quelques avertissements peuvent apparaître :
> - **Avertissement 1566** : première réplication (normal après installation)
> - **Avertissement sur DFSR** : SYSVOL en cours de migration (disparaît après stabilisation)
>
> Des erreurs répétées avec les IDs **1083, 1566, 1925** indiquent des problèmes de réplication à investiguer.

**D2.** Via PowerShell, affiche les 10 derniers événements du journal Directory Service :
```powershell
Get-WinEvent -LogName "Directory Service" -MaxEvents 10 |
  Select-Object TimeCreated, LevelDisplayName, Id, Message
```

> [!success]- Afficher la correction — D2
> ```powershell
> Get-WinEvent -LogName "Directory Service" -MaxEvents 10 |
>   Select-Object TimeCreated, LevelDisplayName, Id, Message | Format-List
> ```

**D3.** Cherche l'événement **ID 1000** dans le journal Directory Service. Que signifie-t-il ? Combien en trouves-tu, et pourquoi ce nombre ?

> [!success]- Afficher la correction — D3
> ```powershell
> Get-WinEvent -FilterHashtable @{LogName='Directory Service'; Id=1000} | Select-Object TimeCreated, Message
> ```
> L'événement **ID 1000** signifie *« Le démarrage des services de domaine Active Directory est terminé »* (*Microsoft Active Directory Domain Services startup complete*). On en trouve **un par démarrage du service NTDS**, donc un par redémarrage du DC depuis sa promotion. C'est un moyen simple de dater les redémarrages d'un DC.
>
> > Ne cherche pas l'événement 1109 : Windows Server 2025 ne le génère pas après la promotion.

**D4.** Vérifie l'état de la réplication (même avec un seul DC) :
```powershell
repadmin /showrepl
repadmin /replsummary
```
Que retourne `repadmin /replsummary` avec un seul DC ?

> [!success]- Afficher la correction — D4
> ```powershell
> repadmin /showrepl
> # → "There are no replication errors" avec un seul DC
>
> repadmin /replsummary
> # → Affiche le DC seul avec 0 delta de réplication
> ```
> Avec un seul DC, `repadmin /replsummary` indique qu'il n'y a aucun partenaire de réplication. L'outil devient vraiment utile à partir de 2 DC.

## Partie E — Scénario de dépannage (bonus)

**E1. Simulation de problème DNS**

Arrête temporairement le service DNS sur le DC :
```powershell
Stop-Service -Name DNS
```

Depuis un poste client, essaie de te connecter au domaine. Que se passe-t-il ?

Redémarre le service DNS :
```powershell
Start-Service -Name DNS
```

Retrouve dans les journaux l'événement qui signale l'arrêt et le redémarrage du service.

> [!success]- Afficher la correction — E1
> Après `Stop-Service DNS` :
> - Les postes clients ne peuvent plus résoudre `ad.fournil.lab`
> - L'authentification Kerberos échoue (ne trouve plus le DC via SRV)
> - Les messages d'erreur côté client : "Le domaine n'est pas disponible" ou "Aucun contrôleur de domaine n'a pu être contacté"
>
> Dans les journaux système du DC, chercher l'**ID 7036** (service démarré/arrêté) dans le journal **Système**.
>
> Après `Start-Service DNS` : l'authentification reprend dans les 30-60 secondes.

**E2.** Quelle commande permet de vérifier que le DC répond correctement aux requêtes DNS du domaine ?
```powershell
Resolve-DnsName _ldap._tcp.ad.fournil.lab -Type SRV
```
Qu'est-ce qu'un enregistrement SRV et pourquoi AD en a-t-il besoin ?

> [!success]- Afficher la correction — E2
> ```powershell
> Resolve-DnsName _ldap._tcp.ad.fournil.lab -Type SRV
> ```
> Exemple de retour :
> ```
> Name                              Type  TTL  Section NameTarget              Port
> _ldap._tcp.ad.fournil.lab         SRV   600  Answer  dc01.ad.fournil.lab     389
> ```
> Un **enregistrement SRV** (Service Record) indique à quel serveur et sur quel port se connecter pour un service donné. AD en a besoin car les clients ne connaissent pas a priori l'adresse IP du DC : ils interrogent le DNS pour trouver `_ldap._tcp.<domaine>` et `_kerberos._tcp.<domaine>`. Sans ces enregistrements, aucun client ne peut localiser le DC pour s'authentifier.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/tp)
