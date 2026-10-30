# TP 04 — Sites AD et réplication — Correction

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h30

> Chapitres associés : [04. Sites AD et réplication](https://cours.kaya.ovh/active-directory/ad/04-sites-replication/)

---

## Contexte — Fournil

Fournil ouvre une seconde unité de production à **Nantes**. Le siège de **Rennes** héberge déjà `DC01`. La direction veut que les utilisateurs nantais s'authentifient localement, même si le lien WAN entre les deux sites est coupé.

Ta mission : installer un second contrôleur de domaine `DC02` à Nantes, déclarer la topologie physique dans AD et vérifier que la réplication fonctionne.

| Machine | Site | IP | Passerelle | Switch Hyper-V |
|---------|------|----|------------|----------------|
| `DC01` | Rennes | `192.168.3.10/24` | `192.168.3.254` | Internal1 (vSwitch-Rennes) |
| `DC02` | Nantes | `192.168.4.10/24` | `192.168.4.254` | Internal2 (vSwitch-Nantes) |
| Hôte Hyper-V | — | `192.168.3.254` / `192.168.4.254` | — | les deux |

---

## Objectifs

- Relier deux réseaux isolés en faisant de l'hôte un routeur
- Promouvoir un DC **additionnel** dans un domaine existant
- Créer les sites, les subnets et configurer le site link
- Vérifier, forcer et diagnostiquer la réplication

---

## Prérequis lab

- `DC01` opérationnel (TP 01), avec les OUs, utilisateurs et groupes des TP 02 et 03
- Une VM Windows Server 2025 vierge pour `DC02`, connectée au second switch interne
- PowerShell administrateur sur l'**hôte** Hyper-V

---

## Partie A — Interconnecter les deux sites (20 min)

**A1.** Sur l'hôte, liste les adaptateurs `vEthernet`. Note les noms exacts des deux interfaces internes et vérifie qu'elles portent bien `192.168.3.254` et `192.168.4.254`.

> [!success]- Afficher la correction — A1
> ```powershell
> Get-NetAdapter | Where-Object Name -like "vEthernet*" | Select-Object Name, InterfaceDescription
> Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -like "vEthernet*" |
>     Select-Object InterfaceAlias, IPAddress, PrefixLength
> ```
> Les noms dépendent du lab (`vEthernet (vSwitch-Rennes)`, `vEthernet (Internal1)`…) : on les **copie** plutôt que de les retaper.

**A2.** Active le routage IP entre ces deux interfaces. Quelle commande utilises-tu ?

> [!success]- Afficher la correction — A2
> ```powershell
> Set-NetIPInterface -InterfaceAlias "vEthernet (vSwitch-Rennes)" -Forwarding Enabled
> Set-NetIPInterface -InterfaceAlias "vEthernet (vSwitch-Nantes)" -Forwarding Enabled
> ```
> Vérification :
> ```powershell
> Get-NetIPInterface -AddressFamily IPv4 | Where-Object InterfaceAlias -like "vEthernet*" |
>     Select-Object InterfaceAlias, Forwarding
> ```
> > Si les DC ont leur passerelle sur l'hôte (`.254`), les routes statiques `route add … -p` du cours sont **inutiles**. Elles ne servent que si la passerelle par défaut pointe ailleurs.

**A3.** Configure l'IP fixe de `DC02` (voir tableau). Vers quel serveur DNS doit pointer **DNS préféré** **avant** la promotion ? Pourquoi ?

> [!success]- Afficher la correction — A3
> ```powershell
> New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.4.10 -PrefixLength 24 -DefaultGateway 192.168.4.254
> Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.3.10
> ```
> DNS préféré = **`DC01` (192.168.3.10)**. Avant la promotion, `DC02` n'a ni zone DNS ni annuaire : seul `DC01` sait répondre à `ad.fournil.lab` et aux enregistrements SRV qui permettent de **trouver** un DC.

**A4.** Depuis `DC02`, vérifie :
- que `DC01` répond au ping ;
- que le nom `ad.fournil.lab` se résout ;
- que l'enregistrement SRV `_ldap._tcp.ad.fournil.lab` est trouvé.

Quelles commandes utilises-tu ? Si un test échoue, ne passe pas à la suite.

> [!success]- Afficher la correction — A4
> ```powershell
> Test-Connection 192.168.3.10 -Count 2
> Resolve-DnsName ad.fournil.lab
> Resolve-DnsName _ldap._tcp.ad.fournil.lab -Type SRV
> ```
> Résultat attendu : le SRV renvoie `dc01.ad.fournil.lab` sur le port **389**.
>
> > [!warning] Pare-feu
> > Si le ping échoue alors que le routage est actif, c'est souvent le pare-feu Windows de `DC01` (ICMP bloqué sur le profil **Public**). Le profil doit être **Domaine** sur `DC01`. Ne pas désactiver le pare-feu « pour tester » sans le réactiver.

## Partie B — Promouvoir DC02 (25 min)

**B1.** Renomme la machine `DC02` et redémarre.

> [!success]- Afficher la correction — B1
> ```powershell
> Rename-Computer -NewName "DC02" -Restart
> ```

**B2.** Installe le rôle AD DS via PowerShell.

> [!success]- Afficher la correction — B2
> ```powershell
> Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
> ```

**B3.** Promeus `DC02` en **contrôleur de domaine additionnel** de `ad.fournil.lab`, avec DNS et catalogue global, mot de passe DSRM `P@ssw0rd!`. Donne la commande PowerShell. Quelle option de l'assistant graphique correspond ?

> [!success]- Afficher la correction — B3
> ```powershell
> Install-ADDSDomainController `
>     -DomainName "ad.fournil.lab" `
>     -InstallDns `
>     -NoGlobalCatalog:$false `
>     -Credential (Get-Credential "FOURNIL\Administrateur") `
>     -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
>     -Force
> ```
> Dans l'assistant graphique : **« Ajouter un contrôleur de domaine à un domaine existant »**. Le compte fourni doit être **Admins du domaine**. Le serveur **redémarre automatiquement** à la fin. `Status : Success`, puis redémarrage, en quelques minutes.
>
> > Si le TP 06 a déjà été fait (longueur minimale portée à 10), le mot de passe DSRM `P@ssw0rd!` est **refusé** : *« The Directory Services Restore Mode password does not meet the minimum password length requirement »*. Utiliser `P@ssw0rd!2026`.
>
> > On n'a pas besoin de joindre `DC02` au domaine au préalable : la promotion s'en charge. Le joindre avant ne pose pas de problème non plus.

**B4.** Après redémarrage, quel compte utilises-tu pour te connecter sur `DC02` ? Pourquoi n'y a-t-il plus de compte local ?

> [!success]- Afficher la correction — B4
> On se connecte avec **`FOURNIL\Administrateur`**. Un contrôleur de domaine **n'a plus de base SAM locale utilisable** : ses comptes sont ceux de l'annuaire. Le seul compte « local » restant est le compte **DSRM**, utilisable uniquement en mode restauration des services d'annuaire.

**B5.** Modifie la configuration DNS de `DC02` après la promotion : quelles adresses mets-tu en DNS préféré / auxiliaire ?

> [!success]- Afficher la correction — B5
> Attention : juste après la promotion, Windows a **modifié seul** la configuration DNS de `DC02` en `192.168.3.10, 127.0.0.1` (le partenaire, puis la boucle locale). Configuration retenue pour le TP :
>
> | DNS préféré | DNS auxiliaire |
> |---|---|
> | `192.168.4.10` (lui-même) | `192.168.3.10` (DC01) |
>
> Bonne pratique : chaque DC pointe d'abord sur **un DNS local** (lui-même ou le DC du même site), puis sur un autre DC. Certains préfèrent mettre le partenaire en premier et `127.0.0.1` en second pour éviter un démarrage « isolé » — les deux sont défendables, à condition de savoir l'expliquer.
> ```powershell
> Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.4.10,192.168.3.10
> ```

**B6.** Vérifie que les deux DC sont bien listés dans le domaine. Dans quel site apparaît `DC02` ? Pourquoi ?

> [!success]- Afficher la correction — B6
> ```powershell
> Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address, IsGlobalCatalog
> ```
> `DC02` apparaît dans **`Default-First-Site-Name`** : aucun site ni subnet n'existant encore pour `192.168.4.0/24`, AD le place dans le seul site connu.

## Partie C — Sites, subnets et site link (25 min)

**C1.** Ouvre `dssite.msc`. Quel est le nom du site existant ? Quels serveurs contient-il ?

> [!success]- Afficher la correction — C1
> Site : **`Default-First-Site-Name`**, contenant `DC01` et `DC02` dans `Servers`.

**C2.** Renomme ce site en `Rennes` et crée un site `Nantes`. Réalise une opération en GUI, l'autre en PowerShell.

> [!success]- Afficher la correction — C2
> GUI : clic droit sur `Default-First-Site-Name` → **Renommer** → `Rennes` ; clic droit sur `Sites` → **Nouveau site** → `Nantes`, lien `DEFAULTIPSITELINK`.
>
> PowerShell :
> ```powershell
> Get-ADReplicationSite "Default-First-Site-Name" | Rename-ADObject -NewName "Rennes"
> New-ADReplicationSite -Name "Nantes"
> ```

**C3.** Crée les subnets `192.168.3.0/24` (Rennes) et `192.168.4.0/24` (Nantes) via PowerShell.

> [!success]- Afficher la correction — C3
> ```powershell
> New-ADReplicationSubnet -Name "192.168.3.0/24" -Site "Rennes"
> New-ADReplicationSubnet -Name "192.168.4.0/24" -Site "Nantes"
> Get-ADReplicationSubnet -Filter * | Select-Object Name, Site
> ```

**C4.** Déplace `DC02` dans le site `Nantes`.

> [!success]- Afficher la correction — C4
> GUI : `dssite.msc` → `Rennes → Servers → DC02` → clic droit **Déplacer** → `Nantes`.
> ```powershell
> Move-ADDirectoryServer -Identity "DC02" -Site "Nantes"
> ```
> > Créer le subnet ne déplace **pas** un DC existant : le site d'un DC est fixé par l'objet serveur dans `dssite.msc`. Le subnet ne sert qu'aux **clients** (et aux nouveaux DC lors de la promotion). après C3, `Get-ADDomainController DC02` affiche toujours `Site : Rennes`, jusqu'au `Move-ADDirectoryServer`.

**C5.** Le site link `DEFAULTIPSITELINK` relie-t-il bien les deux sites ? Ajoute `Nantes` si besoin et passe la fréquence de réplication à **15 minutes**. Pourquoi ne garderait-on pas 15 min en production ?

> [!success]- Afficher la correction — C5
> Un site créé en GUI avec `DEFAULTIPSITELINK` coché y est déjà ajouté ; un site créé en PowerShell **ne l'est pas**. avant correction, `SitesIncluded` ne contient que `Rennes`.
> ```powershell
> Set-ADReplicationSiteLink -Identity "DEFAULTIPSITELINK" `
>     -SitesIncluded @{Add="Nantes"} `
>     -ReplicationFrequencyInMinutes 15
> Get-ADReplicationSiteLink -Filter * | Select-Object Name, SitesIncluded, Cost, ReplicationFrequencyInMinutes
> ```
> En production, 15 min sur un lien WAN génère du trafic inutile : on reste entre **60 et 180 min**. Une modification urgente (désactivation de compte) peut toujours être forcée à la main.

**C6.** Dans `dssite.msc`, ouvre `Nantes → Servers → DC02 → NTDS Settings`. Qu'y trouves-tu ? Qui a créé ces objets ?

> [!success]- Afficher la correction — C6
> On y trouve un ou plusieurs objets **Connection** (`<générée automatiquement>`) : ce sont les flux de réplication **entrants** de `DC02`. Ils sont créés par le **KCC** (Knowledge Consistency Checker), qui recalcule la topologie toutes les 15 minutes. On ne les crée pas à la main.
>
> ![ad-tp04-dssite-sites-connexion](https://cours.kaya.ovh/active-directory/assets/supports/fcd4245ee016f62ec4f9.png)
> *Résultat attendu : les deux sites avec leur subnet et leur DC. Dans les `NTDS Settings` de DC01, une connexion « automatically generated » arrive de DC02 (site Nantes).*
>
> > Pour ne pas attendre le cycle du KCC : `repadmin /kcc DC01` et `repadmin /kcc DC02`.

## Partie D — Vérifier la réplication (15 min)

**D1.** Sur `DC01`, crée un utilisateur `test.repli` dans `OU=Utilisateurs`. Vérifie immédiatement s'il existe sur `DC02` :

```powershell
Get-ADUser test.repli -Server DC02
```

> [!success]- Afficher la correction — D1
> ```powershell
> New-ADUser -Name "test.repli" -Path "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" `
>     -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Enabled $true -Server DC01
> Get-ADUser test.repli -Server DC02
> ```
> Selon le moment, l'utilisateur est présent ou non : depuis C4, les DC sont dans des sites **différents**, la réplication suit donc la planification du site link (15 min) au lieu de la notification intra-site (~15 s). En lab, il était **déjà présent** : le KCC venait de créer les connexions et avait déclenché une réplication. Ne pas en tirer de conclusion.
>
> > `-Server DC01` force l'écriture sur DC01. Sans ce paramètre, la commande s'adresse au DC « le plus proche », qui n'est pas forcément celui qu'on croit.

**D2.** S'il n'est pas encore présent, force la réplication. Quelle commande utilises-tu ?

> [!success]- Afficher la correction — D2
> ```powershell
> repadmin /syncall /AdeP
> ```
> | Option | Sens |
> |---|---|
> | `A` | Toutes les partitions |
> | `d` | Noms distinctifs dans la sortie |
> | `e` | Inter-sites (entreprise) |
> | `P` | Pousser depuis le DC courant vers ses partenaires |
>
> GUI : `dssite.msc` → `NTDS Settings` de `DC02` → clic droit sur la connexion → **Répliquer maintenant**.
>
> > [!warning] « topology incomplete » juste après la création des sites
> > Attention : lancé **depuis DC01** juste après C4/C5, `repadmin /syncall /AdeP` affiche pour plusieurs partitions *« SyncAll reported the following errors: The following server could not be reached (topology incomplete) »*, alors que la réplication fonctionne.
> > DC01 ne connaît pas encore l'objet Connection **entrant** que le KCC a créé sur DC02 : cet objet n'est pas encore revenu de Nantes. On le lance donc **depuis l'autre DC** (`repadmin /syncall DC02 /AdeP`), ou on attend un cycle. L'erreur disparaît d'elle-même.

**D3.** Affiche l'état de la réplication des deux DC. Combien d'échecs ? Quelle est la date de la dernière réplication réussie ?

> [!success]- Afficher la correction — D3
> ```powershell
> repadmin /replsummary
> repadmin /showrepl
> ```
> Attendu : **0 échec** sur les deux DC, `Last Success` récent pour chaque partition (`DC=ad,…`, `Configuration`, `Schema`, `DomainDnsZones`, `ForestDnsZones`).

**D4.** Lance `dcdiag /test:replications` sur `DC02`. Résultat ?

> [!success]- Afficher la correction — D4
> ```powershell
> dcdiag /s:DC02 /test:replications
> ```
> Attendu : `DC02 a réussi le test Replications`.

## Partie E — Bonus : panne du lien WAN

**E1.** Sur l'hôte, désactive le routage sur l'interface de Nantes. Crée un utilisateur `test.panne` sur `DC01`. Que montre `repadmin /replsummary` ? Un utilisateur nantais peut-il toujours ouvrir une session ? Pourquoi ?

> [!success]- Afficher la correction — E1
> ```powershell
> Set-NetIPInterface -InterfaceAlias "vEthernet (vSwitch-Nantes)" -Forwarding Disabled
> ```
> Résultats attendus :
> - `repadmin /syncall /AdeP` → *« Error contacting server … DC02 … (network error): **1722** (0x6ba) »* (le serveur RPC n'est pas disponible) ;
> - `repadmin /replsummary` → `5 / 5  100  (`**`1256`**`) The remote system is not available` dans les deux sens ;
> - `test.panne` n'existe que sur `DC01`.
>
> Un utilisateur nantais **peut toujours ouvrir une session** : son poste trouve `DC02` grâce au subnet `192.168.4.0/24` associé au site `Nantes`, et `DC02` possède une copie complète de l'annuaire. C'est exactement la raison d'être d'un DC par site. DC01 injoignable, `DC02` valide seul les identifiants de `jrenard`.

**E2.** Réactive le routage. Que se passe-t-il pour `test.panne` ? Faut-il intervenir manuellement ?

> [!success]- Afficher la correction — E2
> Après réactivation du routage, la réplication reprend **automatiquement** au prochain cycle (ou immédiatement avec `repadmin /syncall /AdeP`) : `test.panne` apparaît sur `DC02`. Aucune intervention n'est nécessaire : les **USN** permettent à chaque DC de savoir ce qu'il lui manque. `SyncAll terminated with no errors`, puis `test.panne` est présent sur DC02.
>
> > `repadmin /replsummary` peut encore afficher l'ancienne erreur 1256 dans un sens **pendant quelques minutes** : il montre l'état du **dernier** essai de chaque partenaire, pas l'état en temps réel. Relancer après le cycle suivant.
>
> > Limite à mentionner : au-delà de la **durée de vie des objets supprimés** (tombstone lifetime, 180 jours), un DC resté isolé ne doit plus être reconnecté — il pourrait réintroduire des objets supprimés (objets « persistants »).

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/04-sites-replication/tp)
