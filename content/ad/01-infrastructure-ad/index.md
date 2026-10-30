---
title: "01. Infrastructure Active Directory"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/01-infrastructure-ad"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/cours/01-infrastructure-ad.md">↓ Télécharger le cours (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>

> **Objectif** : Comprendre le rôle et l'architecture d'Active Directory, installer le rôle AD DS et promouvoir un serveur en contrôleur de domaine.

> [!INFO] Fil rouge — Fournil
> Tous les exemples de ce cours utilisent l'entreprise **Fournil**, boulangerie industrielle.
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01` — IP : `192.168.3.10`

---

## 1. Qu'est-ce qu'Active Directory ?

<iframe width="560" height="315" src="https://www.youtube.com/embed/nhW-0qZzjy4?si=asXhcVTHhn-rtktl" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

Active Directory (AD) est un **service d'annuaire** utilisé pour centraliser :

- les **comptes utilisateurs**
- les **groupes**
- les **ordinateurs**
- les **permissions** du réseau

Il est géré par un serveur appelé **contrôleur de domaine (DC)**.

> En entreprise, on ne crée plus les comptes localement : ils sont tous gérés dans AD.

- [Introduction à AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/training/modules/introduction-to-ad-ds/)
- [Active Directory — Wikipédia](https://fr.wikipedia.org/wiki/Active_Directory)

---

## 2. Structure logique : forêt, domaine, OU

<iframe width="560" height="315" src="https://www.youtube.com/embed/Vk2SfrKQdR8?si=QSfqKNa30QZeEOh-" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### 2.1 Forêt

- Niveau logique le plus haut
- Contient un ou plusieurs domaines
- Contient le **Catalogue Global (GC)**

### 2.2 Domaine

- Espace d'authentification commun
- Contient : comptes, groupes, ordinateurs, GPO
- Exemple : `ad.fournil.lab`

> [Les notions de domaine, arbre et forêt — it-connect](https://www.it-connect.fr/chapitres/domaine-arbre-et-foret/)

### 2.3 Unités d'organisation (OU)

Les OU servent à :

- organiser les objets du domaine
- déléguer l'administration
- appliquer des GPO ciblées

Exemples d'OU pour Fournil :

```
ad.fournil.lab
├── OU=Fournil
│   ├── OU=Direction
│   ├── OU=Production
│   ├── OU=Commercial
│   └── OU=Support
├── OU=Groupes
└── OU=Ordinateurs
```

> [!WARNING]
> Les OU ne définissent **pas** les permissions NTFS. Elles servent à l'organisation et aux GPO.

| Concept | Rôle |
|---------|------|
| **Forêt** | Périmètre de sécurité global ; partage le schéma AD |
| **Domaine** | Unité d'administration (comptes, GPO, DNS) |
| **OU** | Conteneur logique pour organiser et déléguer |
| **DC** | Serveur qui héberge et réplique la base AD |

---

## 3. Le rôle du DNS dans AD

> [!WARNING] DNS = prérequis absolu
> Active Directory ne fonctionne pas sans DNS. Les clients trouvent le DC via des enregistrements SRV. En pratique, le DC héberge lui-même le serveur DNS.

| Enregistrement | Exemple | Utilité |
|----------------|---------|---------|
| `A` | `dc01.ad.fournil.lab → 192.168.3.10` | Résolution du DC |
| `SRV` | `_ldap._tcp.ad.fournil.lab` | Localisation du service LDAP |
| `SRV` | `_kerberos._tcp.ad.fournil.lab` | Localisation de Kerberos |

- [DNS et AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/dns-and-ad-ds)

---

## 4. Installer le rôle AD DS

### 4.1 Avec le Gestionnaire de serveur

1. Ouvrir **Gestionnaire de serveur**
2. **Gérer → Ajouter des rôles et fonctionnalités**
3. Type d'installation : *Basée sur un rôle ou une fonctionnalité*
4. Sélectionner le serveur local
5. Cocher **Active Directory Domain Services**
6. Accepter l'ajout des outils de gestion
7. Laisser les valeurs par défaut pour le reste
8. **Installer**

![Installation du rôle AD DS](https://cours.kaya.ovh/active-directory/assets/supports/external/dd5136cc4aa0fb4a4df2.png)


> [!TIP] Pas encore un DC
> L'installation du rôle ne crée pas le domaine. Il faut ensuite **promouvoir** le serveur.

### 4.2 Avec PowerShell

Lister les rôles disponibles :

```powershell
Get-WindowsFeature
```

Installer AD DS :

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

Vérifier l'installation :

```powershell
Get-WindowsFeature AD-Domain-Services
```

- [Installer AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-)

---

## 5. Promouvoir le serveur en contrôleur de domaine

### 5.1 Avec le Gestionnaire de serveur

1. Dans le Gestionnaire de serveur : **Notification → Promouvoir ce serveur en contrôleur de domaine**

   ![Notification de promotion](https://cours.kaya.ovh/active-directory/assets/supports/external/a8046fc37088c16aa3e7.png)

2. Choisir **Ajouter une nouvelle forêt**

3. Saisir le nom du domaine :

   ```
   ad.fournil.lab
   ```

4. Niveau fonctionnel : **Windows Server 2025**

   ![Niveau fonctionnel](https://cours.kaya.ovh/active-directory/assets/supports/external/4e25e584a0f33162094a.png)

   - [Niveaux fonctionnels AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/active-directory-functional-levels)
   - [Les nouveautés AD dans Windows Server 2025 — it-connect](https://www.it-connect.fr/lactive-directory-aura-le-droit-a-des-nouveautes-dans-windows-server-2025/)

5. Saisir le **mot de passe DSRM** : `P@ssw0rd!`

   > [!WARNING] Mot de passe DSRM
   > Ce mot de passe sert uniquement en mode de restauration (récupération après incident). Il est **différent** du mot de passe administrateur du domaine. Notez-le précieusement.

6. Ne pas cocher **Créer une délégation DNS** (normal en lab isolé)

7. Lancer l'installation → le serveur redémarre automatiquement

- [Descriptions des pages de l'assistant AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/deploy/ad-ds-installation-and-removal-wizard-page-descriptions)
- [Installer et configurer un DC — rdr-it](https://rdr-it.com/mise-en-place-environnement-active-directory/)

### 5.2 Avec PowerShell

Promouvoir en **nouvelle forêt** :

```powershell
Import-Module ADDSDeployment

Install-ADDSForest `
  -DomainName            "ad.fournil.lab" `
  -DomainNetbiosName     "FOURNIL" `
  -DomainMode            "Win2025" `
  -ForestMode            "Win2025" `
  -CreateDnsDelegation:  $false `
  -InstallDns:           $true `
  -DatabasePath          "C:\WINDOWS\NTDS" `
  -LogPath               "C:\WINDOWS\NTDS" `
  -SysvolPath            "C:\WINDOWS\SYSVOL" `
  -NoRebootOnCompletion: $false `
  -Force:                $true
```

> [!NOTE] `Win2025`
> C'est la valeur du niveau fonctionnel Windows Server 2025. Pour des DC 2019/2022, utiliser `WinThreshold`.

> [!WARNING] Le redémarrage fait partie de la promotion
> Tant que le serveur n'a pas redémarré, il n'est **ni** un serveur autonome **ni** un DC : les comptes locaux ne permettent plus de s'authentifier à distance et le service NTDS est arrêté. Si on a utilisé `-NoRebootOnCompletion`, il faut redémarrer **depuis la console** — un `Restart-Computer` lancé à distance est refusé (constaté en lab).

---

## 6. Vérifier l'installation

### Vérifications graphiques

| Outil | Accès | Ce qu'on vérifie |
|-------|-------|-----------------|
| **Utilisateurs et ordinateurs AD** | `dsa.msc` | Le domaine apparaît avec ses conteneurs par défaut |
| **Sites et services AD** | `dssite.msc` | Un site `Default-First-Site-Name` existe |
| **DNS** | `dnsmgmt.msc` | Zone `ad.fournil.lab` créée avec enregistrements SRV |
| **Observateur d'événements** | `eventvwr.msc` | Journal *Directory Service* : événement **1000** (« démarrage d'AD DS terminé ») |

