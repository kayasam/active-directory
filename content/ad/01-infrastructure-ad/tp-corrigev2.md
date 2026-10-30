---
title: "TP 01 — Infrastructure Active Directory — Correction"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/01-infrastructure-ad"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/01-infrastructure-ad-corrigev2.md">↓ Télécharger le corrigé (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>
<nav class="exercise-resources" aria-label="Ressources du TP"><a href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp">Énoncé</a><a class="exercise-correction" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp-corrigev2" aria-current="page">Corrigé</a></nav>

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h30

> Chapitres associés : [01. Infrastructure Active Directory](https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/)

---

## Contexte — Fournil

La société **Fournil** est une boulangerie industrielle implantée à Bordeaux. Elle souhaite centraliser la gestion de ses comptes et de ses postes via Active Directory. Vous êtes mandaté pour installer et configurer le premier contrôleur de domaine.

| Paramètre | Valeur |
|-----------|--------|
| Nom de domaine | `ad.fournil.lab` |
| Nom NetBIOS | `FOURNIL` |
| Nom du serveur | `DC01` |
| Adresse IP du DC | `192.168.3.10/24` |
| Mot de passe DSRM | `P@ssw0rd!` |

---

## Objectifs

- Installer le rôle AD DS sur Windows Server 2025
- Promouvoir le serveur en contrôleur de domaine (nouvelle forêt)
- Vérifier l'installation via les outils graphiques et PowerShell
- Contrôler l'intégration DNS

---

## Prérequis lab

- Machine virtuelle Windows Server 2025 (VMware Workstation)
- IP fixe configurée (`192.168.3.10/24`)
- Serveur DNS préféré pointant sur lui-même (`192.168.3.10`)
- Nom d'hôte défini avant l'installation (`DC01`)

---

## Partie A — Préparation du serveur (15 min)

**A1.** Vérifie le nom de ta machine. Quel est-il ? Comment le modifier si nécessaire ? Renomme-la `DC01` si ce n'est pas déjà fait.

> [!success]- Afficher la correction — A1
> ```powershell
> hostname
> # ou
> $env:COMPUTERNAME
> ```
> Pour renommer : **Paramètres → Système → Informations système → Renommer ce PC**, ou :
> ```powershell
> Rename-Computer -NewName "DC01" -Restart
> ```
> > Toujours renommer **avant** de promouvoir en DC.

**A2.** Vérifie la configuration IP de ta carte réseau. Quelle commande PowerShell permet d'afficher les interfaces et leurs adresses ?

> [!success]- Afficher la correction — A2
> ```powershell
> Get-NetIPConfiguration
> # ou plus détaillé :
> Get-NetIPAddress
> ```

**A3.** Dans les propriétés TCP/IP de ta carte réseau, configure :
- IP fixe : `192.168.3.10`
- Masque : `255.255.255.0`
- DNS préféré : `192.168.3.10` (lui-même)

> [!success]- Afficher la correction — A3
> Via l'interface : Panneau de configuration → Centre Réseau → Propriétés de la carte → TCP/IPv4.
>
> Via PowerShell :
> ```powershell
> New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.3.10 -PrefixLength 24
> Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.3.10
> ```

**A4.** Vérifie que le serveur se résout bien lui-même. Quelle commande PowerShell utilises-tu ?

> [!success]- Afficher la correction — A4
> ```powershell
> Resolve-DnsName DC01
> # ou
> nslookup DC01
> ```
> > Avant la promotion, la résolution fonctionne via le fichier hosts ou le DNS de la passerelle. Après la promotion, c'est le DC lui-même qui répond.

## Partie B — Installation du rôle AD DS (20 min)

**B1.** Installe le rôle **Active Directory Domain Services** via le Gestionnaire de serveur. Quels outils de gestion sont ajoutés automatiquement ?

> [!success]- Afficher la correction — B1
> Les outils ajoutés automatiquement sont les **Outils d'administration de serveur distant (RSAT)** pour AD DS :
> - Utilisateurs et ordinateurs Active Directory (`dsa.msc`)
> - Sites et services Active Directory (`dssite.msc`)
> - Domaines et approbations Active Directory (`domain.msc`)
> - Centre d'administration Active Directory (`dsac.exe`)
> - Module PowerShell `ActiveDirectory`
> - Console **Gestion des stratégies de groupe** (`gpmc.msc`) — installée avec AD DS (vérifié : `FeatureResult` liste *Group Policy Management*)

**B2.** Réalise la même installation via PowerShell. Quelle commande utilises-tu ?

> [!success]- Afficher la correction — B2
> ```powershell
> Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
> ```

**B3.** Une fois l'installation terminée, une notification apparaît dans le Gestionnaire de serveur. Qu'indique-t-elle ?

> [!success]- Afficher la correction — B3
> La notification indique **"Configuration requise pour les services AD DS"** avec un lien **"Promouvoir ce serveur en contrôleur de domaine"**. Le rôle est installé mais le domaine n'existe pas encore.

## Partie C — Promotion en contrôleur de domaine (30 min)

**C1.** Lance l'assistant de promotion. Quelle option choisis-tu pour créer un tout nouveau domaine ?

> [!success]- Afficher la correction — C1
> L'option **"Ajouter une nouvelle forêt"** crée un domaine racine dans une forêt vierge. Les deux autres options (*Ajouter un DC à un domaine existant* et *Ajouter un domaine enfant*) supposent qu'une forêt AD existe déjà.

**C2.** Crée la forêt avec les paramètres suivants :
- Nom de domaine : `ad.fournil.lab`
- Niveau fonctionnel forêt et domaine : Windows Server 2025
- Options : DNS + Catalogue global cochés
- Mot de passe DSRM : `P@ssw0rd!`

> [!success]- Afficher la correction — C2
> Équivalent PowerShell de l'opération effectuée :
> ```powershell
> Install-ADDSForest `
>   -DomainName "ad.fournil.lab" `
>   -DomainNetbiosName "FOURNIL" `
>   -ForestMode "Win2025" `
>   -DomainMode "Win2025" `
>   -InstallDns `
>   -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>   -Force
> ```
> > Le serveur redémarre automatiquement à la fin. **Ne pas** ajouter `-NoRebootOnCompletion` en TP : tant que le serveur n'a pas redémarré, il n'est plus autonome sans être encore DC (NTDS arrêté, comptes locaux refusés à distance). Attention : un `Restart-Computer` lancé à distance à ce moment-là échoue, il faut redémarrer depuis la console.

**C3.** Pendant l'assistant, un avertissement apparaît concernant la délégation DNS. Est-ce bloquant ? Pourquoi ?

> [!success]- Afficher la correction — C3
> L'avertissement *"Impossible de créer une délégation pour ce serveur DNS"* est **non bloquant**. Il indique qu'aucun DNS parent ne délègue vers notre zone `ad.fournil.lab`, ce qui est normal pour un lab ou un domaine interne isolé. En production, il serait résolu en configurant la délégation dans le DNS parent.

**C4.** Une fois le redémarrage effectué, avec quel compte te connectes-tu ? Quelle est la différence avec le compte local d'avant ?

> [!success]- Afficher la correction — C4
> On se connecte avec le compte **`FOURNIL\Administrateur`** (compte administrateur du domaine). Lors de la création de la forêt, le compte **Administrateur local devient l'Administrateur du domaine, avec le même mot de passe** (les autres comptes locaux deviennent eux aussi des comptes du domaine). Un DC n'a plus de base SAM locale utilisable : seul le compte **DSRM** reste local, pour le mode restauration.
>
> > D'où le réflexe : **définir un mot de passe fort sur l'Administrateur local avant la promotion**.

## Partie D — Vérification (25 min)

**D1.** Ouvre **Utilisateurs et ordinateurs Active Directory** (`dsa.msc`). Quels conteneurs par défaut vois-tu ? À quoi servent `Computers` et `Users` ?

> [!success]- Afficher la correction — D1
> Conteneurs par défaut visibles dans `dsa.msc` :
>
> | Conteneur | Rôle |
> |-----------|------|
> | `Builtin` | Groupes locaux intégrés (Administrateurs, Opérateurs...) |
> | `Computers` | Conteneur par défaut des ordinateurs joints au domaine |
> | `Domain Controllers` | OU contenant les contrôleurs de domaine |
> | `ForeignSecurityPrincipals` | Représente les comptes d'autres domaines ou forêts ajoutés à nos groupes |
> | `Managed Service Accounts` | Comptes de service gérés (gMSA) |
> | `Users` | Conteneur par défaut des utilisateurs et groupes créés à l'installation |
>
> ![ad-tp01-dsa-conteneurs](https://cours.kaya.ovh/active-directory/assets/supports/f2eb37ba29f238575f9b.png)
>
> > `Computers` et `Users` sont des **conteneurs** (pas des OU) : on ne peut pas leur appliquer de GPO directement. Seule `Domain Controllers` porte l'icône d'OU.
> >
> > Avec **Affichage → Fonctionnalités avancées**, d'autres conteneurs apparaissent (`System`, `LostAndFound`, `Program Data`, `NTDS Quotas`, `TPM Devices`…) : on n'y touche pas.

**D2.** Ouvre le **Gestionnaire DNS** (`dnsmgmt.msc`). Retrouve la zone `ad.fournil.lab`. Quels types d'enregistrements ont été créés automatiquement ?

> [!success]- Afficher la correction — D2
> Enregistrements créés automatiquement dans `ad.fournil.lab` :
>
> | Type | Nom | Utilité |
> |------|-----|---------|
> | `A` | `dc01` | Résolution du DC |
> | `SRV` | `_ldap._tcp` | Localisation du service LDAP |
> | `SRV` | `_kerberos._tcp` | Localisation de Kerberos |
> | `SRV` | `_gc._tcp` | Catalogue global |
> | `NS` | `@` | Serveur de noms de la zone |
> | `SOA` | `@` | Autorité de la zone |
> | `A` | `@` | Le nom du domaine lui-même pointe vers le DC |
>
> ![ad-tp01-dns-zone](https://cours.kaya.ovh/active-directory/assets/supports/db17a688dd44c866a175.png)
>
> On trouve aussi `_kpasswd` (changement de mot de passe Kerberos), les variantes `_udp`, et les mêmes SRV déclinés par site (`_ldap._tcp.Default-First-Site-Name._sites`). C'est ce qui permettra, au chapitre 04, d'orienter chaque client vers le DC de son site.

**D3.** Exécute les commandes PowerShell suivantes et note les informations retournées :

```powershell
Get-ADDomain
Get-ADForest
```

> [!success]- Afficher la correction — D3
> ```powershell
> Get-ADDomain
> ```
> Retourne notamment : `DNSRoot` (ad.fournil.lab), `NetBIOSName` (FOURNIL), `DomainMode`, `PDCEmulator`, `RIDMaster`, `InfrastructureMaster`.
>
> ```powershell
> Get-ADForest
> ```
> Retourne : `Name` (ad.fournil.lab), `ForestMode`, `SchemaMaster`, `DomainNamingMaster`, liste des domaines et sites.

**D4.** Lance un diagnostic complet du DC :

```powershell
dcdiag /test:dns /v
```

Combien de tests passent ? Y a-t-il des avertissements ou erreurs ?

> [!success]- Afficher la correction — D4
> ```powershell
> dcdiag /test:dns /v
> ```
> Sur un lab propre, tous les tests DNS passent. L'avertissement `Warning: DcGetDcName(GC_SERVER_REQUIRED) call failed` peut apparaître si le catalogue global n'est pas encore pleinement répliqué (normal juste après la promotion, disparaît en quelques minutes).

**D5.** Vérifie que le service `NETLOGON` est bien démarré. Quelle commande PowerShell utilises-tu ?

> [!success]- Afficher la correction — D5
> ```powershell
> Get-Service NETLOGON
> # ou
> Get-Service -Name "Netlogon" | Select-Object Name, Status, StartType
> ```
> Le service doit être en état `Running`. NETLOGON est indispensable : il authentifie les utilisateurs et gère le canal sécurisé entre DC et clients.

## Partie E — Bonus

**E1.** Depuis une invite de commandes, exécute `nslookup ad.fournil.lab`. Que retourne-t-il ?

> [!success]- Afficher la correction — E1
> ```
> nslookup ad.fournil.lab
> ```
> Résultat attendu :
> ```
> DNS request timed out.
>     timeout was 2 seconds.
> Server:  UnKnown
> Address:  ::1
>
> Name:    ad.fournil.lab
> Address:  192.168.3.10
> ```
> La réponse est bonne (l'IP du DC), mais `nslookup` affiche `Server: UnKnown` et un délai dépassé. Il interroge le DNS local en **IPv6 (`::1`)**, puis tente une **résolution inverse** de cette adresse, qui échoue faute de **zone de recherche inverse**. Ce n'est pas une panne : c'est l'occasion de montrer que la promotion ne crée pas la zone inverse. `Resolve-DnsName ad.fournil.lab` n'a pas ce défaut.

**E2.** Cherche dans l'Observateur d'événements (`eventvwr.msc`) le journal **Directory Service**. Trouve l'événement confirmant que les services AD DS ont démarré (ID **1000**). Quel autre événement indique que la base AD accepte les mises à jour ?

> [!success]- Afficher la correction — E2
> Dans **Observateur d'événements → Journaux des applications et des services → Directory Service**, chercher :
> - **Événement 1000** — *« Le démarrage des services de domaine Active Directory est terminé »*
> - **Événement 1394** — *« Tous les problèmes empêchant les mises à jour de la base AD DS ont été résolus »* (le service Netlogon a redémarré)
>
> ```powershell
> Get-WinEvent -FilterHashtable @{LogName='Directory Service'; Id=1000,1394} |
>   Select-Object TimeCreated, Id, Message
> ```
>
> > Sous Windows Server 2025, **aucun événement 1109** n'est généré après la promotion : inutile de le chercher.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp)
