---
title: "TP Débutant — DFS et Réplication"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="html" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 28 32"><path d="M2 2h24l-2 25-10 3-10-3Z" fill="#e44d26"/><path d="M14 5v22l7-2 2-20Z" fill="#f16529"/><path d="M7 8h15l-.3 3H11l.3 3h10l-.8 9-6.5 2-6.5-2-.4-5h3l.2 2.6 3.7 1 3.7-1 .3-3.6H8Z" fill="#fff"/></svg>
</span><span class="resource-label">Projet guidé</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-02-tp-debutant-dfs.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 2h
> Prérequis : TP Active Directory terminé, DC01 + DC02 opérationnels
> Niveau : Débutant — commandes manuelles

---

## Contexte

L'Active Directory du Fournil est en place. Maintenant il faut :
- Partager les dossiers entre les deux serveurs (DC01 et DC02)
- Mettre en place DFS pour que les utilisateurs accèdent aux fichiers via un chemin unique (`\\ad.fournil.lab\...`)
- Configurer la réplication pour que les fichiers soient synchronisés entre les serveurs
- Créer les dossiers personnels (homes)

---

## Exercice 1 — Installer les rôles DFS

### Consigne

1. Sur DC01, installez les rôles **DFS Namespace** et **DFS Replication** avec les outils de gestion
2. Sur DC02, installez uniquement **DFS Replication** (via `Invoke-Command`)

### Questions

- Pourquoi DC01 a besoin des 2 rôles mais DC02 n'en a besoin que d'un seul ?
- Que fait le paramètre `-IncludeManagementTools` ?
- Qu'est-ce que `Invoke-Command` ? Pourquoi l'utiliser ?

### Vérification

```powershell
Get-WindowsFeature FS-DFS-Namespace, FS-DFS-Replication | Select-Object Name, InstallState
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [DFS-01-Installer-Roles](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-01-installer-roles)

---

## Exercice 2 — Créer les partages

### Consigne

1. Sur DC02, créez l'arborescence de dossiers `C:\fournil\Laboratoire\fabrication` (et sous-dossiers)
2. Sur DC01 ET DC02, créez un partage caché `fabrication$` pointant vers `C:\fournil\Laboratoire\fabrication`

### Questions

- Pourquoi le `$` à la fin du nom de partage ? Que signifie-t-il ?
- Quelle commande crée un partage SMB ?
- Comment vérifier qu'un partage existe ?

### Vérification

```powershell
# Sur DC01
Get-SmbShare -Name "fabrication$"

# Sur DC02
Invoke-Command -ComputerName DC02 { Get-SmbShare -Name "fabrication$" }
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [DFS-02-Dossiers-Partages-DC02](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-02-dossiers-partages-dc02) et [DFS-03-Partages-DC01](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-03-partages-dc01)

---

## Exercice 3 — Créer un espace de noms DFS

> Etudiez l'architecture DFS avant de commencer :

