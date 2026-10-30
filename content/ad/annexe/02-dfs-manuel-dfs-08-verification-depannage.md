---
title: "Verification et Depannage"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-07-HomeDirectory](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory)

## Tableau récapitulatif des chemins DFS

### Espaces de noms des pôles

| Chemin DFS (vu par les utilisateurs) | Cible DC01 | Cible DC02 |
|---------------------------------------|------------|-----------|
| `\\ad.fournil.lab\Laboratoire\fabrication` | `\\DC01\fabrication$` | `\\DC02\fabrication$` |
| `\\ad.fournil.lab\Laboratoire\approvisionnement` | `\\DC01\approvisionnement$` | `\\DC02\approvisionnement$` |
| `\\ad.fournil.lab\Laboratoire\conditionnement` | `\\DC01\conditionnement$` | `\\DC02\conditionnement$` |
| `\\ad.fournil.lab\Laboratoire\qualite-hygiene` | `\\DC01\qualite-hygiene$` | `\\DC02\qualite-hygiene$` |
| `\\ad.fournil.lab\Laboratoire\maintenance` | `\\DC01\maintenance$` | `\\DC02\maintenance$` |
| `\\ad.fournil.lab\Laboratoire\direction-laboratoire` | `\\DC01\direction-laboratoire$` | `\\DC02\direction-laboratoire$` |
| `\\ad.fournil.lab\Laboratoire\communs-laboratoire` | `\\DC01\communs-laboratoire$` | `\\DC02\communs-laboratoire$` |
| `\\ad.fournil.lab\Vente\boutique` | `\\DC01\boutique$` | `\\DC02\boutique$` |
| `\\ad.fournil.lab\Vente\commercial` | `\\DC01\commercial$` | `\\DC02\commercial$` |
| `\\ad.fournil.lab\Vente\livraisons` | `\\DC01\livraisons$` | `\\DC02\livraisons$` |
| `\\ad.fournil.lab\Vente\ressources` | `\\DC01\ressources$` | `\\DC02\ressources$` |
| `\\ad.fournil.lab\Vente\direction-vente` | `\\DC01\direction-vente$` | `\\DC02\direction-vente$` |
| `\\ad.fournil.lab\Vente\communs-vente` | `\\DC01\communs-vente$` | `\\DC02\communs-vente$` |

### Espaces de noms des homes

| Chemin DFS (vu par les utilisateurs) | Cible DC01 | Cible DC02 |
|---------------------------------------|------------|-----------|
| `\\ad.fournil.lab\HOMES\Laboratoire` | `\\DC01\homes-Laboratoire$` | `\\DC02\homes-Laboratoire$` |
| `\\ad.fournil.lab\HOMES\Vente` | `\\DC01\homes-Vente$` | `\\DC02\homes-Vente$` |

### Groupes de réplication DFSr

| Groupe de réplication | Dossier répliqué | Chemin DC01 | Chemin DC02 | Membre primaire |
|-----------------------|------------------|-------------|------------|-----------------|
| `Laboratoire-fabrication-Replication` | fabrication | `C:\fournil\Laboratoire\fabrication` | `C:\fournil\Laboratoire\fabrication` | DC01 |
| `Laboratoire-approvisionnement-Replication` | approvisionnement | `C:\fournil\Laboratoire\approvisionnement` | `C:\fournil\Laboratoire\approvisionnement` | DC01 |
| `Laboratoire-conditionnement-Replication` | conditionnement | `C:\fournil\Laboratoire\conditionnement` | `C:\fournil\Laboratoire\conditionnement` | DC01 |
| `Laboratoire-qualite-hygiene-Replication` | qualite-hygiene | `C:\fournil\Laboratoire\qualite-hygiene` | `C:\fournil\Laboratoire\qualite-hygiene` | DC01 |
| `Laboratoire-maintenance-Replication` | maintenance | `C:\fournil\Laboratoire\maintenance` | `C:\fournil\Laboratoire\maintenance` | DC01 |
| `Laboratoire-direction-laboratoire-Replication` | direction-laboratoire | `C:\fournil\Laboratoire\direction-laboratoire` | `C:\fournil\Laboratoire\direction-laboratoire` | DC01 |
| `Laboratoire-communs-laboratoire-Replication` | communs-laboratoire | `C:\fournil\Laboratoire\communs-laboratoire` | `C:\fournil\Laboratoire\communs-laboratoire` | DC01 |
| `Vente-boutique-Replication` | boutique | `C:\fournil\Vente\boutique` | `C:\fournil\Vente\boutique` | DC01 |
| `Vente-commercial-Replication` | commercial | `C:\fournil\Vente\commercial` | `C:\fournil\Vente\commercial` | DC01 |
| `Vente-livraisons-Replication` | livraisons | `C:\fournil\Vente\livraisons` | `C:\fournil\Vente\livraisons` | DC01 |
| `Vente-ressources-Replication` | ressources | `C:\fournil\Vente\ressources` | `C:\fournil\Vente\ressources` | DC01 |
| `Vente-direction-vente-Replication` | direction-vente | `C:\fournil\Vente\direction-vente` | `C:\fournil\Vente\direction-vente` | DC01 |
| `Vente-communs-vente-Replication` | communs-vente | `C:\fournil\Vente\communs-vente` | `C:\fournil\Vente\communs-vente` | DC01 |
| `HOMES-Laboratoire-Replication` | homes-Laboratoire | `C:\homes\Laboratoire` | `C:\homes\Laboratoire` | DC01 |
| `HOMES-Vente-Replication` | homes-Vente | `C:\homes\Vente` | `C:\homes\Vente` | DC01 |

