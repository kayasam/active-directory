# 04. Sites AD et réplication

> **Objectif** : Comprendre la topologie physique d'Active Directory, configurer des sites et des liens de sites, promouvoir un second contrôleur de domaine et superviser la réplication.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — DC01 (Rennes) : `192.168.3.10` — DC02 (Nantes) : `192.168.4.10`

**Outils abordés :** `dssite.msc` (Sites et services AD), `repadmin`, `dcdiag`, PowerShell `ActiveDirectory`
**Concepts clés :** site, subnet, site link, réplication intra/inter-site, KCC, DC additionnel

---

## 1. Sites et subnets

### Qu'est-ce qu'un site ?

Un **site Active Directory** représente une portion du réseau à **haute disponibilité et faible latence** (typiquement un LAN ou un datacenter). Il est défini par une ou plusieurs plages IP (**subnets**).

> [!TIP] Site ≠ Domaine
> Un site est une notion **physique** (où se trouvent les machines sur le réseau). Un domaine est une notion **logique** (périmètre administratif). Un même domaine peut s'étendre sur plusieurs sites.

Rôles des sites :
- **Optimiser la réplication** : la réplication entre sites est planifiée et compressée ; la réplication intra-site est quasi-immédiate.
- **Orienter l'authentification** : un poste client s'authentifie préférentiellement auprès du DC de son propre site.
- **Contrôler les GPO de site** : des GPO peuvent être liées à un site.

### Subnet

Un subnet associe une **plage IP** (ex. `192.168.3.0/24`) à un site. Quand un poste se connecte, AD identifie son site en comparant son IP aux subnets déclarés.

| Objet | Exemple | Rôle |
|-------|---------|------|
| Site | `Rennes` | Représente le bureau de Rennes |
| Subnet | `192.168.3.0/24` | Associé au site Rennes |
| Site | `Nantes` | Représente le bureau de Nantes |
| Subnet | `192.168.4.0/24` | Associé au site Nantes |

---

## 2. Réplication Active Directory

### Principe multi-maître

AD est **multi-maître** : tous les DC peuvent recevoir des écritures. Les modifications sont ensuite répliquées entre tous les DC. Si deux DC modifient le même attribut simultanément, le conflit est résolu par **USN (Update Sequence Number)** et horodatage.

### Réplication intra-site

Entre deux DC du **même site** :
- Déclenchée en **quasi-temps réel** (notification dans les 15 secondes)
- Protocole **RPC sur IP** (port 135 + dynamique)
- **Pas de compression** (le réseau local est supposé rapide)
- Topologie calculée automatiquement par le **KCC**

### Réplication inter-site

Entre deux DC de **sites différents** :
- **Planifiée** (toutes les 3 heures par défaut, configurable)
- **Compressée** (réduit la bande passante)
- Protocole **RPC sur IP** (recommandé) ou SMTP
- Passe par un **serveur tête de pont** (bridgehead server)

### KCC — Knowledge Consistency Checker

Le KCC est un service qui tourne sur chaque DC et **calcule automatiquement la topologie de réplication** (quels DC se répliquent avec qui). Il crée des objets **Connection** dans `dssite.msc`. Il s'exécute toutes les 15 minutes.

```
DC01 (Rennes) ──réplication inter-site──▶ DC02 (Nantes)
     │                                        │
  clients Rennes                          clients Nantes
```

---

## 3. Topologie réseau — Lab Hyper-V

### Architecture du lab

Dans ce lab, deux réseaux internes Hyper-V simulent deux sites géographiques :

| Machine | Site | IP | Switch Hyper-V |
|---------|------|----|----------------|
| DC01 | Rennes | `192.168.3.10` | Internal1 |
| PC-PROD-01 (Win11) | Rennes | `192.168.3.100` | Internal1 |
| DC02 | Nantes | `192.168.4.10` | Internal2 |
| Hôte Hyper-V | — | `192.168.3.254` / `192.168.4.254` | Les deux |