![Schema-DFS-Architecture](https://cours.kaya.ovh/active-directory/assets/supports/c46280291d5668e55094.svg)

### Consigne

1. Créez un dossier `C:\DFSRoots\Laboratoire` sur DC01
2. Partagez-le sous le nom `Laboratoire`
3. Créez la racine DFS `\\ad.fournil.lab\Laboratoire` pointant vers `\\DC01\Laboratoire`
4. Ajoutez un dossier DFS `\\ad.fournil.lab\Laboratoire\fabrication` avec :
   - Cible 1 : `\\DC01\fabrication$`
   - Cible 2 : `\\DC02\fabrication$`

### Questions

- Quelle est la différence entre un partage SMB normal et un espace de noms DFS ?
- Que signifie `-Type DomainV2` ?
- Que signifie `-EnableAccessBasedEnumeration $true` ?
- Pourquoi 2 cibles (DC01 + DC02) par dossier ?

### Vérification

```powershell
Get-DfsnFolder -Path "\\ad.fournil.lab\Laboratoire\*"
Get-DfsnFolderTarget -Path "\\ad.fournil.lab\Laboratoire\fabrication"
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [DFS-04-Espaces-Noms-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-04-espaces-noms-dfs)

---

## Exercice 4 — Configurer la réplication

### Consigne

Pour le pôle `fabrication` :
1. Créez un groupe de réplication `Laboratoire-fabrication-Replication`
2. Ajoutez DC01 et DC02 comme membres
3. Créez une connexion entre DC01 et DC02
4. Configurez DC01 comme **membre principal** et DC02 comme secondaire
5. Liez la réplication à l'espace de noms DFS

### Questions

- Qu'est-ce que DFSr ?
- Pourquoi un serveur est "principal" et l'autre "secondaire" ?
- Que se passe-t-il si on crée un fichier sur DC02 ? Est-il répliqué vers DC01 ?

### Test

```powershell
# Créer un fichier test sur DC01
New-Item "C:\fournil\Laboratoire\fabrication\test-replication.txt" -Value "bonjour"

# Attendre 30 secondes puis vérifier sur DC02
Invoke-Command -ComputerName DC02 { Get-Content "C:\fournil\Laboratoire\fabrication\test-replication.txt" }
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [DFS-05-Replication-DFSr](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-05-replication-dfsr)

---

## Exercice 5 — Dossiers personnels (Homes)

### Consigne

1. Créez `C:\homes\Laboratoire` et `C:\homes\Vente` sur DC01
2. Appliquez les permissions NTFS :
   - Racine `C:\homes` : SYSTEM + Admins du domaine uniquement
   - `C:\homes\Laboratoire` : + `CREATEUR PROPRIETAIRE` en modification + `Utilisateurs du domaine` en création de dossier
3. Créez le partage `homes-Laboratoire$` sur DC01
4. Créez l'espace de noms DFS `\\ad.fournil.lab\HOMES`
5. Configurez le HomeDirectory de `mlebrun` vers `\\ad.fournil.lab\HOMES\Laboratoire\mlebrun` avec le lecteur `H:`

### Questions

- Qu'est-ce que `CREATEUR PROPRIETAIRE` ? Pourquoi l'utiliser ?
- Que fait `Set-ADUser -HomeDirectory ... -HomeDrive "H:"` ?
- À quoi sert l'ABE (Access Based Enumeration) sur les homes ?

### Vérification

```powershell
Get-ADUser -Identity "mlebrun" -Properties HomeDirectory, HomeDrive | Select-Object Name, HomeDirectory, HomeDrive
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [DFS-06-Homes](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) et [DFS-07-HomeDirectory](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-07-homedirectory)

---

## Exercice 6 — Vérification globale

Depuis un **poste client** connecté avec `mlebrun` :

| Test | Résultat attendu | OK ? |
|------|-------------------|------|
| `\\ad.fournil.lab\Laboratoire\fabrication` | Accès en modification | ☐ |
| `\\ad.fournil.lab\Vente\ressources` | Accès refusé | ☐ |
| Lecteur `H:` visible | Pointe vers le home | ☐ |
| Créer un fichier dans `H:` | Fonctionne | ☐ |

> [!tip]- Commandes de vérification
> Consultez : [DFS-08-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage)

---

## Bonus — Le script fait tout ça automatiquement

> Ouvrez `02-DFS-Deploiement.ps1` et retrouvez quelle phase du script correspond à chaque exercice.

| Exercice | Phase du script |
|----------|----------------|
| 1 (Rôles) | Phase 1 |
| 2 (Partages DC02) | Phase 2-3 |
| 3 (DFS Namespace) | Phase 4 |
| 4 (Réplication) | Phase 5 |
| 5 (Homes) | Phase 6-7 |

> Pour l'explication détaillée : [Explication-Script-DFS](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-script-explication-script-dfs)