---

## Commandes de vérification post-déploiement

Après avoir exécuté le script (ou suivi cette procédure manuellement), voici les commandes pour valider le bon fonctionnement :

### Vérifier les espaces de noms DFS

```powershell
# Lister les racines DFS
Get-DfsnRoot -Path "\\ad.fournil.lab\*"

# Lister les dossiers DFS d'un espace de noms
Get-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\*"
Get-DfsnFolder -Path "\\ad.fournil.lab\Vente\*"
Get-DfsnFolder -Path "\\ad.fournil.lab\HOMES\*"

# Vérifier les cibles d'un dossier DFS
Get-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication"
```

### Vérifier la réplication DFS

```powershell
# Lister les groupes de réplication
Get-DfsReplicationGroup

# Vérifier l'état d'un groupe de réplication
Get-DfsrState -GroupName "Laboratoire-fabrication-Replication"

# Générer un rapport de diagnostic de réplication
Write-DfsrHealthReport -GroupName "Laboratoire-fabrication-Replication" `
    -ReferenceComputerName DC01 -Path "C:\DFSRapports"
```

### Vérifier les partages SMB

```powershell
# Sur DC01
Get-SmbShare | Where-Object { $_.Name -like "*$*" -and $_.Name -ne "IPC$" -and $_.Name -ne "C$" }

# Sur DC02
Invoke-Command -ComputerName DC02 -ScriptBlock {
    Get-SmbShare | Where-Object { $_.Name -like "*$*" -and $_.Name -ne "IPC$" -and $_.Name -ne "C$" }
}
```

### Vérifier les HomeDirectory des utilisateurs

```powershell
Get-ADUser -Filter * -Properties HomeDirectory, HomeDrive |
    Where-Object { $_.HomeDirectory } |
    Select-Object SamAccountName, HomeDirectory, HomeDrive |
    Format-Table -AutoSize
```

---

## Dépannage courant

| Problème | Cause probable | Solution |
|----------|---------------|----------|
| `New-DfsnRoot` échoue avec « accès refusé » | Le compte n'a pas les droits d'administration de l'espace de noms | Vérifier l'appartenance au groupe « Admins du domaine » |
| La réplication ne démarre pas | Le service DFSR n'est pas démarré | `Get-Service DFSR -ComputerName DC01,DC02` puis `Start-Service DFSR` |
| Les dossiers DFS ne sont pas visibles | L'ABE masque les dossiers sans permission | Vérifier les ACL NTFS sur les dossiers physiques |
| `Invoke-Command` échoue | WinRM non activé ou pare-feu bloquant | `Enable-PSRemoting -Force` sur DC02, vérifier le port 5985/TCP |
| Le lecteur `H:` ne se mappe pas à l'ouverture de session | Le `HomeDirectory` n'est pas configuré dans AD | Vérifier avec `Get-ADUser -Properties HomeDirectory` |
| Conflit de fichiers après réplication initiale | Des fichiers différents existaient des deux côtés | Vérifier le dossier `ConflictAndDeleted` sur le membre non primaire |
