---
title: "TP 07 — Maintenance et dépannage"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/07-maintenance-depannage"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/07-maintenance-depannage/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/07-maintenance-depannage.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


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

**A3.** Lance une sauvegarde de l'état du système via `wbadmin` :
```powershell
wbadmin start systemstatebackup -backuptarget:E: -quiet
```
Combien de temps prend l'opération ? Quelle taille fait la sauvegarde ?

*Pour comprendre la contrainte, essaie aussi `-backuptarget:C:\Sauvegardes` puis `-backuptarget:C:`. Quels messages obtiens-tu ?*

**A4.** Liste les sauvegardes disponibles :
```powershell
wbadmin get versions
```
Note l'**identifiant de version** (format `JJ/MM/AAAA-HH:MM`) — il sera nécessaire pour une restauration.

**A5.** Quelle est la différence entre une sauvegarde de l'état du système et une sauvegarde complète du serveur ?

---

## Partie B — Diagnostic avec dcdiag (25 min)

**B1.** Lance le diagnostic complet du DC :
```powershell
dcdiag /v 2>&1 | Out-File C:\dcdiag_complet.txt
notepad C:\dcdiag_complet.txt
```
Combien de tests sont effectués ? Tous passent-ils ?

**B2.** Lance le test DNS spécifiquement :
```powershell
dcdiag /test:dns /v
```
Quels sous-tests DNS sont effectués ? Y a-t-il des avertissements ?

**B3.** Lance le test de réplication :
```powershell
dcdiag /test:replications
```
Avec un seul DC, quel est le résultat attendu ?

**B4.** Vérifie l'état du service NETLOGON et du partage SYSVOL :
```powershell
dcdiag /test:netlogons
dcdiag /test:sysvol
```
Que contient le partage SYSVOL et pourquoi est-il important ?

---

## Partie C — Rôles FSMO (15 min)

**C1.** Identifie les titulaires des 5 rôles FSMO de ton domaine :
```powershell
netdom query fsmo
```

**C2.** Récupère les mêmes informations via PowerShell AD :
```powershell
Get-ADDomain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
Get-ADForest | Select-Object SchemaMaster, DomainNamingMaster
```

**C3.** Explique le rôle du **PDC Emulator** dans le contexte de la gestion des mots de passe et des verrouillages de compte.

**C4.** Dans un environnement avec 2 DC, sur quel DC placerait-on le rôle PDC Emulator de préférence ? Pourquoi ?

---

## Partie D — Journaux et surveillance (20 min)

**D1.** Dans l'Observateur d'événements, ouvre le journal **Directory Service** :
`Observateur d'événements → Journaux des applications et services → Directory Service`

Filtre sur les événements de niveau **Erreur** et **Avertissement**. Y en a-t-il ?

**D2.** Via PowerShell, affiche les 10 derniers événements du journal Directory Service :
```powershell
Get-WinEvent -LogName "Directory Service" -MaxEvents 10 |
  Select-Object TimeCreated, LevelDisplayName, Id, Message
```

**D3.** Cherche l'événement **ID 1000** dans le journal Directory Service. Que signifie-t-il ? Combien en trouves-tu, et pourquoi ce nombre ?

**D4.** Vérifie l'état de la réplication (même avec un seul DC) :
```powershell
repadmin /showrepl
repadmin /replsummary
```
Que retourne `repadmin /replsummary` avec un seul DC ?

---

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

**E2.** Quelle commande permet de vérifier que le DC répond correctement aux requêtes DNS du domaine ?
```powershell
Resolve-DnsName _ldap._tcp.ad.fournil.lab -Type SRV
```
Qu'est-ce qu'un enregistrement SRV et pourquoi AD en a-t-il besoin ?

---


