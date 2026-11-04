---
title: "TP 08 — Tiering : cloisonner l'administration — Correction"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/08-tiering"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/08-tiering/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/08-tiering/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/08-tiering-corrigev2.md">↓ Télécharger le corrigé (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>
<nav class="exercise-resources" aria-label="Ressources du TP"><a href="https://cours.kaya.ovh/active-directory/ad/08-tiering/tp">Énoncé</a><a class="exercise-correction" href="https://cours.kaya.ovh/active-directory/ad/08-tiering/tp-corrigev2" aria-current="page">Corrigé</a></nav>

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h45

> Chapitres associés : [08. Tiering : cloisonner l'administration](https://cours.kaya.ovh/active-directory/ad/08-tiering/)

---

## Contexte — Fournil

Aujourd'hui, chez Fournil, l'admin système utilise le même compte pour tout, et le support se connecte aux postes avec un compte très privilégié. Après un audit, la direction veut **cloisonner l'administration** : chaque compte d'administration ne doit pouvoir se connecter qu'au niveau qui le concerne.

## Objectifs

- Classer les machines et les comptes de Fournil en Tier 0 / 1 / 2
- Créer l'arborescence, les groupes et les comptes d'administration par niveau
- Interdire par GPO la connexion des comptes Tier 0 et Tier 1 sur les postes
- Protéger le compte Tier 0 avec `Protected Users`
- Déployer Windows LAPS sur les postes

## Prérequis

- `DC01` (`192.168.3.10`) et `PC-PROD-01` joint au domaine, dans `OU=Postes,OU=Ordinateurs,OU=Fournil` (TP 03)
- Stratégie de mot de passe du TP 06 en place : **10 caractères minimum**. Dans ce TP, les comptes d'administration utilisent `Adm!Fournil@2026`.

---

## Partie A — Classer en niveaux (15 min)

**A1.** Classe chaque élément dans le bon niveau (Tier 0, 1 ou 2) et justifie en une phrase :

| Élément | Tier ? |
|---|---|
| `DC01`, `DC02` | |
| `PC-PROD-01`, `PC-DIRECTION-01` | |
| Le futur serveur de fichiers `SRV-FIC01` | |
| L'hôte **Hyper-V** qui fait tourner `DC01` | |
| `svc_backup`, s'il sauvegarde l'état du système des DC (TP 07) | |
| Le groupe `Admins du domaine` | |
| `helpdesk` et `jrenard` (support) | |

> [!success]- Afficher la correction — A1
> | Élément | Tier | Justification |
> |---|---|---|
> | `DC01`, `DC02` | **0** | Ils hébergent l'annuaire : qui les contrôle contrôle le domaine |
> | `PC-PROD-01`, `PC-DIRECTION-01` | **2** | Postes de travail |
> | `SRV-FIC01` | **1** | Serveur membre qui héberge des données |
> | Hôte Hyper-V de `DC01` | **0** | L'administrateur de l'hôte peut éteindre le DC, copier son disque virtuel et en extraire la base `NTDS.dit` |
> | `svc_backup` (sauvegarde des DC) | **0** | Une sauvegarde d'état du système **contient** l'annuaire : qui la lit, ou qui contrôle le compte qui la fait, contrôle le domaine |
> | `Admins du domaine` | **0** | Contrôle total du domaine |
> | `helpdesk`, `jrenard` | **2** | Ils n'agissent que sur les utilisateurs et les postes |
>
> Le piège de l'exercice : l'**hyperviseur** et la **sauvegarde** des DC. On les oublie souvent, alors qu'ils donnent un accès complet à l'annuaire sans jamais se connecter au DC.

**A2.** Un technicien, membre de `Admins du domaine`, ouvre une session sur `PC-PROD-01` pour réinstaller une imprimante. Le poste était infecté depuis la veille. Explique ce que l'attaquant peut obtenir, et jusqu'où il peut aller.

> [!success]- Afficher la correction — A2
> À l'ouverture de session interactive, les secrets du compte (hash NTLM, tickets Kerberos) sont chargés dans la mémoire du processus **LSASS** du poste. L'attaquant, déjà présent sur la machine, les extrait et les **réutilise** (*pass-the-hash*, *pass-the-ticket*) sans connaître le mot de passe.
>
> Le compte étant **Admin du domaine**, l'attaquant peut se connecter à `DC01`, créer ses propres comptes, déployer un rançongiciel par GPO sur tout le parc : **le domaine entier est compromis**, à partir d'un simple poste.

**A3.** Pourquoi la règle d'or interdit-elle de « descendre » (un compte Tier 0 sur un poste), mais pas de « monter » de la même façon (un compte Tier 2 qui tente d'ouvrir une session sur un DC) ?

> [!success]- Afficher la correction — A3
> - **Descendre** est dangereux pour le **compte** : il laisse ses identifiants sur une machine peu protégée, où un attaquant a plus de chances d'être présent.
> - **Monter** n'expose rien : un compte Tier 2 n'a pas de droit d'ouverture de session sur un DC, Windows le refuse déjà. Et même s'il y parvenait, il n'apporterait aucun secret puissant à voler.
>
> Le risque vient toujours d'un **secret puissant posé sur une machine faible**.

---

## Partie B — Comptes et groupes par niveau (20 min)

**B1.** Crée l'OU `Administration` **directement sous le domaine**, à côté de `OU=Fournil` (et non dessous), avec l'arborescence suivante :

```
OU=Administration
├── OU=Tier0  → Comptes, Groupes, Services
├── OU=Tier1  → Comptes, Groupes, Serveurs, Services
└── OU=Tier2  → Comptes, Groupes
```

Pourquoi ne pas la ranger sous `OU=Fournil` ?

> [!success]- Afficher la correction — B1
> ```powershell
> $domaine = "DC=ad,DC=fournil,DC=lab"
> $admin   = "OU=Administration,$domaine"
>
> New-ADOrganizationalUnit -Name "Administration" -Path $domaine
> foreach ($t in 0,1,2) {
>     New-ADOrganizationalUnit -Name "Tier$t" -Path $admin
>     foreach ($sous in "Comptes","Groupes") {
>         New-ADOrganizationalUnit -Name $sous -Path "OU=Tier$t,$admin"
>     }
> }
> New-ADOrganizationalUnit -Name "Services" -Path "OU=Tier0,$admin"
> New-ADOrganizationalUnit -Name "Serveurs" -Path "OU=Tier1,$admin"
> New-ADOrganizationalUnit -Name "Services" -Path "OU=Tier1,$admin"
>
> Get-ADOrganizationalUnit -SearchBase $admin -Filter * |
>     Select-Object Name, DistinguishedName
> ```
>
> **Pourquoi à côté de `Fournil` ?** Délégations et GPO sont **héritées** par les sous-OUs. Sous `OU=Fournil`, une délégation métier (par exemple « réinitialiser les mots de passe » donnée sur toute l'entreprise) permettrait de réinitialiser `adm0.sysinfo`, donc de prendre le Tier 0. Et les GPO des utilisateurs et des postes s'appliqueraient aussi aux comptes d'administration. Deux branches séparées dès la racine : aucun héritage possible de l'une vers l'autre.

**B2.** Crée dans l'OU `Groupes` de chaque niveau le groupe global de sécurité correspondant : `GG_Tier0_Admins`, `GG_Tier1_Admins`, `GG_Tier2_Admins`.

> [!success]- Afficher la correction — B2
> ```powershell
> foreach ($t in 0,1,2) {
>     New-ADGroup -Name "GG_Tier${t}_Admins" -GroupScope Global -GroupCategory Security `
>                 -Path "OU=Groupes,OU=Tier$t,OU=Administration,DC=ad,DC=fournil,DC=lab"
> }
> ```
> `${t}` (avec accolades) est nécessaire : sans elles, PowerShell chercherait une variable `$t_Admins`.

**B3.** Crée les trois comptes d'administration (mot de passe `Adm!Fournil@2026`) et ajoute-les à leur groupe :

| Compte | OU | Groupe |
|---|---|---|
| `adm0.sysinfo` | `Tier0/Comptes` | `GG_Tier0_Admins` |
| `adm1.sysinfo` | `Tier1/Comptes` | `GG_Tier1_Admins` |
| `adm2.jrenard` | `Tier2/Comptes` | `GG_Tier2_Admins` |

> [!success]- Afficher la correction — B3
> ```powershell
> $pw = ConvertTo-SecureString "Adm!Fournil@2026" -AsPlainText -Force
> $comptes = @(
>     @{ Nom = "adm0.sysinfo"; Tier = 0 },
>     @{ Nom = "adm1.sysinfo"; Tier = 1 },
>     @{ Nom = "adm2.jrenard"; Tier = 2 }
> )
> foreach ($c in $comptes) {
>     New-ADUser -Name $c.Nom -SamAccountName $c.Nom `
>                -UserPrincipalName "$($c.Nom)@ad.fournil.lab" `
>                -Path "OU=Comptes,OU=Tier$($c.Tier),OU=Administration,DC=ad,DC=fournil,DC=lab" `
>                -AccountPassword $pw -Enabled $true
>     Add-ADGroupMember -Identity "GG_Tier$($c.Tier)_Admins" -Members $c.Nom
> }
> ```
> `P@ssw0rd!` (9 caractères) serait refusé : la longueur minimale est de 10 depuis le TP 06.

**B4.** Ajoute `GG_Tier0_Admins` au groupe `Admins du domaine`. Vérifie avec une commande que `adm0.sysinfo` est bien, indirectement, administrateur du domaine.

> [!success]- Afficher la correction — B4
> ```powershell
> Add-ADGroupMember -Identity "Admins du domaine" -Members "GG_Tier0_Admins"
> Get-ADGroupMember -Identity "Admins du domaine" -Recursive | Select-Object Name
> ```
> `-Recursive` développe les groupes imbriqués : `adm0.sysinfo` apparaît, à côté de `Administrateur`. Sans `-Recursive`, on ne voit que le groupe `GG_Tier0_Admins`.
>
> Sur un serveur en anglais, le groupe s'appelle `Domain Admins`.

**B5.** `adm.sysinfo`, créé au TP 06, est membre de `Opérateurs de compte`. Dans quel niveau ce compte se trouve-t-il réellement ? Que faudrait-il en faire ?

> [!success]- Afficher la correction — B5
> **Tier 0.** `Opérateurs de compte` (*Account Operators*) peut créer et modifier la plupart des comptes et groupes du domaine, et peut par défaut **ouvrir une session sur les DC**. Microsoft recommande de laisser ce groupe **vide**.
>
> Il faut donc retirer `adm.sysinfo` de ce groupe, puis le désactiver : son usage est remplacé par `adm0.sysinfo` (Tier 0) et `adm1.sysinfo` (Tier 1).
> ```powershell
> Remove-ADGroupMember -Identity "Opérateurs de compte" -Members "adm.sysinfo" -Confirm:$false
> Disable-ADAccount -Identity "adm.sysinfo"
> ```

**B6.** Range les objets d'administration qui traînent encore sous `OU=Fournil` :
- `svc_backup` (TP 06), classé Tier 0 en A1, va dans `Tier0/Services` ;
- les OUs `OU=Services,OU=Fournil` et `OU=Serveurs,OU=Ordinateurs,OU=Fournil`, désormais vides, sont supprimées : les serveurs membres iront dans `Tier1/Serveurs`.

> [!success]- Afficher la correction — B6
> ```powershell
> Get-ADUser svc_backup |
>     Move-ADObject -TargetPath "OU=Services,OU=Tier0,OU=Administration,DC=ad,DC=fournil,DC=lab"
>
> foreach ($ou in "OU=Services,OU=Fournil,DC=ad,DC=fournil,DC=lab",
>                 "OU=Serveurs,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab") {
>     Set-ADOrganizationalUnit -Identity $ou -ProtectedFromAccidentalDeletion $false
>     Remove-ADOrganizationalUnit -Identity $ou -Confirm:$false
> }
> ```
> Les OUs sont protégées contre la suppression accidentelle (TP 02, E1) : il faut lever la protection avant de les supprimer. Si `Remove-ADOrganizationalUnit` signale que l'OU n'est pas vide, un objet y est resté : le déplacer d'abord.
>
> Résultat : `OU=Fournil` ne contient plus que des objets **métier** (utilisateurs, groupes, postes). Tout ce qui sert à administrer est sous `OU=Administration`.

---

## Partie C — Faire respecter la règle (30 min)

**C1.** Crée la GPO `GPO_Tier2_Postes`, liée à `OU=Postes,OU=Ordinateurs,OU=Fournil`. Dans **Attribution des droits utilisateur**, ajoute `GG_Tier0_Admins`, `GG_Tier1_Admins` et `Admins du domaine` aux quatre droits suivants :
- Interdire l'ouverture d'une session locale
- Interdire l'ouverture de session par les services Bureau à distance
- Interdire l'ouverture de session en tant que tâche
- Interdire l'ouverture de session en tant que service

> [!success]- Afficher la correction — C1
> ```powershell
> New-GPO -Name "GPO_Tier2_Postes" |
>     New-GPLink -Target "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```
> Puis dans `gpmc.msc` → clic droit sur `GPO_Tier2_Postes` → **Modifier** :
>
> `Configuration ordinateur → Stratégies → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Attribution des droits utilisateur`
>
> Pour chacun des quatre droits : cocher **Définir ces paramètres de stratégie** → **Ajouter un utilisateur ou un groupe** → `FOURNIL\GG_Tier0_Admins`, `FOURNIL\GG_Tier1_Admins`, `FOURNIL\Admins du domaine`.
>
> > Avec `Admins du domaine` dans la liste, même le compte `Administrateur` ne peut plus ouvrir de session sur les postes. C'est voulu : pour dépanner un poste, on utilise un compte Tier 2.

**C2.** Dans la même GPO, utilise les **Groupes restreints** pour que `GG_Tier2_Admins` devienne membre du groupe local `Administrateurs` des postes. Quelle section utilises-tu : « Membres de ce groupe » ou « Ce groupe est membre de » ? Pourquoi ?

> [!success]- Afficher la correction — C2
> `Paramètres de sécurité → Groupes restreints` → clic droit **Ajouter un groupe** → `FOURNIL\GG_Tier2_Admins` → section **« Ce groupe est membre de »** → **Ajouter** → `Administrateurs`.
>
> On utilise **« Ce groupe est membre de »** : elle **ajoute** `GG_Tier2_Admins` au groupe local `Administrateurs` sans toucher à ses autres membres.
>
> > [!warning] Le piège
> > Restreindre le groupe `Administrateurs` avec **« Membres de ce groupe »** **remplace** toute sa liste de membres par celle de la GPO. On efface alors l'administrateur local et tout autre groupe ajouté (par exemple par LAPS ou par un logiciel).

**C3.** Sur `PC-PROD-01` : lance `gpupdate /force`, puis vérifie avec `gpresult` que la GPO est appliquée. Affiche ensuite les membres du groupe local `Administrateurs`.

> [!success]- Afficher la correction — C3
> Dans une invite **administrateur** :
> ```powershell
> gpupdate /force
> gpresult /scope computer /r
> Get-LocalGroupMember -Group "Administrateurs"
> ```
> `GPO_Tier2_Postes` apparaît dans les **objets de stratégie de groupe appliqués**, et `FOURNIL\GG_Tier2_Admins` dans les membres du groupe local `Administrateurs` :
> ```
> Name                      PrincipalSource
> ----                      ---------------
> FOURNIL\Admins du domaine ActiveDirectory
> FOURNIL\GG_Tier2_Admins   ActiveDirectory
> PC-PROD-01\Administrateur Local
> ```
> `Admins du domaine` reste membre des `Administrateurs` locaux (ajouté lors de la jonction au domaine). Ce n'est pas un problème : l'**interdiction** d'ouverture de session l'emporte toujours sur l'appartenance à un groupe.
>
> Si la GPO n'apparaît pas : vérifier que `PC-PROD-01` est bien dans `OU=Postes` (`Get-ADComputer PC-PROD-01`) et qu'il a redémarré depuis sa jonction au domaine (TP 03).

**C4.** Toujours sur `PC-PROD-01`, tente d'ouvrir une session avec :
- `FOURNIL\adm0.sysinfo`
- `FOURNIL\adm2.jrenard`

Que se passe-t-il dans chaque cas ? `adm2.jrenard` est-il administrateur du poste ?

> [!success]- Afficher la correction — C4
> - `adm0.sysinfo` : ouverture de session **refusée** avec le message *« La méthode de connexion que vous tentez d’utiliser n’est pas autorisée »*. Le mot de passe est pourtant correct : c'est le droit **Interdire l'ouverture d'une session locale** qui joue.
>
> ![ad-tp08-refus-adm0-poste](https://cours.kaya.ovh/active-directory/assets/supports/12c7f92c1b03c78f90c6.png)
>
> - `adm2.jrenard` : la session s'ouvre. `whoami /groups` affiche `BUILTIN\Administrateurs` et `FOURNIL\GG_Tier2_Admins` : il est bien administrateur du poste, grâce au groupe restreint.
>
> ![ad-tp08-adm2-admin-poste](https://cours.kaya.ovh/active-directory/assets/supports/e55eea19076b233a64ed.png)
>
> Le support peut donc administrer les postes sans jamais y apporter un compte capable de prendre le domaine.

**C5.** Crée de la même façon la GPO `GPO_Tier1_Serveurs`, liée à `OU=Serveurs,OU=Tier1,OU=Administration` : elle interdit la connexion de `GG_Tier0_Admins`, `GG_Tier2_Admins` et `Admins du domaine`, et rend `GG_Tier1_Admins` administrateur local.

> [!success]- Afficher la correction — C5
> ```powershell
> New-GPO -Name "GPO_Tier1_Serveurs" |
>     New-GPLink -Target "OU=Serveurs,OU=Tier1,OU=Administration,DC=ad,DC=fournil,DC=lab"
> ```
> Mêmes réglages qu'en C1 et C2, avec :
> - dans les quatre droits « Interdire… » : `GG_Tier0_Admins`, `GG_Tier2_Admins`, `Admins du domaine` ;
> - dans les groupes restreints : `GG_Tier1_Admins`, **Ce groupe est membre de** → `Administrateurs`.
>
> | Compte | Postes (Tier 2) | Serveurs (Tier 1) | DC (Tier 0) |
> |---|---|---|---|
> | `adm0.sysinfo` | ❌ | ❌ | ✅ |
> | `adm1.sysinfo` | ❌ | ✅ admin | ❌ (pas de droit sur les DC) |
> | `adm2.jrenard` | ✅ admin | ❌ | ❌ |

**C6.** Pourquoi ne faut-il **jamais** lier ces GPO à la racine du domaine ni à l'OU `Domain Controllers` ?

> [!success]- Afficher la correction — C6
> Ces GPO interdisent la connexion de `Admins du domaine`. Liées à la racine, elles s'appliqueraient **aussi aux DC** (héritage) : plus aucun administrateur du domaine ne pourrait ouvrir de session sur `DC01`, ni en console, ni en Bureau à distance. On se retrouverait enfermé dehors, avec une GPO qu'on ne peut plus corriger qu'à distance (`gpmc.msc` depuis une autre machine) ou en mode restauration.
>
> D'où la règle : une GPO de tiering par OU de machines, testée d'abord avec un seul compte, et un compte de secours (`Administrateur`, mot de passe sous enveloppe) qu'on n'utilise jamais au quotidien.

---

## Partie D — Protected Users (10 min)

**D1.** Ajoute `adm0.sysinfo` au groupe `Protected Users`, puis vérifie.

> [!success]- Afficher la correction — D1
> ```powershell
> Add-ADGroupMember -Identity "Protected Users" -Members "adm0.sysinfo"
> Get-ADGroupMember -Identity "Protected Users" | Select-Object Name
> ```
> Les protections s'appliquent à la **prochaine** authentification du compte : un ticket déjà obtenu n'est pas concerné.

**D2.** Depuis `PC-PROD-01` (session `adm2.jrenard`), compare :
```powershell
net use \\DC01\IPC$ /user:FOURNIL\adm0.sysinfo *
net use \\192.168.3.10\IPC$ /user:FOURNIL\adm0.sysinfo *
```
Supprime chaque connexion après l'essai (`net use * /delete /y`). Explique la différence de résultat.

> [!success]- Afficher la correction — D2
> - `\\DC01\IPC$` : **réussit**. Avec un **nom**, Windows utilise **Kerberos**.
> - `\\192.168.3.10\IPC$` : **échoue** avec *« L’erreur système 1327 s’est produite — Des restrictions de compte d’utilisateur empêchent cet utilisateur de se connecter »*. Avec une **adresse IP**, Kerberos est impossible (il faut un nom de service), Windows se rabat sur **NTLM**, et NTLM est interdit aux membres de `Protected Users`.
>
> ![ad-tp08-protected-users-ntlm](https://cours.kaya.ovh/active-directory/assets/supports/92485545f07ab6cc47a5.png)
>
> Le même `net use` par IP avec `adm2.jrenard` (hors Protected Users) réussit : c'est bien l'appartenance au groupe qui bloque NTLM.
>
> C'est la protection attendue : même si un hash NTLM de `adm0.sysinfo` était volé, il ne servirait à rien.
>
> > `adm0.sysinfo` ne peut pas ouvrir de session interactive sur `PC-PROD-01` (C1), mais une connexion **réseau** comme `net use` n'est pas concernée par ce droit : elle ne laisse pas d'identifiants réutilisables sur le poste.

**D3.** Pourquoi ne faut-il pas ajouter `svc_backup` (TP 06) à `Protected Users` ?

> [!success]- Afficher la correction — D3
> `Protected Users` est conçu pour des **comptes humains**. Un compte de service :
> - utilise souvent **NTLM** (logiciels anciens, accès par IP) ;
> - a parfois besoin de **délégation Kerberos** ;
> - doit pouvoir s'authentifier sans limite de 4 heures sur ses tickets.
>
> L'ajouter casserait le service. On protège un compte de service autrement : mot de passe long et unique, droits minimaux, et idéalement un **gMSA** dont AD gère lui-même le mot de passe.

---

## Partie E — Windows LAPS sur les postes (25 min)

**E1.** Sur `DC01`, étends le schéma AD pour Windows LAPS.

> [!success]- Afficher la correction — E1
> ```powershell
> Update-LapsADSchema
> ```
> L'opération ajoute les attributs `msLAPS-*` aux objets ordinateur. Elle ne se fait **qu'une fois par forêt**, avec un compte membre de **Admins du schéma** (l'`Administrateur` de la forêt l'est par défaut).
>
> Après coup, l'onglet **LAPS** apparaît dans les propriétés des ordinateurs, dans `dsa.msc`.

**E2.** Autorise les ordinateurs de `OU=Postes,OU=Ordinateurs,OU=Fournil` à enregistrer leur propre mot de passe LAPS.

> [!success]- Afficher la correction — E2
> ```powershell
> Set-LapsADComputerSelfPermission -Identity "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```
> Chaque ordinateur reçoit le droit d'écrire **son propre** mot de passe dans **son propre** objet AD, et rien d'autre.

**E3.** Crée la GPO `GPO_LAPS_Postes`, liée à `OU=Postes,OU=Ordinateurs,OU=Fournil`, avec les paramètres :
- Configurer le répertoire de sauvegarde des mots de passe : **Active Directory**
- Paramètres du mot de passe : complexité maximale, **16** caractères, **30** jours

> [!success]- Afficher la correction — E3
> ```powershell
> New-GPO -Name "GPO_LAPS_Postes" |
>     New-GPLink -Target "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```
> `Configuration ordinateur → Stratégies → Modèles d'administration → Système → LAPS` :
>
> | Paramètre | Valeur |
> |---|---|
> | Configurer le répertoire de sauvegarde des mots de passe | Activé → **Active Directory** |
> | Paramètres du mot de passe | Activé → complexité : *Majuscules + minuscules + chiffres + caractères spéciaux*, longueur **16**, âge **30** jours |
>
> Sans le premier paramètre, LAPS ne fait **rien** : c'est lui qui active la fonctionnalité.

**E4.** Sur `PC-PROD-01` : applique la stratégie, puis force le traitement LAPS. Dans quel journal vérifier que tout s'est bien passé ?

> [!success]- Afficher la correction — E4
> Dans une invite **administrateur** :
> ```powershell
> gpupdate /force
> Invoke-LapsPolicyProcessing
> ```
> Journal : **Observateur d'événements → Journaux des applications et des services → Microsoft → Windows → LAPS → Operational**. Au premier passage, on y trouve notamment :
>
> | ID | Message |
> |---|---|
> | 10015 | *The managed account password needs to be updated…* |
> | **10018** | *LAPS successfully updated Active Directory with the new password.* |
> | **10020** | *LAPS successfully updated the local admin account with the new password.* |
> | 10004 | *LAPS policy processing succeeded.* |
>
> Aux passages suivants, **10016** (*the managed account password does not need to be updated at this time*) : normal tant que le mot de passe n'a pas expiré.
> ```powershell
> Get-WinEvent -LogName "Microsoft-Windows-LAPS/Operational" -MaxEvents 10 |
>     Select-Object TimeCreated, Id, Message
> ```
> En cas d'erreur de droits, revoir E2 : l'ordinateur n'a pas le droit d'écrire dans son objet.

**E5.** Sur `DC01`, affiche le mot de passe administrateur local de `PC-PROD-01`. Retrouve-le aussi dans `dsa.msc`.

> [!success]- Afficher la correction — E5
> ```powershell
> Get-LapsADPassword -Identity "PC-PROD-01" -AsPlainText
> ```
> Sortie attendue (le mot de passe sera différent chez toi) :
> ```
> ComputerName        : PC-PROD-01
> Account             : Administrateur
> Password            : }!bezTR0V$@91X33
> PasswordUpdateTime  : …
> ExpirationTimestamp : … (+30 jours)
> Source              : EncryptedPassword
> DecryptionStatus    : Success
> AuthorizedDecryptor : FOURNIL\Admins du domaine
> ```
> `Source : EncryptedPassword` : le mot de passe est **chiffré** dans AD (domaine en niveau fonctionnel 2016 ou plus). Seul le **déchiffreur autorisé**, par défaut `Admins du domaine`, peut le lire. Sans `-AsPlainText`, le mot de passe est renvoyé sous forme de `SecureString`.
>
> Dans `dsa.msc` : `OU=Postes` → propriétés de `PC-PROD-01` → onglet **LAPS** → **Afficher le mot de passe**.

**E6.** Fais en sorte que le groupe `GG_Tier2_Admins` puisse lire les mots de passe LAPS des postes. Vérifie depuis une session `adm2.jrenard` sur `PC-PROD-01` : que vaut `DecryptionStatus` ?

> [!success]- Afficher la correction — E6
> Deux réglages sont nécessaires, parce que le mot de passe est **chiffré** (voir E5).
>
> **1. Le droit de lecture** sur l'attribut, limité à `OU=Postes` :
> ```powershell
> Set-LapsADReadPasswordPermission -Identity "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
>                                  -AllowedPrincipals "FOURNIL\GG_Tier2_Admins"
> ```
> Seul, il ne suffit pas : depuis la session `adm2.jrenard`, `Get-LapsADPassword -Identity PC-PROD-01 -AsPlainText` renvoie un mot de passe **vide** et `DecryptionStatus : Unauthorized`.
>
> **2. Le droit de déchiffrer**, dans `GPO_LAPS_Postes` :
> `Configuration ordinateur → Stratégies → Modèles d'administration → Système → LAPS` → **Configurer les déchiffreurs de mots de passe autorisés** → Activé → `FOURNIL\GG_Tier2_Admins`.
>
> Le nouveau déchiffreur ne vaut que pour le **prochain** mot de passe. Sur `PC-PROD-01`, en administrateur :
> ```powershell
> gpupdate /force
> Reset-LapsPassword
> ```
> Ensuite, depuis la session `adm2.jrenard` :
>
> ![ad-tp08-laps-adm2](https://cours.kaya.ovh/active-directory/assets/supports/5bcb9f101e23122f8817.png)
>
> `DecryptionStatus : Success` et `AuthorizedDecryptor : FOURNIL\GG_Tier2_Admins`.
>
> > Il n'y a qu'**un** déchiffreur par mot de passe : désormais, les `Admins du domaine` ne peuvent plus le déchiffrer. C'est cohérent avec le tiering : le mot de passe d'un poste appartient au Tier 2. Pour `OU=Serveurs,OU=Tier1,OU=Administration`, on ferait la même chose avec `GG_Tier1_Admins`.

---

## Partie F — Bonus

**F1.** Liste les comptes marqués `adminCount = 1`. Que signifie cet attribut ? Retrouves-tu des comptes qui ne devraient plus être privilégiés ?

> [!success]- Afficher la correction — F1
> ```powershell
> Get-ADUser -Filter 'adminCount -eq 1' | Select-Object Name, SamAccountName
> ```
> AD pose `adminCount = 1` sur tout compte qui est, ou **a été**, membre d'un groupe protégé (`Admins du domaine`, `Opérateurs de compte`, `Administrateurs`…). Le processus **SDProp** remplace alors ses permissions par un modèle protégé, toutes les 60 minutes.
>
> Le marquage n'est pas immédiat : `adm0.sysinfo`, ajouté à `Admins du domaine` en B4, n'apparaît qu'au prochain passage de SDProp (jusqu'à 60 minutes).
>
> L'attribut **reste** après le retrait du groupe : `adm.sysinfo` (retiré de `Opérateurs de compte` en B5) y figure encore. C'est une bonne liste de départ pour repérer les anciens comptes à privilèges à nettoyer.

**F2.** Après une intervention avec le mot de passe LAPS de `PC-PROD-01`, quelle commande force immédiatement un nouveau mot de passe ?

> [!success]- Afficher la correction — F2
> Sur `PC-PROD-01`, en administrateur :
> ```powershell
> Reset-LapsPassword
> ```
> On peut aussi l'automatiser avec le paramètre de GPO **Actions après authentification** : une fois le mot de passe LAPS utilisé, Windows le renouvelle (et peut fermer la session) au bout du délai choisi.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/08-tiering/tp)