![ad-tp01-dsa-conteneurs](https://cours.kaya.ovh/active-directory/assets/supports/f2eb37ba29f238575f9b.png)
*`dsa.msc` juste après la promotion : les conteneurs par défaut (dossiers simples) et la seule OU créée d'office, `Domain Controllers` (icône d'OU).*

![ad-tp01-dns-zone](https://cours.kaya.ovh/active-directory/assets/supports/db17a688dd44c866a175.png)
*`dnsmgmt.msc` : la zone `ad.fournil.lab` est créée par la promotion, avec les dossiers `_tcp`, `_udp`, `_sites`, `_msdcs` qui contiennent les enregistrements SRV.*

### Via PowerShell

```powershell
# Informations sur le domaine
Get-ADDomain

# Informations sur la forêt
Get-ADForest

# Diagnostic complet du DC
dcdiag /test:dns /v
```

- [Vérifier l'installation AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/deploy/ad-ds-installation-and-removal-wizard-page-descriptions)

---

## 7. Bonnes pratiques d'organisation

- Créer une **OU racine** portant le nom de l'entreprise
- Séparer clairement : `Utilisateurs`, `Groupes`, `Ordinateurs`, `Serveurs`
- Ne jamais appliquer de GPO au niveau du domaine lui-même
- Ne jamais déplacer ni supprimer l'OU **Domain Controllers**
- Toujours utiliser des noms explicites et cohérents
- Renommer le serveur **avant** de le promouvoir en DC

```powershell
# Vérifier la configuration IP
Get-NetIPConfiguration

# Vérifier que le DC se résout lui-même en DNS
Resolve-DnsName ad.fournil.lab
```

---

> [!NOTE] À retenir
>
> - AD DS centralise comptes, groupes, objets et sécurité.
> - La **forêt** = niveau global ; le **domaine** = unité d'administration.
> - Les **OU** structurent le domaine et reçoivent les GPO.
> - La promotion peut se faire via **Server Manager** ou **PowerShell**.
> - Après promotion, le serveur devient **contrôleur de domaine (DC)**.