### Le problème : deux réseaux isolés

Par défaut, les deux switches internes Hyper-V sont **complètement isolés**. DC01 et DC02 ne peuvent pas se joindre.

L'hôte possède une interface virtuelle sur chaque réseau (`vEthernet`). En activant le **routage IP sur l'hôte**, il devient passerelle entre les deux subnets.

### Solution : activer le routage IP sur l'hôte

**Sur l'hôte Hyper-V** (PowerShell en administrateur) :

```powershell
# Identifier les alias des adaptateurs vEthernet (adapter les noms à ton lab)
Get-NetAdapter | Where-Object { $_.Name -like "vEthernet*" } | Select-Object Name, InterfaceDescription

# Activer le forwarding IP sur les deux interfaces
Set-NetIPInterface -InterfaceAlias "vEthernet (Internal1)" -Forwarding Enabled
Set-NetIPInterface -InterfaceAlias "vEthernet (Internal2)" -Forwarding Enabled
```

**Sur DC01** (route permanente vers le réseau de Nantes) :

```powershell
route add 192.168.4.0 mask 255.255.255.0 192.168.3.254 -p
```

**Sur DC02** (route permanente vers le réseau de Rennes) :

```powershell
route add 192.168.3.0 mask 255.255.255.0 192.168.4.254 -p
```

> [!NOTE] Pourquoi ça fonctionne
> L'hôte a 192.168.3.254 sur Internal1 et 192.168.4.254 sur Internal2. Avec le forwarding activé, il relaie les paquets entre les deux réseaux — exactement comme un routeur WAN en production.

---

## 4. Promouvoir un deuxième contrôleur de domaine

DC02 rejoint le **domaine existant** `ad.fournil.lab` comme **DC additionnel** (pas une nouvelle forêt).

### Prérequis DC02

| Paramètre | Valeur |
|-----------|--------|
| Nom | `DC02` |
| IP | `192.168.4.10` |
| Masque | `255.255.255.0` |
| Passerelle | `192.168.4.254` |
| DNS préféré | `192.168.3.10` (DC01) |
| DNS alternatif | `192.168.4.10` (lui-même, après promotion) |

> [!WARNING] DNS de DC02 avant la promotion
> Avant d'être promu, DC02 doit résoudre `ad.fournil.lab` via DC01. Son DNS préféré doit donc pointer vers **DC01 (192.168.3.10)**. Après la promotion, on ajoute son propre IP en DNS alternatif.

### Installation et promotion

```powershell
# 1. Installer le rôle AD DS
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 2. Promouvoir en DC additionnel du domaine existant
Install-ADDSDomainController `
    -DomainName "ad.fournil.lab" `
    -InstallDns:$true `
    -Credential (Get-Credential) `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "a12345!" -AsPlainText -Force) `
    -Force
```

Le serveur redémarre automatiquement à la fin de la promotion.

---

## 5. Configurer les sites et subnets

### Outil : dssite.msc (Sites et services Active Directory)

`dssite.msc` permet de gérer :
- Les sites et leurs sous-réseaux associés
- Les site links (liens inter-sites)
- Les serveurs tête de pont
- Les objets Connection (topologie de réplication)

### Via dssite.msc (GUI)

1. Ouvrir `dssite.msc` depuis DC01
2. Renommer `Default-First-Site-Name` → `Rennes`
3. Créer un nouveau site `Nantes`
4. Créer les subnets et les associer :
   - `192.168.3.0/24` → site `Rennes`
   - `192.168.4.0/24` → site `Nantes`
5. Déplacer DC02 dans le site `Nantes` (clic droit sur le serveur → **Déplacer**) : créer le subnet ne déplace **pas** un DC existant

![ad-tp04-dssite-sites-connexion](https://cours.kaya.ovh/active-directory/assets/supports/fcd4245ee016f62ec4f9.png)
*Résultat dans `dssite.msc` : deux sites, deux subnets, un DC par site. Dans les `NTDS Settings` de DC01, l'objet Connection généré automatiquement par le KCC depuis DC02.*

### Via PowerShell

```powershell
# Renommer le site par défaut
Get-ADReplicationSite "Default-First-Site-Name" | Rename-ADObject -NewName "Rennes"

