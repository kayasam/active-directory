---
title: "08. Tiering : cloisonner l'administration"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/08-tiering"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/08-tiering/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/08-tiering/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/cours/08-tiering.md">↓ Télécharger le cours (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>

> **Objectif** : Comprendre pourquoi un compte administrateur ne doit jamais se connecter « n'importe où », découper le SI en niveaux (tiers), et mettre en place les barrières de base : comptes séparés, GPO d'interdiction de connexion, groupe Protected Users et Windows LAPS.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01` (`192.168.3.10`) — poste : `PC-PROD-01`

**Outils abordés :** `dsa.msc`, `gpmc.msc`, module PowerShell `ActiveDirectory`, module `LAPS`
**Concepts clés :** vol d'identifiants, Tier 0 / 1 / 2, règle « jamais vers le bas », comptes d'administration par niveau, droits « Interdire l'ouverture de session », groupes restreints, Protected Users, Windows LAPS

---

## 1. Le problème : les identifiants restent sur la machine

Quand un compte ouvre une session **interactive** sur un ordinateur (console, Bureau à distance, `runas`, tâche planifiée, service), Windows garde de quoi le réauthentifier en mémoire (processus **LSASS**) : hash NTLM, tickets Kerberos.

Un attaquant qui prend le contrôle de cette machine peut récupérer ces secrets et **se faire passer pour le compte** (attaques *pass-the-hash*, *pass-the-ticket*), sans jamais connaître le mot de passe.

![Schema-Tiering-Vol-Identifiants](https://cours.kaya.ovh/active-directory/assets/supports/241e562af5e32fe0e2fe.svg)

> [!WARNING] Ce n'est pas un scénario théorique
> C'est le chemin d'attaque le plus courant dans les rançongiciels : on ne « casse » pas le DC, on attend qu'un administrateur vienne se connecter sur une machine déjà compromise.

Le **tiering** répond à une seule question : *sur quelles machines chaque compte d'administration a-t-il le droit de se connecter ?*

- [Sécuriser l'accès privilégié — Microsoft Learn](https://learn.microsoft.com/fr-fr/security/privileged-access-workstations/overview)

---

## 2. Le modèle en trois niveaux

On classe chaque machine et chaque compte selon **ce qu'il permet de contrôler** :

| Niveau | Contient | Pourquoi |
|---|---|---|
| **Tier 0** | DC, l'annuaire AD lui-même, comptes *Admins du domaine* / *Administrateurs de l'entreprise*, PKI (AD CS), Entra Connect, **hyperviseurs et sauvegardes qui hébergent ou copient les DC** | Qui contrôle un de ces éléments contrôle **tout le domaine** |
| **Tier 1** | Serveurs membres : fichiers, impression, bases de données, applications | Contrôle des **données et services** de l'entreprise |
| **Tier 2** | Postes de travail, portables, imprimantes, comptes du support | Contrôle des **utilisateurs** |

![Schema-Tiering-Niveaux](https://cours.kaya.ovh/active-directory/assets/supports/435d37e243bfebd244ba.svg)

### La règle d'or

> **Un compte d'un niveau ne se connecte jamais sur une machine d'un niveau inférieur.**

- un compte **Tier 0** ne se connecte **que** sur des machines Tier 0 (DC, poste d'administration dédié) ;
- un compte **Tier 1** ne se connecte ni sur un poste utilisateur, ni sur un DC ;
- un compte **Tier 2** n'a aucun droit sur les serveurs ni sur les DC.

Moyen mnémotechnique : **« on ne descend jamais avec ses clés »**. Un compte puissant qui descend sur une machine moins protégée y laisse ses clés.

> [!NOTE] Et le modèle « Enterprise Access » ?
> Microsoft présente aujourd'hui le **modèle d'accès d'entreprise** (plan de contrôle, plan de gestion, plan de données/charges de travail, accès utilisateur), qui étend le tiering au cloud. Pour un SI on-premise, le découpage Tier 0 / 1 / 2 reste la base, et c'est celui qu'utilise l'**ANSSI** dans ses recommandations AD.
>
> - [Modèle d'accès d'entreprise — Microsoft Learn](https://learn.microsoft.com/fr-fr/security/privileged-access-workstations/privileged-access-access-model)
> - [Recommandations de sécurité relatives à Active Directory — ANSSI](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-active-directory)

---

## 3. Un compte par niveau et par administrateur

Le chapitre 06 posait la première règle : un compte d'administration séparé du compte quotidien. Le tiering la pousse plus loin : **un compte par niveau**.

| Personne | Compte quotidien | Tier 2 | Tier 1 | Tier 0 |
|---|---|---|---|---|
| Julie Renard (support) | `jrenard` | `adm2.jrenard` | — | — |
| Admin système Fournil | `sysinfo` | `adm2.sysinfo` | `adm1.sysinfo` | `adm0.sysinfo` |

- `jrenard` lit ses mails et navigue : **aucun droit d'administration** ;
- `adm2.jrenard` est administrateur local des **postes**, et de rien d'autre ;
- seul `adm0.sysinfo` est membre (indirect) de **Admins du domaine**.

> [!TIP] Convention de nommage
> Le préfixe `adm0.` / `adm1.` / `adm2.` permet de savoir d'un coup d'œil, dans un journal ou dans `dsa.msc`, à quel niveau appartient un compte. Peu importe la convention choisie, l'important est qu'elle soit **appliquée partout**.

---

## 4. Ranger l'annuaire par niveau

### Les comptes et groupes d'administration

On crée une OU dédiée, séparée des utilisateurs :

```
ad.fournil.lab
├── OU=Administration
│   ├── OU=Tier0    ← adm0.*, GG_Tier0_Admins
│   ├── OU=Tier1    ← adm1.*, GG_Tier1_Admins
│   └── OU=Tier2    ← adm2.*, GG_Tier2_Admins
├── OU=Utilisateurs
└── OU=Ordinateurs
    ├── OU=Postes     ← machines Tier 2
    └── OU=Serveurs   ← machines Tier 1
```

Les DC restent dans `OU=Domain Controllers` : c'est le Tier 0.

```powershell
New-ADOrganizationalUnit -Name "Administration" -Path "DC=ad,DC=fournil,DC=lab"
foreach ($t in 0,1,2) {
    New-ADOrganizationalUnit -Name "Tier$t" -Path "OU=Administration,DC=ad,DC=fournil,DC=lab"
    New-ADGroup -Name "GG_Tier${t}_Admins" -GroupScope Global -GroupCategory Security `
                -Path "OU=Tier$t,OU=Administration,DC=ad,DC=fournil,DC=lab"
}

# Seul le groupe Tier 0 donne les droits d'administration du domaine
Add-ADGroupMember -Identity "Admins du domaine" -Members "GG_Tier0_Admins"
```

> [!WARNING] Délégation sur l'OU Administration
> Qui peut modifier un objet de `OU=Tier0` (réinitialiser `adm0.sysinfo`, ajouter un membre à `GG_Tier0_Admins`) **devient** Tier 0. La délégation du support (chapitre 02) porte sur `OU=Utilisateurs` : elle ne doit **jamais** s'étendre à `OU=Administration`.

---

## 5. Faire respecter la règle avec des GPO

Créer des comptes séparés ne suffit pas : rien n'empêche encore `adm0.sysinfo` de se connecter sur un poste. On le **bloque** avec les **droits utilisateur**.

### Les droits « Interdire l'ouverture de session »

`Configuration ordinateur → Stratégies → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Attribution des droits utilisateur`

| Paramètre | Bloque |
|---|---|
| **Interdire l'ouverture d'une session locale** | console, `runas` |
| **Interdire l'ouverture de session par les services Bureau à distance** | RDP |
| **Interdire l'ouverture de session en tant que tâche** | tâches planifiées |
| **Interdire l'ouverture de session en tant que service** | services Windows |

Les connexions **réseau** (accès à un partage, console MMC à distance) ne sont pas bloquées : elles ne laissent pas d'identifiants réutilisables sur la machine cible.

### Quelle GPO, sur quelle OU ?

| GPO | Liée à | Interdit la connexion de | Donne l'admin local à |
|---|---|---|---|
| `GPO_Tier2_Postes` | `OU=Postes` | `GG_Tier0_Admins`, `GG_Tier1_Admins`, `Admins du domaine` | `GG_Tier2_Admins` |
| `GPO_Tier1_Serveurs` | `OU=Serveurs` | `GG_Tier0_Admins`, `GG_Tier2_Admins`, `Admins du domaine` | `GG_Tier1_Admins` |

L'administration locale se donne avec les **Groupes restreints** :
`Paramètres de sécurité → Groupes restreints → Ajouter un groupe → GG_Tier2_Admins` → section **« Ce groupe est membre de »** → `Administrateurs`.

> [!WARNING] Utiliser « Ce groupe est membre de », jamais « Membres de ce groupe »
> Dans un groupe restreint, la section **Membres de ce groupe** **remplace** la liste complète des membres du groupe ciblé. Restreindre ainsi `Administrateurs` effacerait tous les autres administrateurs locaux du poste. La section **Ce groupe est membre de** se contente d'**ajouter** `GG_Tier2_Admins` dans `Administrateurs`.

> [!WARNING] Ne jamais lier ces GPO à la racine du domaine ni à `Domain Controllers`
> Une interdiction appliquée par erreur aux DC peut empêcher **tous** les administrateurs de s'y connecter. On teste d'abord avec un seul compte, sur un seul poste, et on garde le compte `Administrateur` intégré hors de ces groupes (compte de secours, mot de passe sous enveloppe).

### Le résultat sur le poste

Un compte Tier 0 qui tente d'ouvrir une session sur `PC-PROD-01` est refusé, même avec le bon mot de passe :

![ad-tp08-refus-adm0-poste](https://cours.kaya.ovh/active-directory/assets/supports/a08841ad458f5bf050dd.png)
*« The sign-in method you're trying to use isn't allowed » (« La méthode de connexion que vous essayez d'utiliser n'est pas autorisée ») : c'est le droit « Interdire l'ouverture d'une session locale ».*

Le compte Tier 2, lui, ouvre sa session et se retrouve administrateur du poste par le groupe `GG_Tier2_Admins` :

![ad-tp08-adm2-admin-poste](https://cours.kaya.ovh/active-directory/assets/supports/6cf313b342b83f23d6c1.png)

> [!NOTE] L'interdiction vise aussi PowerShell Direct
> Une fois la GPO appliquée, même `Invoke-Command -VMName` (PowerShell Direct depuis l'hôte Hyper-V) est refusé au compte Administrateur du domaine sur le poste : *« Les informations d'identification ne sont pas valides »*. Pour administrer les postes, on utilise un compte Tier 2.

---

## 6. Le groupe Protected Users

`Protected Users` est un groupe de sécurité intégré (niveau fonctionnel 2012 R2 et plus). Ses membres bénéficient de protections **non configurables** :

| Protection | Effet |
|---|---|
| Pas de **NTLM** | Authentification Kerberos uniquement : le hash NTLM n'est plus utilisable |
| Pas de chiffrement faible | Ni DES, ni RC4 dans Kerberos |
| Pas d'**identifiants en cache** | Pas de connexion hors ligne avec ce compte |
| Pas de délégation Kerberos | Le compte ne peut pas être délégué à un autre service |
| TGT de **4 heures** | Les tickets volés expirent vite |

```powershell
Add-ADGroupMember -Identity "Protected Users" -Members "adm0.sysinfo"
Get-ADGroupMember -Identity "Protected Users"
```

> [!WARNING] À réserver aux comptes humains d'administration
> - **Jamais** de compte de service ni de compte ordinateur dans `Protected Users` : ils ont souvent besoin de NTLM ou de délégation.
> - Une connexion **par adresse IP** (`\\192.168.3.10\partage`) passe en NTLM : elle échoue pour un membre de `Protected Users`. Il faut utiliser le **nom** (`\\DC01\partage`).
> - Garder au moins un compte de secours **hors** du groupe.

![ad-tp08-protected-users-ntlm](https://cours.kaya.ovh/active-directory/assets/supports/a759f3537ea06bad89fd.png)
*`net use` avec `adm0.sysinfo` (membre de Protected Users) : par le **nom** `\\DC01`, ça passe (Kerberos). Par l'**adresse IP**, on obtient « System error 1327 — Account restrictions are preventing this user from signing in » (NTLM refusé).*

- [Groupe Protected Users — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/security/credentials-protection-and-management/protected-users-security-group)

---

## 7. Windows LAPS : un mot de passe local différent par machine

Si tous les postes ont le **même** mot de passe pour le compte `Administrateur` local, compromettre un poste donne accès à **tous** les autres : c'est un mouvement latéral gratuit dans le Tier 2.

**Windows LAPS** (*Local Administrator Password Solution*) est intégré à Windows depuis avril 2023 (Windows 10/11, Windows Server 2019 et plus), sans rien installer. Chaque machine :
- génère un mot de passe aléatoire pour son compte administrateur local ;
- le change régulièrement ;
- le stocke **dans son propre objet ordinateur** AD, lisible uniquement par les groupes autorisés.

### Mise en place

```powershell
# 1. Étendre le schéma AD (une seule fois par forêt, en Admins du schéma)
Update-LapsADSchema

# 2. Autoriser les ordinateurs de l'OU à écrire leur propre mot de passe
Set-LapsADComputerSelfPermission -Identity "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"

# 3. Autoriser le support Tier 2 à lire les mots de passe des postes
Set-LapsADReadPasswordPermission -Identity "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab" `
                                 -AllowedPrincipals "FOURNIL\GG_Tier2_Admins"
```

4. GPO liée à `OU=Postes` : `Configuration ordinateur → Stratégies → Modèles d'administration → Système → LAPS`

| Paramètre | Valeur |
|---|---|
| **Configurer le répertoire de sauvegarde des mots de passe** | Activé → *Active Directory* |
| **Paramètres du mot de passe** | Activé → complexité maximale, 16 caractères, 30 jours |
| **Configurer les déchiffreurs de mots de passe autorisés** | Activé → `FOURNIL\GG_Tier2_Admins` |

> [!WARNING] Le mot de passe est chiffré : le droit de lecture ne suffit pas
> Avec un domaine en niveau fonctionnel **2016 ou plus**, Windows LAPS **chiffre** le mot de passe dans AD. Seul le **déchiffreur autorisé** peut le lire, et c'est par défaut **Admins du domaine** :
> - avec seulement `Set-LapsADReadPasswordPermission`, `adm2.jrenard` obtient `DecryptionStatus : Unauthorized` et un mot de passe vide ;
> - avec le paramètre **Configurer les déchiffreurs de mots de passe autorisés** → `GG_Tier2_Admins`, il obtient `DecryptionStatus : Success`.
>
> Un seul déchiffreur par mot de passe : une fois `GG_Tier2_Admins` désigné, ce sont **les Admins du domaine** qui ne peuvent plus le déchiffrer. C'est cohérent avec le tiering : le mot de passe d'un poste appartient au Tier 2.

### Utilisation

```powershell
# Sur le poste : forcer le traitement sans attendre
Invoke-LapsPolicyProcessing

# Depuis le DC ou un poste d'administration : lire le mot de passe
Get-LapsADPassword -Identity "PC-PROD-01" -AsPlainText

# Forcer un nouveau mot de passe (après une intervention, par exemple)
Reset-LapsPassword            # à lancer sur le poste concerné
```

![ad-tp08-laps-adm2](https://cours.kaya.ovh/active-directory/assets/supports/88d6b2e1f4fca4aa322c.png)
*Lecture du mot de passe par `adm2.jrenard` : `Source : EncryptedPassword`, `DecryptionStatus : Success`, `AuthorizedDecryptor : FOURNIL\GG_Tier2_Admins`. La date d'expiration correspond aux 30 jours de la GPO.*

Sur le poste, le journal **Microsoft → Windows → LAPS → Operational** trace chaque rotation : **10018** (*LAPS successfully updated Active Directory with the new password*), puis **10020** (*… updated the local admin account with the new password*).

Dans `dsa.msc`, les propriétés d'un ordinateur géré affichent un onglet **LAPS** (mot de passe et date d'expiration).

- [Windows LAPS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/laps/laps-overview)

---

## 8. Pour aller plus loin (hors périmètre TSSR)

Ces mesures complètent le tiering dans les grandes organisations. Il suffit de savoir qu'elles existent :

| Mesure | Principe |
|---|---|
| **PAW** (*Privileged Access Workstation*) | Un poste dédié à l'administration Tier 0, sans mail ni navigation |
| **Stratégies et silos d'authentification** | Restreindre côté DC (et non plus côté machine) où un compte peut s'authentifier |
| **Comptes de service gérés (gMSA)** | Mot de passe de compte de service géré automatiquement par AD |
| **Audit de l'annuaire** | Outils d'audit comme **PingCastle** ou **ORADAD** (ANSSI) pour mesurer l'exposition du Tier 0 |

---

> [!NOTE] À retenir
>
> - Se connecter **laisse des identifiants** sur la machine : un compte puissant ne va jamais sur une machine moins protégée.
> - **Tier 0** = ce qui contrôle le domaine (DC, AD, hyperviseurs et sauvegardes des DC). **Tier 1** = serveurs. **Tier 2** = postes.
> - **Un compte par niveau** : `adm0.`, `adm1.`, `adm2.`, et un compte quotidien sans droits.
> - Les **GPO d'interdiction d'ouverture de session** font respecter la règle, les **groupes restreints** (« Ce groupe est membre de ») donnent l'admin local au bon niveau.
> - **Protected Users** protège les comptes d'administration humains (pas les comptes de service).
> - **Windows LAPS** donne un mot de passe administrateur local unique à chaque machine.

---

## Résumé commandes

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Créer l'arborescence d'administration | `dsa.msc` | `New-ADOrganizationalUnit`, `New-ADGroup` |
| Interdire la connexion d'un groupe | GPO → Attribution des droits utilisateur | — |
| Donner l'admin local à un groupe | GPO → Groupes restreints | — |
| Protéger un compte admin | `dsa.msc` → Protected Users | `Add-ADGroupMember "Protected Users"` |
| Préparer AD pour LAPS | — | `Update-LapsADSchema`, `Set-LapsADComputerSelfPermission` |
| Lire un mot de passe LAPS | `dsa.msc` → onglet LAPS | `Get-LapsADPassword -AsPlainText` |
| Comptes à privilèges historiques | — | `Get-ADUser -Filter 'adminCount -eq 1'` |
