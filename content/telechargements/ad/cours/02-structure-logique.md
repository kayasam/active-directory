# 02. Structure logique : OUs, outils, délégation

> **Objectif** : Maîtriser les outils d'administration AD, comprendre la structure logique (DN, OU, conteneurs), concevoir et créer une hiérarchie d'unités organisationnelles, déléguer l'administration.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01`

---

## 1. Les outils d'administration Active Directory

### 1.1 Utilisateurs et ordinateurs Active Directory (ADUC)

![ADUC — dsa.msc](https://cours.kaya.ovh/active-directory/assets/supports/external/b81b285d9d3906e431b4.png)

Commande : `dsa.msc`

Permet :
- la gestion des utilisateurs, groupes, ordinateurs
- la gestion des propriétés des objets
- le déplacement des objets dans les OUs
- l'administration courante du domaine

### 1.2 Centre d'administration Active Directory (ADAC)

![ADAC — dsac.exe](https://cours.kaya.ovh/active-directory/assets/supports/external/c3d9abb8c675aa40277f.png)

Commande : `dsac.exe`

Caractéristiques :
- interface plus moderne que ADUC
- gestion de la **corbeille Active Directory**
- historique PowerShell intégré (excellent pour apprendre)

> [Apprendre PowerShell grâce au Centre d'administration Active Directory — IT-Connect](https://www.it-connect.fr/chapitres/apprendre-powershell-grace-au-centre-dadministration-active-directory/)

Activer la corbeille AD (PowerShell) :

```powershell
Enable-ADOptionalFeature `
  -Identity 'Recycle Bin Feature' `
  -Scope ForestOrConfigurationSet `
  -Target 'ad.fournil.lab'
```

### 1.3 Module PowerShell Active Directory

```powershell
Import-Module ActiveDirectory
```

- [Documentation module ActiveDirectory — Microsoft Learn](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/?view=windowsserver2025-ps)

---

## 2. Rappel : forêt et domaine

| Concept | Description | Analogie |
|---------|-------------|---------|
| **Forêt** | Périmètre de sécurité global, partage le schéma AD | L'entreprise entière |
| **Domaine** | Unité d'administration, a son propre DNS | Un site ou une filiale |
| **Arbre** | Ensemble de domaines avec espace de noms contigu | Groupe de filiales liées |

> [!NOTE] Pour un TSSR en PME
> Dans la très grande majorité des entreprises, il n'y a **qu'une seule forêt avec un seul domaine**. Les structures multi-domaines concernent les grandes entreprises avec des filiales autonomes.

- [Forest Design Models — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/forest-design-models)
- [Modèle logique AD DS — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/understanding-the-active-directory-logical-model)

---

## 3. Le Distinguished Name (DN)

Chaque objet Active Directory est identifié par un chemin unique appelé **Distinguished Name**. Il se lit de droite à gauche.

```
CN=Claire Fontaine,OU=Gerance,OU=Direction,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
```

| Composant | Signification |
|-----------|---------------|
| `DC=ad,DC=fournil,DC=lab` | Le domaine `ad.fournil.lab` |
| `OU=Fournil` | OU racine de l'entreprise |
| `OU=Utilisateurs` | Type d'objet : les comptes utilisateurs |
| `OU=Direction` | Pôle Direction |
| `OU=Gerance` | Service Gérance |
| `CN=Claire Fontaine` | Le Common Name de l'objet |

Le DN est indispensable pour :
- les scripts PowerShell (`-Path`, `-Identity`)
- les recherches LDAP
- la compréhension de la structure logique du domaine

```powershell
# Afficher le DN d'un utilisateur
Get-ADUser cfontaine | Select-Object DistinguishedName
```

- [Conventions de nommage AD — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows/win32/ad/naming-properties)

---

## 4. Conteneurs et unités organisationnelles

### Différence fondamentale

| | **Conteneur** | **Unité organisationnelle (OU)** |
|-|---------------|----------------------------------|
| Icône | Dossier jaune simple | Dossier jaune avec livre |
| GPO applicable | ❌ Non | ✅ Oui |
| Délégation | ❌ Limitée | ✅ Oui |
| Créé par | Windows (par défaut) | L'administrateur |
| Exemples | `Computers`, `Users`, `Builtin` | `OU=Direction`, `OU=RH` |

> [!WARNING] Conteneur ≠ OU
> Les conteneurs `Computers` et `Users` créés par défaut **ne sont pas** des OUs. On ne peut pas leur appliquer de GPO. C'est pourquoi on crée ses propres OUs pour organiser les objets.

Les OUs servent à :
- classer les utilisateurs, groupes, ordinateurs, serveurs
- appliquer des **GPO** ciblées
- déléguer l'administration sans donner des droits trop élevés

---

## 5. Concevoir une structure d'OU

### Approches courantes

**Par département** : les OUs reproduisent l'organigramme (Direction, Production, Commercial…). Lisible, mais utilisateurs et ordinateurs d'un même service se retrouvent mélangés.

**Par type d'objet** : une OU pour les utilisateurs, une pour les ordinateurs, une pour les groupes. Simple, et idéal pour cibler les GPO.

### La structure retenue pour Fournil

On combine les deux, sous **une OU racine** au nom de l'entreprise : d'abord le **type d'objet**, puis le **département**.

```
ad.fournil.lab
├── OU=Fournil                ← OU racine de l'entreprise
│   ├── OU=Utilisateurs
│   │   ├── OU=Direction
│   │   ├── OU=Production
│   │   ├── OU=Commercial
│   │   └── OU=Support
│   ├── OU=Groupes
│   └── OU=Ordinateurs
│       ├── OU=Postes
│       └── OU=Serveurs
├── CN=Users                  ← conteneurs par défaut, laissés vides
├── CN=Computers
└── OU=Domain Controllers     ← créée par la promotion, on n'y touche pas
```

Pourquoi une OU racine `Fournil` ?
- tous les objets de l'entreprise sont **au même endroit**, bien séparés des conteneurs par défaut (`Users`, `Computers`, `Builtin`) ;
- une GPO ou une délégation commune à toute l'entreprise se pose **une seule fois**, sur `OU=Fournil` ;
- l'annuaire reste propre si une seconde entité arrive (rachat, filiale) : elle aura sa propre OU racine à côté.

> [!TIP] Bonne pratique
> Séparer toujours les **ordinateurs** des **utilisateurs** dans des OUs distinctes : les GPO ordinateur et utilisateur ont des cycles d'application différents (démarrage machine vs ouverture de session).

> [!NOTE] Et les comptes d'administration ?
> Ils n'iront **pas** sous `OU=Fournil`, mais dans une OU `Administration` placée **à côté**, directement sous le domaine. Une délégation ou une GPO posée sur `OU=Fournil` ne doit jamais pouvoir les atteindre. C'est l'objet du chapitre 08 (tiering).

- [Conception des OUs — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/creating-an-organizational-unit-design)

---

## 6. Créer des unités organisationnelles

### Via `dsa.msc` (GUI)

1. Clic droit sur le domaine (ou sur une OU existante)
2. **Nouveau → Unité d'organisation**
3. Saisir le nom de l'OU
4. Laisser **"Protéger le conteneur contre une suppression accidentelle"** coché

> [!WARNING] Protection contre la suppression
> Cette option est cochée par défaut depuis Windows Server 2008. Pour supprimer une OU protégée, il faut d'abord décocher l'option dans les propriétés avancées (Affichage → Fonctionnalités avancées → propriétés de l'OU → onglet Objet).

### Via PowerShell

```powershell
# Créer l'OU racine Fournil
New-ADOrganizationalUnit -Name "Fournil" -Path "DC=ad,DC=fournil,DC=lab"

# Créer les OUs par type d'objet sous Fournil
New-ADOrganizationalUnit -Name "Utilisateurs" -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Groupes"      -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Ordinateurs"  -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Créer les pôles sous Utilisateurs
New-ADOrganizationalUnit -Name "Direction"  -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Production" -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Support"    -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Créer sans protection contre la suppression
New-ADOrganizationalUnit -Name "Test" -Path "DC=ad,DC=fournil,DC=lab" `
  -ProtectedFromAccidentalDeletion $false

# Lister toutes les OUs
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

- [New-ADOrganizationalUnit — Microsoft Learn](https://learn.microsoft.com/fr-fr/powershell/module/activedirectory/new-adorganizationalunit)

---

## 7. Déplacer des objets dans les OUs

### Via GUI

Dans `dsa.msc` : clic droit sur l'objet → **Déplacer** → sélectionner l'OU de destination.

### Via PowerShell

```powershell
# Déplacer un utilisateur
Move-ADObject -Identity "CN=Claire Fontaine,CN=Users,DC=ad,DC=fournil,DC=lab" `
              -TargetPath "OU=Gerance,OU=Direction,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Déplacer un ordinateur
Move-ADObject -Identity "CN=PC-DIRECTION-01,CN=Computers,DC=ad,DC=fournil,DC=lab" `
              -TargetPath "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

> [!TIP] Redirection des conteneurs par défaut
> On peut rediriger le conteneur `Computers` par défaut vers une OU personnalisée pour que les nouveaux ordinateurs joints au domaine y arrivent directement :
> ```powershell
> redircmp "OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```

---

## 8. Délégation administrative

La délégation permet de confier certaines tâches à un utilisateur ou groupe **sans lui donner les droits d'administrateur du domaine**.

Exemples courants :
- Le responsable RH peut réinitialiser les mots de passe de son OU
- Un technicien peut joindre des ordinateurs au domaine
- L'utilisateur `helpdesk` peut débloquer les comptes dans `OU=Utilisateurs,OU=Fournil`

### Via l'assistant de délégation (GUI)

1. Dans `dsa.msc`, clic droit sur l'OU cible
2. **Déléguer le contrôle...**
3. Ajouter l'utilisateur ou le groupe
4. Choisir parmi les tâches courantes

| Tâche | Usage typique |
|-------|---------------|
| Créer, supprimer et gérer des comptes utilisateur | Responsable RH |
| Réinitialiser les mots de passe | Helpdesk |
| Lire toutes les informations utilisateur | Support niveau 1 |
| Joindre un ordinateur au domaine | Technicien déploiement |

- [Délégation via les OUs — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/plan/delegating-administration-by-using-ou-objects)

---

> [!NOTE] À retenir
>
> - Les **OUs** servent à organiser, appliquer des GPO et déléguer l'administration.
> - Les **conteneurs** par défaut (`Computers`, `Users`) ne supportent pas les GPO : créer ses propres OUs.
> - Le **Distinguished Name (DN)** identifie précisément chaque objet AD — indispensable en PowerShell.
> - `dsa.msc` pour l'administration graphique courante, `dsac.exe` pour les fonctions avancées (corbeille).
> - PowerShell (`New-ADOrganizationalUnit`, `Move-ADObject`) permet d'automatiser la gestion des OUs.

---

## Résumé commandes

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Créer une OU | `dsa.msc` → Nouveau → OU | `New-ADOrganizationalUnit` |
| Lister les OUs | `dsa.msc` | `Get-ADOrganizationalUnit -Filter *` |
| Déplacer un objet | Clic droit → Déplacer | `Move-ADObject` |
| Déléguer | Clic droit → Déléguer le contrôle | — |
| Rediriger `Computers` | — | `redircmp` |
| Afficher le DN | Propriétés → Attribut Editor | `Get-ADUser … \| Select DistinguishedName` |