# Créer le site Nantes
New-ADReplicationSite "Nantes"

# Créer les subnets
New-ADReplicationSubnet -Name "192.168.3.0/24" -Site "Rennes"
New-ADReplicationSubnet -Name "192.168.4.0/24" -Site "Nantes"

# Déplacer DC02 dans le site Nantes
Move-ADDirectoryServer -Identity "DC02" -Site "Nantes"
```

> [!WARNING] Site créé en PowerShell = absent du site link
> `New-ADReplicationSite` n'ajoute **pas** le site à `DEFAULTIPSITELINK` (l'assistant graphique, lui, le fait). Il faut l'ajouter explicitement : voir section 6, `-SitesIncluded @{Add="Nantes"}`.

---

## 6. Site Links

Un **site link** représente la connexion réseau entre deux sites. Il définit :

| Paramètre | Défaut | Rôle |
|-----------|--------|------|
| **Coût** | 100 | Plus le coût est bas, plus le lien est préféré |
| **Fréquence** | 180 min | Intervalle de réplication inter-site |
| **Horaire** | 24h/24 | Plages horaires autorisées |

```powershell
# Voir le site link existant
Get-ADReplicationSiteLink -Filter *

# Modifier la fréquence de réplication (ici toutes les 15 minutes pour le lab)
Set-ADReplicationSiteLink -Identity "DEFAULTIPSITELINK" `
    -ReplicationFrequencyInMinutes 15 `
    -SitesIncluded @{Add="Nantes"} `
    -Cost 100
```

> [!TIP] Fréquence en production vs lab
> En production, une fréquence de 60 à 180 min est normale pour un lien WAN. En lab, on la réduit à 15 min pour ne pas attendre pendant les TPs.

---

## 7. Vérifier et forcer la réplication

### Commandes essentielles

```powershell
# État de la réplication depuis DC01
repadmin /showrepl

# Résumé de l'état de tous les DC
repadmin /replsummary

# Forcer la réplication immédiate depuis DC01 vers DC02
repadmin /syncall /AdeP

# Diagnostic complet
dcdiag /test:replications /v
```

### Vérifier via PowerShell

```powershell
# Lister tous les DC du domaine et leur site
Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address

# Voir les partenaires de réplication
Get-ADReplicationPartnerMetadata -Target "DC01" -Scope Domain
```

---

> [!NOTE] À retenir
>
> - Un **site** = une plage IP = un emplacement physique. Il optimise la réplication et l'authentification.
> - **Réplication intra-site** : immédiate, RPC, non compressée.
> - **Réplication inter-site** : planifiée, compressée, via site links.
> - Le **KCC** calcule automatiquement la topologie — on ne crée pas les connexions manuellement.
> - DC02 rejoint le domaine comme **DC additionnel** : même forêt, même domaine, réplication complète de l'annuaire.
> - En lab Hyper-V, l'hôte fait office de **routeur** entre les deux réseaux internes grâce au forwarding IP.

---

## Résumé commandes

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Créer un site | `dssite.msc` | `New-ADReplicationSite` |
| Créer un subnet | `dssite.msc` | `New-ADReplicationSubnet` |
| Voir les site links | `dssite.msc` | `Get-ADReplicationSiteLink` |
| Forcer la réplication | `dssite.msc` → Répliquer maintenant | `repadmin /syncall` |
| État de la réplication | — | `repadmin /showrepl` |
| Lister les DC | `dssite.msc` | `Get-ADDomainController -Filter *` |
