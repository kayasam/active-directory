---
title: "Procédure de déploiement de l'arborescence Active Directory -- Fournil"
---

## Objectif

Ce document décrit en détail la procédure de déploiement de l'arborescence Active Directory pour l'infrastructure de l'entreprise **Fournil**, une boulangerie dont le domaine est `ad.fournil.lab`. Le script `01-AD-Arborescence.ps1` automatise la création de l'ensemble de la structure organisationnelle dans Active Directory : les unités d'organisation (OUs), les groupes de sécurité suivant le modèle AGDLP, les dossiers partagés avec leurs permissions NTFS, et les comptes utilisateurs.

Le script s'exécute en **4 phases** séquentielles et produit un résumé chiffré à la fin. Ce document explique chaque phase, chaque fonction, chaque commande et chaque paramètre afin qu'un administrateur puisse soit exécuter le script directement, soit reproduire la procédure manuellement étape par étape.

**Serveur concerné :**

| Rôle | Nom | Description |
|------|------|-------------|
| Contrôleur de domaine principal | DC01 | Héberge Active Directory, les dossiers partagés et l'exécution du script |

### Fichiers CSV requis

Le script s'appuie sur deux fichiers CSV :

- **`orga-fournil.csv`** : décrit l'organigramme de l'entreprise avec les colonnes `Entreprise`, `Entite`, `Poles`, `Service`. Le séparateur est la virgule (`,`).
- **`utilisateurs-fournil.csv`** : liste les utilisateurs avec les colonnes `Prenom`, `Nom`, `Entite`, `Pole`, `Service`, `Fonction`, `Login`, `MotDePasse`, `Email`. Le séparateur est la virgule (`,`).

### Structure organisationnelle

L'entreprise Fournil est divisée en deux entités, chacune regroupant plusieurs pôles :

| Entité | Pôles |
|--------|-------|
| **Laboratoire** | fabrication, approvisionnement, conditionnement, qualite-hygiene, maintenance, communs-laboratoire, direction-laboratoire |
| **Vente** | boutique, commercial, livraisons, ressources, communs-vente, direction-vente |

Certains pôles comportent des services (sous-niveaux). Par exemple, le pôle `fabrication` contient les services `boulangerie`, `patisserie`, `viennoiserie`, `communs-fabrication` et `direction-fabrication`.

---

## Prérequis

Avant d'exécuter le script, les conditions suivantes doivent être réunies :

| Prérequis | Vérification | Commande |
|-----------|-------------|----------|
| Windows Server avec rôle AD DS installé | Le serveur DC01 est promu contrôleur de domaine | `Get-ADDomain` |
| Module PowerShell ActiveDirectory disponible | Le module est installé avec le rôle AD DS | `Get-Module -ListAvailable ActiveDirectory` |
| Domaine `ad.fournil.lab` opérationnel | Le domaine répond aux requêtes LDAP | `Get-ADDomain -Identity "ad.fournil.lab"` |
| Fichier `orga-fournil.csv` présent dans le répertoire courant | Le fichier existe et contient les colonnes attendues | `Import-Csv ".\orga-fournil.csv" -Delimiter ","` |
| Fichier `utilisateurs-fournil.csv` présent dans le répertoire courant | Le fichier existe et contient les colonnes attendues | `Import-Csv ".\utilisateurs-fournil.csv" -Delimiter ","` |
| Compte exécutant membre du groupe Admins du domaine | Droits suffisants pour créer des OUs, groupes, utilisateurs et modifier les ACL | `whoami /groups` |
| Exécution depuis le répertoire contenant les fichiers CSV | Les chemins relatifs `.\orga-fournil.csv` et `.\utilisateurs-fournil.csv` doivent être valides | `Set-Location C:\deploy` |

---

## Concepts fondamentaux

Cette section explique les notions de base nécessaires pour comprendre le script. Si vous êtes familier avec Active Directory et PowerShell, vous pouvez passer directement à la section **Fonctions du script**.

### Qu'est-ce qu'une Unité d'Organisation (OU) ?

Une **Unité d'Organisation** (OU, pour *Organizational Unit*) est un conteneur dans Active Directory qui permet d'organiser les objets (utilisateurs, groupes, ordinateurs) en une hiérarchie logique. Pensez-y comme à des dossiers dans un système de fichiers, mais pour les objets AD.

Les OUs servent à :
- **Organiser** : regrouper les objets par département, service, localisation, etc.
- **Déléguer** : attribuer des droits d'administration à un sous-ensemble d'objets (par exemple, permettre au responsable RH de réinitialiser les mots de passe des utilisateurs de son service).
- **Appliquer des stratégies** : lier des GPO (Group Policy Objects) à une OU pour appliquer des configurations spécifiques à ses membres.

Dans notre cas, la hiérarchie des OUs reflète l'organigramme de l'entreprise :

```
Fournil (OU racine)
├── Utilisateurs
│   ├── Laboratoire
│   │   ├── fabrication
│   │   │   ├── boulangerie
│   │   │   ├── patisserie
│   │   │   └── ...
│   │   ├── approvisionnement
│   │   └── ...
│   └── Vente
│       ├── boutique
│       └── ...
├── Groupes
│   ├── Laboratoire
│   │   ├── fabrication
│   │   └── ...
│   └── Vente
│       └── ...
└── Ordinateurs
    ├── Laboratoire
    └── Vente
```

### Distinguished Name (DN) et syntaxe LDAP

Le **Distinguished Name** (DN) est l'adresse unique d'un objet dans Active Directory. C'est l'équivalent du chemin complet d'un fichier dans un système de fichiers.

Un DN est composé de **composantes** séparées par des virgules, lues **de gauche à droite du plus spécifique au plus général** :

```
OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
```

| Composante | Signification | Exemple |
|-----------|---------------|---------|
| `OU=` | Organizational Unit (Unité d'Organisation) | `OU=boulangerie` |
| `DC=` | Domain Component (Composante du domaine) | `DC=ad,DC=fournil,DC=lab` = `ad.fournil.lab` |
| `CN=` | Common Name (Nom commun, pour les objets comme les utilisateurs ou groupes) | `CN=Marc Lebrun` |

**Attention -- ordre inversé :** Contrairement à un chemin de fichier Windows qui se lit de gauche à droite (`C:\fournil\Laboratoire\fabrication`), un DN LDAP se lit **de droite à gauche** pour remonter la hiérarchie. Le composant le plus profond (le plus spécifique) est à gauche, et la racine du domaine est à droite.

Par exemple, pour placer un utilisateur dans l'OU `boulangerie` :

```
Hiérarchie visuelle :         Fournil → Utilisateurs → Laboratoire → fabrication → boulangerie
DN LDAP (inversé) :           OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
```

C'est cette inversion qui rend parfois les DN difficiles à lire pour les débutants, mais c'est la convention standard du protocole LDAP.

### Groupes de sécurité : Global vs DomainLocal

Un **groupe de sécurité** est un objet Active Directory qui regroupe des utilisateurs (ou d'autres groupes) pour leur attribuer des permissions. Il existe trois **étendues** (scopes) de groupes :

| Étendue | Nom anglais | Peut contenir | Peut être utilisé pour |
|---------|-------------|---------------|----------------------|
| **Globale** | Global | Des utilisateurs et des groupes globaux **du même domaine** | Regrouper les utilisateurs par rôle ou département. Ne sert pas directement à attribuer des permissions sur des ressources. |
| **Domaine Local** | DomainLocal | Des utilisateurs et des groupes de **n'importe quel domaine** de la forêt | Attribuer des permissions sur des ressources (dossiers, imprimantes, etc.) **du domaine local**. |
| **Universelle** | Universal | Des utilisateurs et des groupes de **n'importe quel domaine** de la forêt | Utilisé dans les environnements multi-domaines. Non utilisé dans notre script. |

Il existe aussi deux **catégories** de groupes :

| Catégorie | Description |
|-----------|-------------|
| **Security** (Sécurité) | Peut être utilisé pour attribuer des permissions sur des ressources. C'est le type utilisé dans notre script. |
| **Distribution** | Utilisé uniquement pour les listes de distribution email (comme dans Exchange). Ne peut pas être utilisé pour des permissions. |

### Le modèle AGDLP

Le modèle **AGDLP** est une bonne pratique Microsoft pour gérer les permissions dans Active Directory. L'acronyme signifie :

```
A    →    G    →    DL    →    P
Account  Global  DomainLocal  Permission
(Compte) (Groupe) (Groupe)    (Ressource)
```

Le principe est le suivant :

1. **A (Account)** : Le compte utilisateur (par exemple `mlebrun`).
2. **G (Global)** : L'utilisateur est membre d'un groupe **Global** qui représente son rôle/service (par exemple `G_Laboratoire_fabrication_boulangerie`).
3. **DL (DomainLocal)** : Le groupe Global est membre d'un groupe **DomainLocal** qui représente un niveau d'accès sur une ressource (par exemple `DL_Laboratoire_fabrication_boulangerie_M` pour l'accès en modification).
4. **P (Permission)** : Le groupe DomainLocal est utilisé dans les ACL (listes de contrôle d'accès) du dossier partagé (par exemple `C:\fournil\Laboratoire\fabrication\boulangerie`).

**Exemple concret pour l'utilisateur Marc Lebrun (mlebrun) :**

```
mlebrun (Account)
  └── G_Laboratoire_fabrication_boulangerie (Global)
        └── DL_Laboratoire_fabrication_boulangerie_M (DomainLocal → Modify sur le dossier)
        └── DL_Laboratoire_fabrication_L (DomainLocal → ReadAndExecute sur le dossier parent)
        └── DL_Laboratoire_L (DomainLocal → ReadAndExecute sur le dossier entité)
```

**Pourquoi cette complexité ?** Le modèle AGDLP sépare clairement :
- **Qui** a accès (les groupes G regroupent les personnes par rôle).
- **À quoi** et **comment** (les groupes DL définissent les permissions sur les ressources).
- Pour changer les permissions d'un utilisateur, il suffit de le déplacer d'un groupe G à un autre, sans toucher aux ACL des dossiers.
- Pour donner accès à un nouveau dossier, il suffit de créer un nouveau groupe DL et d'y ajouter les groupes G concernés.

### ACL et héritage NTFS

Les **ACL** (Access Control Lists, ou Listes de Contrôle d'Accès) sont les permissions NTFS appliquées aux dossiers et fichiers Windows. Chaque dossier possède une ACL qui liste les règles d'accès : qui peut lire, écrire, modifier, supprimer, etc.

**L'héritage** est le mécanisme par lequel les permissions d'un dossier parent se propagent automatiquement aux sous-dossiers et fichiers enfants. Par défaut, tous les dossiers héritent des permissions de leur parent.

Dans notre script, nous **désactivons l'héritage** sur chaque dossier de pôle/service avec `SetAccessRuleProtection($true, $false)` pour définir des permissions explicites et indépendantes. Cela permet un contrôle fin : chaque dossier a ses propres permissions, sans hériter de celles du parent.

| Paramètre | Valeur | Effet |
|-----------|--------|-------|
| Premier argument | `$true` | Active la protection (désactive l'héritage du parent) |
| Second argument | `$false` | Ne conserve PAS les permissions héritées existantes (les supprime) |

Si le second argument était `$true`, les permissions héritées seraient converties en permissions explicites (copiées). Avec `$false`, on repart d'une feuille blanche.

### La portée `$script:` en PowerShell

En PowerShell, les variables ont une **portée** (scope) qui détermine où elles sont visibles :

| Portée | Description | Exemple |
|--------|-------------|---------|
| Locale (par défaut) | La variable n'existe que dans le bloc ou la fonction en cours | `$maVariable = "valeur"` |
| `$script:` | La variable est accessible dans tout le script (toutes les fonctions) | `$script:processedOUs = @{}` |
| `$global:` | La variable est accessible partout, même après la fin du script | `$global:maVariable = "valeur"` |

Dans notre script, les variables de cache et les compteurs utilisent la portée `$script:` pour être partagés entre toutes les fonctions. Par exemple, quand la fonction `New-OUIfNotExists` incrémente `$script:counts.OUCreated`, cette modification est visible dans le résumé final du script.

Sans le préfixe `$script:`, chaque fonction créerait sa propre copie locale de la variable, et les modifications seraient perdues à la sortie de la fonction.

### Les hashtables `@{}` pour le cache

Une **hashtable** (table de hachage) est une structure de données qui stocke des paires clé-valeur. En PowerShell, on la crée avec la syntaxe `@{}` :

```powershell
$monCache = @{}                  # Crée une hashtable vide
$monCache["cle1"] = "valeur1"    # Ajoute une entrée
$monCache.ContainsKey("cle1")    # Retourne $true si la clé existe
```

Dans notre script, les hashtables servent de **cache** pour éviter de répéter des opérations coûteuses. Par exemple :

```powershell
$script:processedOUs = @{}       # Cache des OUs déjà traitées
$script:processedGroups = @{}    # Cache des groupes déjà traités
$script:processedMembers = @{}   # Cache des appartenances déjà vérifiées
$script:processedFolders = @{}   # Cache des dossiers déjà traités
```

Avant de créer une OU, le script vérifie d'abord `$script:processedOUs.ContainsKey($ouPath)`. Si la clé existe, l'OU a déjà été traitée dans cette exécution et on passe à la suite sans interroger Active Directory. Cela accélère considérablement l'exécution quand le CSV contient de nombreuses lignes qui partagent les mêmes niveaux hiérarchiques.

---

## Fonctions du script

Le script définit 5 fonctions utilitaires, chacune conçue pour être **idempotente** : on peut exécuter le script plusieurs fois sans provoquer d'erreurs ni de doublons.

### Fonction 1 : `New-OUIfNotExists`

#### Objectif

Créer une Unité d'Organisation (OU) dans Active Directory si elle n'existe pas déjà. La fonction vérifie d'abord son cache interne, puis interroge AD, et ne crée l'OU que si nécessaire.

#### Code complet

```powershell
function New-OUIfNotExists {
    param (
        [string]$ouName,
        [string]$parentPath
    )
    $ouPath = "OU=$ouName,$parentPath"
    if ($script:processedOUs.ContainsKey($ouPath)) { return $ouPath }
    try {
        $existingOU = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$($ouPath))" -ErrorAction SilentlyContinue
        if (-not $existingOU) {
            New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
            Write-Host "  [+] OU '$ouName' créée sous '$parentPath'" -ForegroundColor Green
            $script:counts.OUCreated++
        } else {
            Write-Host "  [=] OU '$ouName' existe déjà" -ForegroundColor Yellow
            $script:counts.OUExists++
        }
    } catch {
        Write-Host "  [!] Erreur OU '$ouName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedOUs[$ouPath] = $true
    return $ouPath
}
```

#### Table des paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `$ouName` | `[string]` | Nom de l'OU à créer | `"Laboratoire"` |
| `$parentPath` | `[string]` | DN LDAP du conteneur parent sous lequel créer l'OU | `"OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"` |

#### Explication pas à pas

**Étape 1 -- Construction du DN complet :**

```powershell
$ouPath = "OU=$ouName,$parentPath"
```

Le DN de la nouvelle OU est construit en préfixant `OU=<nom>` devant le chemin parent. Par exemple, si `$ouName = "Laboratoire"` et `$parentPath = "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"`, alors `$ouPath = "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"`.

**Étape 2 -- Vérification du cache :**

```powershell
if ($script:processedOUs.ContainsKey($ouPath)) { return $ouPath }
```

Si cette OU a déjà été traitée dans cette exécution du script (présente dans le cache), on retourne immédiatement son DN sans interroger Active Directory. Cela évite des requêtes réseau inutiles.

**Étape 3 -- Recherche dans Active Directory :**

```powershell
$existingOU = Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$($ouPath))" -ErrorAction SilentlyContinue
```

- `Get-ADOrganizationalUnit` : cmdlet du module ActiveDirectory qui recherche des OUs dans l'annuaire.
- `-LDAPFilter "(distinguishedName=$($ouPath))"` : filtre LDAP qui recherche une OU dont le DN correspond exactement à `$ouPath`. La syntaxe LDAP utilise des parenthèses et le format `(attribut=valeur)`. La sous-expression `$($ouPath)` est nécessaire pour insérer la variable dans la chaîne.
- `-ErrorAction SilentlyContinue` : si l'OU n'est pas trouvée, la cmdlet ne retourne rien et ne génère pas d'erreur visible. Sans ce paramètre, une absence de résultat pourrait afficher un avertissement.

> **Pourquoi `-LDAPFilter` plutôt que `-Filter` ?** Le paramètre `-LDAPFilter` utilise la syntaxe native LDAP, qui est plus rapide et plus fiable pour les recherches par DN exact. Le paramètre `-Filter` utilise une syntaxe PowerShell qui est convertie en LDAP en coulisse, ce qui peut parfois poser des problèmes (voir la section Dépannage sur le bug des filtres).

**Étape 4 -- Création si nécessaire :**

```powershell
New-ADOrganizationalUnit -Name $ouName -Path $parentPath -ErrorAction Stop
```

- `New-ADOrganizationalUnit` : cmdlet qui crée une nouvelle OU dans Active Directory.
- `-Name $ouName` : nom de l'OU (par exemple `"Laboratoire"`). Ce nom apparaîtra dans la console ADUC (Active Directory Users and Computers).
- `-Path $parentPath` : DN du conteneur parent. L'OU sera créée comme enfant de ce conteneur.
- `-ErrorAction Stop` : en cas d'erreur (permissions insuffisantes, parent inexistant, etc.), l'exécution s'arrête immédiatement et l'erreur est capturée par le bloc `catch`.

**Étape 5 -- Mise en cache et retour :**

```powershell
$script:processedOUs[$ouPath] = $true
return $ouPath
```

Le DN de l'OU est ajouté au cache (la valeur `$true` est arbitraire, seule la clé importe) et retourné à l'appelant. Ce DN sera utilisé comme `$parentPath` pour créer les sous-OUs.

#### Équivalent manuel

Pour créer manuellement l'OU `Laboratoire` sous `Utilisateurs` :

```powershell
# Vérifier si l'OU existe
Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab)"

# Si elle n'existe pas, la créer
New-ADOrganizationalUnit -Name "Laboratoire" -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

---

### Fonction 2 : `New-GroupIfNotExists`

#### Objectif

Créer un groupe de sécurité Active Directory (Global ou DomainLocal) dans une OU spécifique, si ce groupe n'existe pas déjà.

#### Code complet

```powershell
function New-GroupIfNotExists {
    param (
        [string]$groupName,
        [string]$groupScope,
        [string]$path,
        [string]$description
    )
    if ($script:processedGroups.ContainsKey($groupName)) { return }
    try {
        $existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -SearchBase $path -ErrorAction SilentlyContinue
        $existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -SearchBase $path -ErrorAction SilentlyContinue
        if (-not $existingGroup) {
            New-ADGroup -Name $groupName -GroupCategory Security -GroupScope $groupScope -Path $path -Description $description -ErrorAction Stop
            Write-Host "  [+] Groupe '$groupName' créé" -ForegroundColor Green
            $script:counts.GroupCreated++
        } else {
            Write-Host "  [=] Groupe '$groupName' existe déjà" -ForegroundColor Yellow
            $script:counts.GroupExists++
        }
    } catch {
        Write-Host "  [!] Erreur groupe '$groupName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedGroups[$groupName] = $true
}
```

#### Table des paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `$groupName` | `[string]` | Nom du groupe à créer | `"G_Laboratoire_fabrication"` |
| `$groupScope` | `[string]` | Étendue du groupe : `"Global"` ou `"DomainLocal"` | `"Global"` |
| `$path` | `[string]` | DN de l'OU dans laquelle créer le groupe | `"OU=fabrication,OU=Laboratoire,OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab"` |
| `$description` | `[string]` | Description du groupe (texte libre) | `"Groupe global pour G_Laboratoire_fabrication"` |

#### Explication pas à pas

**Étape 1 -- Vérification du cache :**

```powershell
if ($script:processedGroups.ContainsKey($groupName)) { return }
```

Si le groupe a déjà été traité, on sort immédiatement de la fonction sans rien faire.

**Étape 2 -- Recherche dans Active Directory :**

```powershell
$existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -SearchBase $path -ErrorAction SilentlyContinue
```

- `Get-ADGroup` : cmdlet qui recherche des groupes dans Active Directory.
- `-Filter { Name -eq $groupName }` : filtre de recherche au format **scriptblock** PowerShell (délimité par des accolades `{}`). Il recherche les groupes dont le nom (`Name`) est exactement égal à `$groupName`. Le scriptblock est converti en filtre LDAP en coulisse par le module ActiveDirectory.

  > **Important :** La syntaxe `-Filter { Name -eq $groupName }` utilise une variable simple (`$groupName`), pas un accès à une propriété d'objet (`$objet.Propriete`). C'est crucial car le moteur de filtrage AD ne supporte pas correctement l'accès aux propriétés dans les scriptblocks. C'est un bug connu qui est documenté dans la section Dépannage.

- `-SearchBase $path` : limite la recherche à l'OU spécifiée et ses sous-OUs. Sans ce paramètre, la recherche se ferait dans tout le domaine, ce qui serait plus lent et pourrait trouver des homonymes dans d'autres OUs.

**Étape 3 -- Création du groupe :**

```powershell
New-ADGroup -Name $groupName -GroupCategory Security -GroupScope $groupScope -Path $path -Description $description -ErrorAction Stop
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Name` | `$groupName` | Nom du groupe (par exemple `"G_Laboratoire_fabrication"`). |
| `-GroupCategory` | `Security` | Catégorie du groupe. `Security` permet d'utiliser le groupe pour attribuer des permissions NTFS. L'alternative serait `Distribution` (pour les listes de diffusion email uniquement). |
| `-GroupScope` | `$groupScope` | Étendue du groupe, passée en paramètre. Valeurs possibles : |
| | `Global` | Le groupe peut contenir des utilisateurs et groupes globaux du même domaine. Utilisé pour regrouper les utilisateurs par rôle (préfixe `G_`). |
| | `DomainLocal` | Le groupe peut contenir des objets de n'importe quel domaine. Utilisé pour attribuer des permissions sur les ressources locales (préfixes `DL_..._L` et `DL_..._M`). |
| | `Universal` | Étendue universelle (non utilisée dans ce script). Pour les environnements multi-domaines. |
| `-Path` | `$path` | DN de l'OU où créer le groupe. Le groupe sera visible dans cette OU dans la console ADUC. |
| `-Description` | `$description` | Description textuelle du groupe, visible dans les propriétés du groupe dans ADUC. |

#### Différence entre Global et DomainLocal dans ce script

Dans notre script, les groupes suivent une convention de nommage stricte :

| Préfixe | Étendue | Rôle | Exemple |
|---------|---------|------|---------|
| `G_` | Global | Regroupe les utilisateurs par rôle/service | `G_Laboratoire_fabrication_boulangerie` |
| `DL_..._L` | DomainLocal | Permission de **Lecture** sur un dossier | `DL_Laboratoire_fabrication_boulangerie_L` |
| `DL_..._M` | DomainLocal | Permission de **Modification** sur un dossier | `DL_Laboratoire_fabrication_boulangerie_M` |

#### Équivalent manuel

```powershell
# Vérifier si le groupe existe
Get-ADGroup -Filter { Name -eq "G_Laboratoire_fabrication" } -SearchBase "OU=fabrication,OU=Laboratoire,OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Si il n'existe pas, le créer
New-ADGroup -Name "G_Laboratoire_fabrication" `
    -GroupCategory Security `
    -GroupScope Global `
    -Path "OU=fabrication,OU=Laboratoire,OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
    -Description "Groupe global pour G_Laboratoire_fabrication"
```

---

### Fonction 3 : `Add-MemberToGroupSafe`

#### Objectif

Ajouter un membre (utilisateur ou groupe) à un groupe Active Directory, en vérifiant d'abord que le membre n'en fait pas déjà partie. Cela évite les erreurs de doublon et rend le script idempotent.

#### Code complet

```powershell
function Add-MemberToGroupSafe {
    param (
        [string]$memberName,
        [string]$groupName
    )
    $key = "$memberName->$groupName"
    if ($script:processedMembers.ContainsKey($key)) { return }
    try {
        $members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
        if ($members -contains $memberName) {
            Write-Host "  [=] '$memberName' déjà membre de '$groupName'" -ForegroundColor Yellow
            $script:counts.MemberExists++
        } else {
            Add-ADGroupMember -Identity $groupName -Members $memberName -ErrorAction Stop
            Write-Host "  [+] '$memberName' ajouté au groupe '$groupName'" -ForegroundColor Green
            $script:counts.MemberAdded++
        }
    } catch {
        Write-Host "  [!] Erreur ajout '$memberName' dans '$groupName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedMembers[$key] = $true
}
```

#### Table des paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `$memberName` | `[string]` | SamAccountName du membre à ajouter (utilisateur ou groupe) | `"mlebrun"` ou `"G_Laboratoire_fabrication"` |
| `$groupName` | `[string]` | Nom du groupe cible | `"DL_Laboratoire_fabrication_boulangerie_M"` |

#### Explication pas à pas

**Étape 1 -- Construction de la clé de cache :**

```powershell
$key = "$memberName->$groupName"
```

La clé est une chaîne unique combinant le membre et le groupe (par exemple `"mlebrun->G_Laboratoire_fabrication_boulangerie"`). Cela permet de mettre en cache chaque combinaison membre/groupe individuellement.

**Étape 2 -- Récupération des membres actuels :**

```powershell
$members = Get-ADGroupMember -Identity $groupName -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName
```

- `Get-ADGroupMember -Identity $groupName` : récupère la liste de tous les membres directs du groupe. Le paramètre `-Identity` accepte le nom du groupe, son DN, son SID ou son GUID.

  > **Pourquoi ne pas utiliser `-Recursive` ?** Le paramètre `-Recursive` de `Get-ADGroupMember` déploie récursivement tous les membres imbriqués (les membres des sous-groupes, les membres des sous-sous-groupes, etc.). Cela peut être très lent dans les grandes structures et n'est pas nécessaire ici : on veut uniquement vérifier l'appartenance **directe** au groupe.

- `| Select-Object -ExpandProperty SamAccountName` : extrait uniquement la propriété `SamAccountName` de chaque objet membre, retournant un tableau simple de chaînes de caractères (par exemple `@("mlebrun", "rdubois", "lmartin")`). Le paramètre `-ExpandProperty` « aplatit » la propriété : au lieu de retourner des objets avec une propriété `SamAccountName`, il retourne directement les valeurs.

**Étape 3 -- Vérification de l'appartenance :**

```powershell
if ($members -contains $memberName) {
```

L'opérateur `-contains` vérifie si le tableau `$members` contient la valeur `$memberName`. C'est une comparaison insensible à la casse par défaut en PowerShell.

**Étape 4 -- Ajout si nécessaire :**

```powershell
Add-ADGroupMember -Identity $groupName -Members $memberName -ErrorAction Stop
```

- `Add-ADGroupMember` : cmdlet qui ajoute un ou plusieurs membres à un groupe AD.
- `-Identity $groupName` : le groupe cible.
- `-Members $memberName` : le ou les membres à ajouter. Peut accepter un tableau pour ajouter plusieurs membres en une seule commande.

#### Équivalent manuel

```powershell
# Lister les membres actuels d'un groupe
Get-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" | Select-Object SamAccountName

# Ajouter un utilisateur au groupe
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" -Members "mlebrun"
```

---

### Fonction 4 : `Set-NTFSPermissions`

#### Objectif

Créer un dossier (s'il n'existe pas) et configurer ses permissions NTFS de manière explicite : désactiver l'héritage, supprimer les permissions existantes, puis ajouter les permissions pour les Administrateurs, SYSTEM, et les deux groupes DomainLocal (lecture et modification).

#### Code complet

```powershell
function Set-NTFSPermissions {
    param (
        [string]$folderPath,
        [string]$dlGroupRead,
        [string]$dlGroupModify
    )
    if ($script:processedFolders.ContainsKey($folderPath)) { return }

    try {
        $folderCreated = $false
        if (-not (Test-Path -Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            Write-Host "  [+] Dossier '$folderPath' créé" -ForegroundColor Green
            $folderCreated = $true
            $script:counts.FolderCreated++
        } else {
            $script:counts.FolderExists++
        }

        $acl = Get-Acl -Path $folderPath

        if (-not $folderCreated) {
            $existingIdentities = $acl.Access | Select-Object -ExpandProperty IdentityReference | ForEach-Object { $_.Value }
            $hasRead = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupRead"
            $hasModify = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupModify"
            $isProtected = $acl.AreAccessRulesProtected
            if ($hasRead -and $hasModify -and $isProtected) {
                Write-Host "  [=] Permissions déjà OK sur '$folderPath'" -ForegroundColor Yellow
                $script:counts.PermSkipped++
                $script:processedFolders[$folderPath] = $true
                return
            }
        }

        $acl.SetAccessRuleProtection($true, $false)
        foreach ($access in $acl.Access) {
            $acl.RemoveAccessRule($access) | Out-Null
        }

        $administrators = "BUILTIN\Administrateurs"
        $system = "NT AUTHORITY\SYSTEM"

        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $administrators, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $system, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $dlGroupRead, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $dlGroupModify, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
        )))

        Set-Acl -Path $folderPath -AclObject $acl
        Write-Host "  [+] Permissions appliquées sur '$folderPath' ($dlGroupRead=L, $dlGroupModify=M)" -ForegroundColor Green
        $script:counts.PermApplied++
    } catch {
        Write-Host "  [!] Erreur permissions '$folderPath' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
    $script:processedFolders[$folderPath] = $true
}
```

#### Table des paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `$folderPath` | `[string]` | Chemin complet du dossier à créer/configurer | `"C:\fournil\Laboratoire\fabrication"` |
| `$dlGroupRead` | `[string]` | Nom du groupe DomainLocal pour la lecture | `"DL_Laboratoire_fabrication_L"` |
| `$dlGroupModify` | `[string]` | Nom du groupe DomainLocal pour la modification | `"DL_Laboratoire_fabrication_M"` |

#### Explication pas à pas

**Étape 1 -- Création du dossier si nécessaire :**

```powershell
if (-not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
```

- `Test-Path` : vérifie si le chemin existe. Retourne `$true` ou `$false`.
- `New-Item -ItemType Directory -Force` : crée le dossier. Le paramètre `-Force` crée les dossiers parents intermédiaires s'ils n'existent pas.
- `| Out-Null` : supprime la sortie de la commande (l'objet `DirectoryInfo` retourné par `New-Item`).

**Étape 2 -- Récupération de l'ACL actuelle :**

```powershell
$acl = Get-Acl -Path $folderPath
```

`Get-Acl` retourne un objet `System.Security.AccessControl.DirectorySecurity` qui contient toutes les règles d'accès du dossier. Cet objet est modifiable en mémoire : on y apporte les changements souhaités, puis on l'applique avec `Set-Acl`.

**Étape 3 -- Vérification des permissions existantes (si le dossier existait déjà) :**

```powershell
$existingIdentities = $acl.Access | Select-Object -ExpandProperty IdentityReference | ForEach-Object { $_.Value }
$hasRead = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupRead"
$hasModify = $existingIdentities -contains "$($script:domainPrefix)\$dlGroupModify"
$isProtected = $acl.AreAccessRulesProtected
```

- `$acl.Access` : collection de toutes les règles d'accès (`FileSystemAccessRule`) du dossier.
- `IdentityReference` : propriété qui contient le compte ou groupe concerné par la règle (par exemple `AD\DL_Laboratoire_fabrication_L`).
- `$script:domainPrefix` : le nom NetBIOS du domaine (par exemple `AD`), récupéré en début de script via `(Get-ADDomain).NetBIOSName`.
- `$acl.AreAccessRulesProtected` : propriété booléenne qui indique si l'héritage est désactivé (`$true`) ou actif (`$false`).

Si les deux groupes sont déjà présents et l'héritage est désactivé, les permissions sont considérées comme correctes et la fonction sort sans modification.

**Étape 4 -- Désactivation de l'héritage et suppression des règles existantes :**

```powershell
$acl.SetAccessRuleProtection($true, $false)
foreach ($access in $acl.Access) {
    $acl.RemoveAccessRule($access) | Out-Null
}
```

- `SetAccessRuleProtection($true, $false)` :
  - Premier argument `$true` : **désactive l'héritage** des permissions du dossier parent. Les permissions ne seront plus transmises automatiquement depuis le parent.
  - Second argument `$false` : **ne conserve PAS** les permissions héritées existantes. Elles sont supprimées. On repart d'une feuille blanche.
- La boucle `foreach` supprime ensuite toutes les règles d'accès restantes (les règles explicites qui existaient éventuellement avant).

**Étape 5 -- Ajout des nouvelles règles d'accès :**

Chaque règle est créée avec le constructeur `FileSystemAccessRule` qui prend 5 arguments :

```powershell
New-Object System.Security.AccessControl.FileSystemAccessRule(
    identité, droits, héritage, propagation, type
)
```

| Argument | Position | Description | Valeurs possibles |
|----------|----------|-------------|-------------------|
| **Identité** | 1er | Le compte ou groupe auquel s'applique la règle | `"BUILTIN\Administrateurs"`, `"NT AUTHORITY\SYSTEM"`, `"DL_Laboratoire_fabrication_L"` |
| **Droits** | 2ème | Le niveau de permission accordé | `FullControl` (tout), `Modify` (modifier, supprimer, lire), `ReadAndExecute` (lire et exécuter), `Read` (lire), `Write` (écrire) |
| **Héritage** | 3ème | Comment la permission se propage aux enfants | `ContainerInherit` (sous-dossiers), `ObjectInherit` (fichiers), les deux combinés = tout le contenu récursivement |
| **Propagation** | 4ème | Modification du comportement d'héritage | `None` (s'applique ici et aux enfants), `InheritOnly` (enfants uniquement), `NoPropagateInherit` (enfants directs uniquement) |
| **Type** | 5ème | Autorisation ou refus | `Allow` (autoriser), `Deny` (refuser) |

Les 4 règles ajoutées :

| Identité | Droits | Effet |
|----------|--------|-------|
| `BUILTIN\Administrateurs` | `FullControl` | Les administrateurs ont un contrôle total sur le dossier et tout son contenu. |
| `NT AUTHORITY\SYSTEM` | `FullControl` | Le compte système Windows a un contrôle total (nécessaire pour le bon fonctionnement du système). |
| `$dlGroupRead` | `ReadAndExecute` | Les membres du groupe DL de lecture peuvent lire et parcourir le contenu du dossier. |
| `$dlGroupModify` | `Modify` | Les membres du groupe DL de modification peuvent lire, écrire, modifier et supprimer des fichiers. |

**Étape 6 -- Application de l'ACL modifiée :**

```powershell
Set-Acl -Path $folderPath -AclObject $acl
```

- `Set-Acl` : cmdlet qui applique l'objet ACL modifié au dossier. C'est cette commande qui écrit réellement les permissions sur le système de fichiers NTFS.

#### Équivalent manuel

```powershell
# Créer le dossier
New-Item -Path "C:\fournil\Laboratoire\fabrication" -ItemType Directory -Force

# Récupérer l'ACL
$acl = Get-Acl "C:\fournil\Laboratoire\fabrication"

# Désactiver l'héritage et supprimer les permissions héritées
$acl.SetAccessRuleProtection($true, $false)

# Supprimer toutes les règles existantes
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

# Ajouter les permissions
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Administrateurs", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "DL_Laboratoire_fabrication_L", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "DL_Laboratoire_fabrication_M", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")))

# Appliquer
Set-Acl "C:\fournil\Laboratoire\fabrication" $acl
```

---

### Fonction 5 : `New-UserIfNotExists`

#### Objectif

Créer un compte utilisateur dans Active Directory avec toutes ses propriétés (nom, prénom, login, email, mot de passe, etc.), dans l'OU appropriée, si l'utilisateur n'existe pas déjà.

#### Code complet

```powershell
function New-UserIfNotExists {
    param (
        [string]$samAccountName,
        [string]$givenName,
        [string]$surname,
        [string]$displayName,
        [string]$upn,
        [SecureString]$password,
        [string]$description,
        [string]$path
    )
    try {
        $existingUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName } -ErrorAction SilentlyContinue
        if (-not $existingUser) {
            New-ADUser `
                -Name $displayName `
                -GivenName $givenName `
                -Surname $surname `
                -SamAccountName $samAccountName `
                -UserPrincipalName $upn `
                -Path $path `
                -AccountPassword $password `
                -ChangePasswordAtLogon $true `
                -Enabled $true `
                -Description $description `
                -ErrorAction Stop
            Write-Host "  [+] Utilisateur '$displayName' ($samAccountName) créé" -ForegroundColor Green
            $script:counts.UserCreated++
        } else {
            Write-Host "  [=] Utilisateur '$samAccountName' existe déjà" -ForegroundColor Yellow
            $script:counts.UserExists++
        }
    } catch {
        Write-Host "  [!] Erreur utilisateur '$samAccountName' : $_" -ForegroundColor Red
        $script:counts.Errors++
    }
}
```

#### Table des paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `$samAccountName` | `[string]` | Login de l'utilisateur (max 20 caractères, pré-Windows 2000) | `"mlebrun"` |
| `$givenName` | `[string]` | Prénom de l'utilisateur | `"Marc"` |
| `$surname` | `[string]` | Nom de famille de l'utilisateur | `"Lebrun"` |
| `$displayName` | `[string]` | Nom affiché dans AD (généralement "Prénom Nom") | `"Marc Lebrun"` |
| `$upn` | `[string]` | User Principal Name, au format email | `"mlebrun@ad.fournil.lab"` |
| `$password` | `[SecureString]` | Mot de passe initial sous forme sécurisée | Résultat de `ConvertTo-SecureString` |
| `$description` | `[string]` | Description/fonction de l'utilisateur | `"Chef Boulanger"` |
| `$path` | `[string]` | DN de l'OU dans laquelle créer l'utilisateur | `"OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"` |

#### Explication pas à pas

**Étape 1 -- Recherche de l'utilisateur existant :**

```powershell
$existingUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName } -ErrorAction SilentlyContinue
```

- `Get-ADUser -Filter { SamAccountName -eq $samAccountName }` : recherche un utilisateur dont le `SamAccountName` correspond exactement.

> **Point important sur le filtre :** Le filtre utilise une variable simple `$samAccountName`, et non un accès à une propriété d'objet comme `$user.Login`. C'est une précaution essentielle car le moteur de filtrage Active Directory de PowerShell a un **bug connu** : il ne résout pas correctement les expressions de type `$objet.Propriete` à l'intérieur des scriptblocks `-Filter {}`. Si vous écrivez `-Filter { SamAccountName -eq $user.Login }`, le filtre reçoit une chaîne vide ou incorrecte et ne trouve jamais l'utilisateur, ce qui provoque la recréation systématique du compte (et une erreur de doublon). La solution est de toujours extraire la valeur dans une variable simple avant de l'utiliser dans le filtre.

**Étape 2 -- Création de l'utilisateur :**

```powershell
New-ADUser `
    -Name $displayName `
    -GivenName $givenName `
    -Surname $surname `
    -SamAccountName $samAccountName `
    -UserPrincipalName $upn `
    -Path $path `
    -AccountPassword $password `
    -ChangePasswordAtLogon $true `
    -Enabled $true `
    -Description $description `
    -ErrorAction Stop
```

**Explication détaillée de chaque paramètre de `New-ADUser` :**

| Paramètre | Valeur | Description détaillée |
|-----------|--------|----------------------|
| `-Name` | `$displayName` | Le **nom commun** (CN) de l'objet utilisateur dans Active Directory. C'est le nom qui apparaît dans la console ADUC. Par exemple `"Marc Lebrun"`. Il doit être unique dans l'OU de destination. |
| `-GivenName` | `$givenName` | Le **prénom** de l'utilisateur. Correspond à l'attribut LDAP `givenName`. Par exemple `"Marc"`. |
| `-Surname` | `$surname` | Le **nom de famille** de l'utilisateur. Correspond à l'attribut LDAP `sn` (surname). Par exemple `"Lebrun"`. |
| `-SamAccountName` | `$samAccountName` | Le **nom de connexion pré-Windows 2000** (aussi appelé « login » ou « logon name »). C'est l'identifiant que l'utilisateur saisit pour se connecter sous la forme `DOMAINE\login`. **Limité à 20 caractères maximum** (contrainte historique de Windows NT). Par exemple `"mlebrun"`. Doit être unique dans tout le domaine. |
| `-UserPrincipalName` | `$upn` | Le **nom principal de l'utilisateur** au format email (`login@domaine`). C'est l'identifiant de connexion moderne. Par exemple `"mlebrun@ad.fournil.lab"`. Doit être unique dans toute la forêt AD. Les utilisateurs peuvent se connecter avec ce format ou avec le format `DOMAINE\login`. |
| `-Path` | `$path` | Le **DN de l'OU** dans laquelle créer l'utilisateur. Par exemple `"OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"`. |
| `-AccountPassword` | `$password` | Le **mot de passe initial** du compte, sous forme de `[SecureString]`. Active Directory refuse les mots de passe en texte clair pour des raisons de sécurité. La conversion est faite avant l'appel via `ConvertTo-SecureString`. |
| `-ChangePasswordAtLogon` | `$true` | Force l'utilisateur à **changer son mot de passe** lors de sa première connexion. C'est une bonne pratique de sécurité : le mot de passe initial (`a12345!`) est temporaire et connu de l'administrateur, il doit être remplacé par un mot de passe personnel. |
| `-Enabled` | `$true` | **Active** le compte immédiatement après sa création. Par défaut, `New-ADUser` crée des comptes désactivés. Avec `$true`, l'utilisateur peut se connecter dès la création du compte. |
| `-Description` | `$description` | **Description** textuelle du compte, souvent utilisée pour indiquer la fonction de l'utilisateur (par exemple `"Chef Boulanger"`). Visible dans les propriétés du compte dans ADUC. |

**Conversion du mot de passe en SecureString (dans l'appelant, pas dans la fonction) :**

```powershell
$securePassword = ConvertTo-SecureString $user.MotDePasse -AsPlainText -Force
```

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `$user.MotDePasse` | `"a12345!"` | Le mot de passe en texte clair lu depuis le CSV. |
| `-AsPlainText` | -- | Indique que l'entrée est une chaîne en texte clair (pas un texte chiffré). Sans ce paramètre, PowerShell attend une chaîne chiffrée. |
| `-Force` | -- | Confirme que l'on accepte de convertir du texte clair en SecureString. PowerShell demande cette confirmation car manipuler des mots de passe en clair est risqué du point de vue de la sécurité. |

Le résultat est un objet `[SecureString]` qui stocke le mot de passe de manière chiffrée en mémoire, ce qu'attend le paramètre `-AccountPassword` de `New-ADUser`.

#### Équivalent manuel

```powershell
# Vérifier si l'utilisateur existe
Get-ADUser -Filter { SamAccountName -eq "mlebrun" }

# Convertir le mot de passe
$pwd = ConvertTo-SecureString "a12345!" -AsPlainText -Force

# Créer l'utilisateur
New-ADUser `
    -Name "Marc Lebrun" `
    -GivenName "Marc" `
    -Surname "Lebrun" `
    -SamAccountName "mlebrun" `
    -UserPrincipalName "mlebrun@ad.fournil.lab" `
    -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" `
    -AccountPassword $pwd `
    -ChangePasswordAtLogon $true `
    -Enabled $true `
    -Description "Chef Boulanger"
```

---

## Phase 1 : Structure de base

### Objectif

Créer l'OU racine `Fournil` et les trois OUs de séparation par type d'objet : `Utilisateurs`, `Groupes` et `Ordinateurs`.

### Pourquoi séparer par type d'objet ?

C'est une **bonne pratique Microsoft** qui offre plusieurs avantages :

1. **Clarté** : un administrateur sait immédiatement où chercher un objet. Les utilisateurs sont dans `Utilisateurs`, les groupes dans `Groupes`, etc.
2. **Stratégies de groupe (GPO)** : les GPO liées à l'OU `Utilisateurs` ne s'appliquent qu'aux utilisateurs, pas aux ordinateurs. Cela évite les effets de bord indésirables.
3. **Délégation** : on peut donner à un helpdesk le droit de réinitialiser les mots de passe dans `Utilisateurs` sans lui donner accès aux `Groupes` ou `Ordinateurs`.
4. **Sécurité** : séparer les objets permet d'appliquer des politiques de sécurité différentes selon le type.

### Commandes exécutées

```powershell
# OU racine : Fournil
$entreprisePath = New-OUIfNotExists -ouName "fournil" -parentPath "DC=ad,DC=fournil,DC=lab"

# OUs de type d'objet sous fournil
$utilisateursBasePath = New-OUIfNotExists -ouName "Utilisateurs" -parentPath $entreprisePath
$groupesBasePath      = New-OUIfNotExists -ouName "Groupes"      -parentPath $entreprisePath
$ordinateursBasePath  = New-OUIfNotExists -ouName "Ordinateurs"  -parentPath $entreprisePath
```

### Structure créée

```
DC=ad,DC=fournil,DC=lab
└── OU=Fournil
    ├── OU=Utilisateurs
    ├── OU=Groupes
    └── OU=Ordinateurs
```

### DN LDAP résultants

| Variable | DN LDAP |
|----------|---------|
| `$entreprisePath` | `OU=Fournil,DC=ad,DC=fournil,DC=lab` |
| `$utilisateursBasePath` | `OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab` |
| `$groupesBasePath` | `OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab` |
| `$ordinateursBasePath` | `OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab` |

---

## Phase 2 : OUs organisationnelles, Groupes, Dossiers et Permissions

### Objectif

Pour chaque ligne du fichier CSV `orga-fournil.csv`, créer la hiérarchie complète des OUs (sous Utilisateurs, Groupes et Ordinateurs), les groupes de sécurité Global et DomainLocal, les dossiers correspondants sur le disque, et configurer les permissions NTFS.

### Lecture du fichier CSV

```powershell
$csvContent = Import-Csv -Path ".\orga-fournil.csv" -Delimiter ','
```

Chaque ligne du CSV est convertie en objet PowerShell avec les propriétés `Entreprise`, `Entite`, `Poles` et `Service`.

### Exemple complet pour une ligne CSV

Prenons la ligne CSV suivante :

```
fournil,Laboratoire,fabrication,boulangerie
```

**Étape 1 -- Construction de la hiérarchie organisationnelle :**

```powershell
$orgParts = @("Laboratoire", "fabrication", "boulangerie")
```

Le script construit un tableau `$orgParts` à partir des colonnes `Entite`, `Poles` et `Service` de la ligne CSV. Les colonnes vides sont ignorées (certains pôles comme `qualite-hygiene` n'ont pas de service).

**Étape 2 -- Création des OUs sous Utilisateurs :**

Le script parcourt `$orgParts` et crée chaque OU en cascade :

```
OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
└── OU=Laboratoire
    └── OU=fabrication
        └── OU=boulangerie
```

Commandes équivalentes :

```powershell
New-OUIfNotExists -ouName "Laboratoire" -parentPath "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-OUIfNotExists -ouName "fabrication" -parentPath "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-OUIfNotExists -ouName "boulangerie" -parentPath "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

**Étape 3 -- Création des OUs sous Groupes :**

Même hiérarchie sous l'OU `Groupes` :

```
OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab
└── OU=Laboratoire
    └── OU=fabrication
        └── OU=boulangerie
```

**Étape 4 -- Création des OUs sous Ordinateurs :**

Même hiérarchie sous l'OU `Ordinateurs`.

**Étape 5 -- Création du groupe Global entreprise et des groupes DL entreprise :**

```powershell
# Groupe Global entreprise (dans l'OU Groupes directement)
New-GroupIfNotExists -groupName "G_fournil" -groupScope "Global" -path $groupesBasePath

# Groupes DomainLocal entreprise
New-GroupIfNotExists -groupName "DL_fournil_L" -groupScope "DomainLocal" -path $groupesBasePath
New-GroupIfNotExists -groupName "DL_fournil_M" -groupScope "DomainLocal" -path $groupesBasePath
```

Et le dossier racine entreprise avec ses permissions :

```powershell
Set-NTFSPermissions -folderPath "C:\fournil" -dlGroupRead "DL_fournil_L" -dlGroupModify "DL_fournil_M"
```

**Étape 6 -- Création des groupes à chaque niveau organisationnel :**

Pour chaque niveau de `$orgParts`, le script crée un triplet de groupes (1 Global + 2 DomainLocal) :

| Niveau | Groupe Global | Groupe DL Lecture | Groupe DL Modification |
|--------|--------------|-------------------|----------------------|
| Entité | `G_Laboratoire` | `DL_Laboratoire_L` | `DL_Laboratoire_M` |
| Pôle | `G_Laboratoire_fabrication` | `DL_Laboratoire_fabrication_L` | `DL_Laboratoire_fabrication_M` |
| Service | `G_Laboratoire_fabrication_boulangerie` | `DL_Laboratoire_fabrication_boulangerie_L` | `DL_Laboratoire_fabrication_boulangerie_M` |

**Étape 7 -- Imbrication des groupes G (child dans parent) :**

Le script imbrique les groupes G en cascade (le groupe enfant est membre du groupe parent) :

```
G_Laboratoire_fabrication_boulangerie  →  membre de  →  G_Laboratoire_fabrication
G_Laboratoire_fabrication              →  membre de  →  G_Laboratoire
G_Laboratoire                          →  membre de  →  G_fournil
```

Cela signifie que tous les utilisateurs de `boulangerie` sont automatiquement membres (par imbrication) de `fabrication`, puis de `Laboratoire`, puis de `fournil`.

**Étape 8 -- Création des dossiers et application des permissions NTFS :**

Pour chaque niveau, un dossier est créé sur le disque :

| Dossier | Groupe DL Lecture | Groupe DL Modification |
|---------|-------------------|----------------------|
| `C:\fournil` | `DL_fournil_L` | `DL_fournil_M` |
| `C:\fournil\Laboratoire` | `DL_Laboratoire_L` | `DL_Laboratoire_M` |
| `C:\fournil\Laboratoire\fabrication` | `DL_Laboratoire_fabrication_L` | `DL_Laboratoire_fabrication_M` |
| `C:\fournil\Laboratoire\fabrication\boulangerie` | `DL_Laboratoire_fabrication_boulangerie_L` | `DL_Laboratoire_fabrication_boulangerie_M` |

Chaque dossier a l'héritage NTFS désactivé et les permissions suivantes :

| Identité | Permission |
|----------|-----------|
| `BUILTIN\Administrateurs` | Contrôle total |
| `NT AUTHORITY\SYSTEM` | Contrôle total |
| Groupe `DL_..._L` | Lecture et exécution |
| Groupe `DL_..._M` | Modification |

---

## Phase 3 : Imbrication des groupes G dans DL

### Objectif

Relier les groupes Global (G) aux groupes DomainLocal (DL) selon la logique suivante :

- Le **dernier niveau** de la hiérarchie (le plus profond, c'est-à-dire le service ou le pôle si pas de service) obtient les droits de **Modification** (`DL_..._M`).
- Les **niveaux parents** obtiennent les droits de **Lecture** (`DL_..._L`).

C'est la partie du modèle AGDLP qui relie les groupes de rôle (G) aux groupes de permission (DL).

### Logique détaillée

Pour chaque ligne CSV, le script parcourt les niveaux organisationnels et imbrique :

```powershell
for ($i = 0; $i -lt $orgParts.Count; $i++) {
    if ($i -eq $orgParts.Count - 1) {
        # Dernier niveau → Modification
        Add-MemberToGroupSafe -memberName $groupName -groupName $dlGroupModify
    } else {
        # Niveaux parents → Lecture
        Add-MemberToGroupSafe -memberName $groupName -groupName $dlGroupRead
    }
}
```

### Exemple complet pour la ligne `fournil,Laboratoire,fabrication,boulangerie`

Les 3 niveaux sont `Laboratoire`, `fabrication`, `boulangerie` :

| Niveau (index) | Groupe G | Imbriqué dans | Type d'accès |
|----------------|----------|---------------|-------------|
| 0 (Laboratoire) -- parent | `G_Laboratoire` | `DL_Laboratoire_L` | **Lecture** |
| 1 (fabrication) -- parent | `G_Laboratoire_fabrication` | `DL_Laboratoire_fabrication_L` | **Lecture** |
| 2 (boulangerie) -- **dernier** | `G_Laboratoire_fabrication_boulangerie` | `DL_Laboratoire_fabrication_boulangerie_M` | **Modification** |

### Chaîne AGDLP complète pour mlebrun

Voici comment l'utilisateur `mlebrun` (boulanger dans Laboratoire > fabrication > boulangerie) obtient ses droits :

```
mlebrun (Account)
│
├── Membre direct de : G_Laboratoire_fabrication_boulangerie (Global)
│   │
│   ├── G_Laboratoire_fabrication_boulangerie est dans DL_Laboratoire_fabrication_boulangerie_M
│   │   └── DL_..._boulangerie_M → Permission Modify sur C:\fournil\Laboratoire\fabrication\boulangerie
│   │
│   ├── G_Laboratoire_fabrication_boulangerie est dans G_Laboratoire_fabrication (imbrication G→G)
│   │   │
│   │   ├── G_Laboratoire_fabrication est dans DL_Laboratoire_fabrication_L
│   │   │   └── DL_..._fabrication_L → Permission ReadAndExecute sur C:\fournil\Laboratoire\fabrication
│   │   │
│   │   └── G_Laboratoire_fabrication est dans G_Laboratoire (imbrication G→G)
│   │       │
│   │       ├── G_Laboratoire est dans DL_Laboratoire_L
│   │       │   └── DL_..._Laboratoire_L → Permission ReadAndExecute sur C:\fournil\Laboratoire
│   │       │
│   │       └── G_Laboratoire est dans G_fournil (imbrication G→G)
│   │           (accès potentiel à C:\fournil si DL_fournil_L est configuré)
```

**Résultat pour mlebrun :**

| Dossier | Permission | Via quel groupe |
|---------|-----------|-----------------|
| `C:\fournil\Laboratoire\fabrication\boulangerie` | **Modify** (modification) | `DL_Laboratoire_fabrication_boulangerie_M` |
| `C:\fournil\Laboratoire\fabrication` | **ReadAndExecute** (lecture) | `DL_Laboratoire_fabrication_L` |
| `C:\fournil\Laboratoire` | **ReadAndExecute** (lecture) | `DL_Laboratoire_L` |

Ainsi, mlebrun peut modifier les fichiers de son service (boulangerie), parcourir le dossier de son pôle (fabrication) et parcourir le dossier de son entité (Laboratoire), mais il ne peut modifier que dans son propre dossier de service.

---

## Phase 4 : Création des utilisateurs

### Objectif

Lire le fichier `utilisateurs-fournil.csv` et créer chaque utilisateur dans son OU appropriée, avec toutes ses propriétés, puis l'ajouter à son groupe Global.

### Lecture du fichier CSV

```powershell
$userCsvContent = Import-Csv -Path ".\utilisateurs-fournil.csv" -Delimiter ','
```

### Traitement de chaque utilisateur

Pour chaque ligne du CSV, le script effectue 3 opérations :

**Étape 1 -- Construction du chemin LDAP de l'utilisateur :**

```powershell
$ouParts = @()
if ($user.Service -and $user.Service -ne "") { $ouParts += "OU=$($user.Service)" }
if ($user.Pole -and $user.Pole -ne "")       { $ouParts += "OU=$($user.Pole)" }
if ($user.Entite -and $user.Entite -ne "")   { $ouParts += "OU=$($user.Entite)" }
$ouParts += "OU=$ouUtilisateurs"
$ouParts += "OU=$entrepriseOU"

$userPath = ($ouParts -join ",") + ",$baseDN"
```

**Attention -- ordre inversé !** Le chemin LDAP est construit **du plus profond au plus général** (Service, puis Pole, puis Entite, puis Utilisateurs, puis fournil, puis le domaine). C'est l'inverse de l'ordre hiérarchique visuel.

Par exemple, pour `mlebrun` (Entite=Laboratoire, Pole=fabrication, Service=boulangerie) :

```
$ouParts = @(
    "OU=boulangerie",          # Service (le plus profond)
    "OU=fabrication",          # Pole
    "OU=Laboratoire",          # Entite
    "OU=Utilisateurs",         # Branche type
    "OU=Fournil"               # OU racine
)

$userPath = "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

Pour un utilisateur sans service (par exemple `jduval` dans `qualite-hygiene`) :

```
$ouParts = @(
    "OU=qualite-hygiene",      # Pole (pas de service)
    "OU=Laboratoire",          # Entite
    "OU=Utilisateurs",
    "OU=Fournil"
)

$userPath = "OU=qualite-hygiene,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

**Étape 2 -- Conversion du mot de passe et création de l'utilisateur :**

```powershell
$securePassword = ConvertTo-SecureString $user.MotDePasse -AsPlainText -Force

New-UserIfNotExists `
    -samAccountName $user.Login `
    -givenName $user.Prenom `
    -surname $user.Nom `
    -displayName "$($user.Prenom) $($user.Nom)" `
    -upn $user.Email `
    -password $securePassword `
    -description $user.Fonction `
    -path $userPath
```

**Étape 3 -- Ajout au groupe Global du service :**

```powershell
$groupParts = @()
if ($user.Entite -and $user.Entite -ne "")   { $groupParts += $user.Entite }
if ($user.Pole -and $user.Pole -ne "")       { $groupParts += $user.Pole }
if ($user.Service -and $user.Service -ne "") { $groupParts += $user.Service }

$groupName = "G_" + ($groupParts -join "_")
Add-MemberToGroupSafe -memberName $user.Login -groupName $groupName
```

Pour `mlebrun` : `$groupName = "G_Laboratoire_fabrication_boulangerie"`.
Pour `jduval` (sans service) : `$groupName = "G_Laboratoire_qualite-hygiene"`.

> **Note :** L'ordre de `$groupParts` est l'ordre hiérarchique normal (Entite, Pole, Service), contrairement à `$ouParts` qui est inversé. C'est parce que le nom du groupe est un identifiant lisible, pas un chemin LDAP.

---

## Vérification

Après l'exécution du script, voici les commandes pour valider le bon fonctionnement de chaque composant.

### Vérifier les OUs

```powershell
# Lister toutes les OUs sous Fournil
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, DistinguishedName |
    Format-Table -AutoSize

# Compter les OUs créées
(Get-ADOrganizationalUnit -Filter * -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab").Count
```

### Vérifier les utilisateurs

```powershell
# Lister tous les utilisateurs sous Fournil
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab" -Properties Description |
    Select-Object SamAccountName, Name, Description, DistinguishedName |
    Format-Table -AutoSize

# Vérifier un utilisateur spécifique
Get-ADUser -Identity "mlebrun" -Properties *
```

### Vérifier les groupes

```powershell
# Lister tous les groupes Global (G_)
Get-ADGroup -Filter { Name -like "G_*" } -SearchBase "OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, GroupScope |
    Format-Table -AutoSize

# Lister tous les groupes DomainLocal (DL_)
Get-ADGroup -Filter { Name -like "DL_*" } -SearchBase "OU=Groupes,OU=Fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, GroupScope |
    Format-Table -AutoSize
```

### Vérifier la chaîne AGDLP pour un utilisateur

```powershell
# Groupes directs de mlebrun
Get-ADPrincipalGroupMembership "mlebrun" | Select-Object Name, GroupScope

# Membres du groupe G_Laboratoire_fabrication_boulangerie
Get-ADGroupMember "G_Laboratoire_fabrication_boulangerie" | Select-Object Name, objectClass

# Groupes dont G_Laboratoire_fabrication_boulangerie est membre
Get-ADPrincipalGroupMembership "G_Laboratoire_fabrication_boulangerie" | Select-Object Name, GroupScope
```

### Vérifier les dossiers

```powershell
# Lister l'arborescence des dossiers
Get-ChildItem "C:\fournil" -Recurse -Directory | Select-Object FullName

# Compter les dossiers créés
(Get-ChildItem "C:\fournil" -Recurse -Directory).Count
```

### Vérifier les permissions NTFS

```powershell
# Voir les permissions d'un dossier
Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie" | Format-List

# Voir les règles d'accès détaillées
(Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").Access |
    Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited |
    Format-Table -AutoSize

# Vérifier que l'héritage est désactivé
(Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").AreAccessRulesProtected
# Doit retourner : True
```

---

## Dépannage

### Module ActiveDirectory manquant

**Symptôme :** `Import-Module : The specified module 'ActiveDirectory' was not loaded because no valid module file was found in any module directory.`

**Cause :** Le module PowerShell ActiveDirectory n'est pas installé. Il est normalement installé automatiquement avec le rôle AD DS.

**Solution :**

```powershell
# Installer les outils d'administration AD
Install-WindowsFeature RSAT-AD-PowerShell

# Vérifier l'installation
Get-Module -ListAvailable ActiveDirectory
```

### Bug du filtre avec accès aux propriétés d'objet

**Symptôme :** Le script tente de recréer des utilisateurs qui existent déjà, ou `Get-ADUser -Filter { SamAccountName -eq $user.Login }` ne trouve aucun résultat alors que l'utilisateur existe.

**Cause :** Le moteur de filtrage AD de PowerShell ne résout pas correctement les expressions `$objet.Propriete` à l'intérieur des scriptblocks `-Filter {}`. L'expression `$user.Login` est évaluée comme une chaîne vide ou le nom de la propriété au lieu de sa valeur.

**Solution :** Toujours extraire la valeur dans une variable simple avant de l'utiliser dans le filtre :

```powershell
# INCORRECT - ne fonctionne pas correctement
$existingUser = Get-ADUser -Filter { SamAccountName -eq $user.Login }

# CORRECT - fonctionne
$samAccountName = $user.Login
$existingUser = Get-ADUser -Filter { SamAccountName -eq $samAccountName }
```

C'est exactement ce que fait le script : les valeurs sont passées en paramètres de fonction (`$samAccountName`) et non accédées directement via `$user.Login` dans le filtre.

### Erreur d'ordre dans le chemin LDAP

**Symptôme :** `New-ADUser : Directory object not found` ou l'utilisateur est créé dans la mauvaise OU.

**Cause :** Le chemin LDAP est construit dans le mauvais ordre. Un chemin LDAP se lit du plus spécifique (à gauche) au plus général (à droite).

**Solution :** Vérifier que l'ordre est bien inversé par rapport à la hiérarchie visuelle :

```
Hiérarchie visuelle :  Fournil → Utilisateurs → Laboratoire → fabrication → boulangerie
Chemin LDAP correct :  OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
```

### Permission refusée (Access Denied)

**Symptôme :** `Access is denied` lors de la création d'OUs, groupes ou utilisateurs, ou lors de l'application des permissions NTFS.

**Cause :** Le compte exécutant le script n'a pas les droits suffisants.

**Solution :**

```powershell
# Vérifier l'appartenance aux groupes
whoami /groups

# Le compte doit être membre de :
# - Admins du domaine (pour la création d'objets AD)
# - Administrateurs (pour la modification des ACL NTFS)

# Exécuter PowerShell en tant qu'administrateur (clic droit > Exécuter en tant qu'administrateur)
```

### Erreur de portée de groupe (Group Scope)

**Symptôme :** `Add-ADGroupMember : The specified group type is invalid` ou `A group with the specified scope cannot be added to another group`.

**Cause :** Les règles d'imbrication des groupes ne sont pas respectées. Un groupe Global ne peut contenir que des utilisateurs et des groupes Globaux du même domaine. Un groupe DomainLocal peut contenir des objets de n'importe quel domaine.

**Règles d'imbrication :**

| Type du conteneur | Peut contenir |
|-------------------|---------------|
| Global | Utilisateurs du même domaine, Groupes Globaux du même domaine |
| DomainLocal | Utilisateurs de tout domaine, Groupes Globaux de tout domaine, Groupes Universels, Groupes DomainLocal du même domaine |
| Universel | Utilisateurs de tout domaine, Groupes Globaux de tout domaine, Groupes Universels |

**Solution :** Vérifier que l'on n'essaie pas d'ajouter un groupe DomainLocal dans un groupe Global (ce n'est pas autorisé). Dans le modèle AGDLP, les groupes G (Global) sont membres des groupes DL (DomainLocal), jamais l'inverse.

### Politique de mot de passe non respectée

**Symptôme :** `New-ADUser : The password does not meet the length, complexity, or history requirement of the domain.`

**Cause :** Le mot de passe dans le CSV (`a12345!`) ne respecte pas la politique de mot de passe du domaine.

**Solution :**

```powershell
# Vérifier la politique de mot de passe du domaine
Get-ADDefaultDomainPasswordPolicy

# Les critères habituels sont :
# - MinPasswordLength : longueur minimale (souvent 7 ou 8 caractères)
# - ComplexityEnabled : si $true, le mot de passe doit contenir au moins 3 des 4 types :
#   majuscules, minuscules, chiffres, caractères spéciaux
# - Le mot de passe ne doit pas contenir le nom de l'utilisateur
```

Le mot de passe `a12345!` contient des minuscules, des chiffres et un caractère spécial (3 types sur 4), et fait 7 caractères. Si la politique exige plus de 7 caractères, il faudra modifier le mot de passe dans le CSV.

---

## Tableaux récapitulatifs

### Groupes créés (G_ -- Global)

| Nom du groupe | Étendue | OU de création | Description |
|---------------|---------|---------------|-------------|
| `G_fournil` | Global | `OU=Groupes,OU=Fournil,...` | Groupe global entreprise |
| `G_Laboratoire` | Global | `OU=Laboratoire,OU=Groupes,OU=Fournil,...` | Groupe global entité Laboratoire |
| `G_Laboratoire_fabrication` | Global | `OU=fabrication,OU=Laboratoire,OU=Groupes,...` | Groupe global pôle fabrication |
| `G_Laboratoire_fabrication_boulangerie` | Global | `OU=boulangerie,OU=fabrication,...` | Groupe global service boulangerie |
| `G_Laboratoire_fabrication_patisserie` | Global | `OU=patisserie,OU=fabrication,...` | Groupe global service patisserie |
| `G_Laboratoire_fabrication_viennoiserie` | Global | `OU=viennoiserie,OU=fabrication,...` | Groupe global service viennoiserie |
| `G_Laboratoire_fabrication_communs-fabrication` | Global | `OU=communs-fabrication,...` | Groupe global service communs-fabrication |
| `G_Laboratoire_fabrication_direction-fabrication` | Global | `OU=direction-fabrication,...` | Groupe global service direction-fabrication |
| `G_Laboratoire_approvisionnement` | Global | `OU=approvisionnement,...` | Groupe global pôle approvisionnement |
| `G_Laboratoire_approvisionnement_achats` | Global | `OU=achats,...` | Groupe global service achats |
| `G_Laboratoire_approvisionnement_stock` | Global | `OU=stock,...` | Groupe global service stock |
| `G_Laboratoire_conditionnement` | Global | `OU=conditionnement,...` | Groupe global pôle conditionnement |
| `G_Laboratoire_conditionnement_emballage` | Global | `OU=emballage,...` | Groupe global service emballage |
| `G_Laboratoire_conditionnement_expedition` | Global | `OU=expedition,...` | Groupe global service expedition |
| `G_Laboratoire_qualite-hygiene` | Global | `OU=qualite-hygiene,...` | Groupe global pôle qualite-hygiene |
| `G_Laboratoire_maintenance` | Global | `OU=maintenance,...` | Groupe global pôle maintenance |
| `G_Laboratoire_communs-laboratoire` | Global | `OU=communs-laboratoire,...` | Groupe global pôle communs-laboratoire |
| `G_Laboratoire_direction-laboratoire` | Global | `OU=direction-laboratoire,...` | Groupe global pôle direction-laboratoire |
| `G_Vente` | Global | `OU=Vente,OU=Groupes,...` | Groupe global entité Vente |
| `G_Vente_boutique` | Global | `OU=boutique,OU=Vente,...` | Groupe global pôle boutique |
| `G_Vente_boutique_accueil-boutique` | Global | `OU=accueil-boutique,...` | Groupe global service accueil-boutique |
| `G_Vente_boutique_caisse` | Global | `OU=caisse,...` | Groupe global service caisse |
| `G_Vente_boutique_communs-boutique` | Global | `OU=communs-boutique,...` | Groupe global service communs-boutique |
| `G_Vente_boutique_direction-boutique` | Global | `OU=direction-boutique,...` | Groupe global service direction-boutique |
| `G_Vente_commercial` | Global | `OU=commercial,OU=Vente,...` | Groupe global pôle commercial |
| `G_Vente_commercial_ventes-pro` | Global | `OU=ventes-pro,...` | Groupe global service ventes-pro |
| `G_Vente_commercial_marketing` | Global | `OU=marketing,...` | Groupe global service marketing |
| `G_Vente_commercial_direction-commercial` | Global | `OU=direction-commercial,...` | Groupe global service direction-commercial |
| `G_Vente_livraisons` | Global | `OU=livraisons,OU=Vente,...` | Groupe global pôle livraisons |
| `G_Vente_livraisons_tournees` | Global | `OU=tournees,...` | Groupe global service tournees |
| `G_Vente_livraisons_planning` | Global | `OU=planning,...` | Groupe global service planning |
| `G_Vente_ressources` | Global | `OU=ressources,OU=Vente,...` | Groupe global pôle ressources |
| `G_Vente_ressources_secretariat` | Global | `OU=secretariat,...` | Groupe global service secretariat |
| `G_Vente_ressources_comptabilite` | Global | `OU=comptabilite,...` | Groupe global service comptabilite |
| `G_Vente_ressources_rh` | Global | `OU=rh,...` | Groupe global service rh |
| `G_Vente_ressources_informatique` | Global | `OU=informatique,...` | Groupe global service informatique |
| `G_Vente_ressources_communs-ressources` | Global | `OU=communs-ressources,...` | Groupe global service communs-ressources |
| `G_Vente_ressources_direction-ressources` | Global | `OU=direction-ressources,...` | Groupe global service direction-ressources |
| `G_Vente_communs-vente` | Global | `OU=communs-vente,...` | Groupe global pôle communs-vente |
| `G_Vente_direction-vente` | Global | `OU=direction-vente,...` | Groupe global pôle direction-vente |

### Groupes créés (DL_ -- DomainLocal)

| Nom du groupe (Lecture) | Nom du groupe (Modification) | Étendue |
|-------------------------|------------------------------|---------|
| `DL_fournil_L` | `DL_fournil_M` | DomainLocal |
| `DL_Laboratoire_L` | `DL_Laboratoire_M` | DomainLocal |
| `DL_Laboratoire_fabrication_L` | `DL_Laboratoire_fabrication_M` | DomainLocal |
| `DL_Laboratoire_fabrication_boulangerie_L` | `DL_Laboratoire_fabrication_boulangerie_M` | DomainLocal |
| `DL_Laboratoire_fabrication_patisserie_L` | `DL_Laboratoire_fabrication_patisserie_M` | DomainLocal |
| `DL_Laboratoire_fabrication_viennoiserie_L` | `DL_Laboratoire_fabrication_viennoiserie_M` | DomainLocal |
| `DL_Laboratoire_fabrication_communs-fabrication_L` | `DL_Laboratoire_fabrication_communs-fabrication_M` | DomainLocal |
| `DL_Laboratoire_fabrication_direction-fabrication_L` | `DL_Laboratoire_fabrication_direction-fabrication_M` | DomainLocal |
| `DL_Laboratoire_approvisionnement_L` | `DL_Laboratoire_approvisionnement_M` | DomainLocal |
| `DL_Laboratoire_approvisionnement_achats_L` | `DL_Laboratoire_approvisionnement_achats_M` | DomainLocal |
| `DL_Laboratoire_approvisionnement_stock_L` | `DL_Laboratoire_approvisionnement_stock_M` | DomainLocal |
| `DL_Laboratoire_conditionnement_L` | `DL_Laboratoire_conditionnement_M` | DomainLocal |
| `DL_Laboratoire_conditionnement_emballage_L` | `DL_Laboratoire_conditionnement_emballage_M` | DomainLocal |
| `DL_Laboratoire_conditionnement_expedition_L` | `DL_Laboratoire_conditionnement_expedition_M` | DomainLocal |
| `DL_Laboratoire_qualite-hygiene_L` | `DL_Laboratoire_qualite-hygiene_M` | DomainLocal |
| `DL_Laboratoire_maintenance_L` | `DL_Laboratoire_maintenance_M` | DomainLocal |
| `DL_Laboratoire_communs-laboratoire_L` | `DL_Laboratoire_communs-laboratoire_M` | DomainLocal |
| `DL_Laboratoire_direction-laboratoire_L` | `DL_Laboratoire_direction-laboratoire_M` | DomainLocal |
| `DL_Vente_L` | `DL_Vente_M` | DomainLocal |
| `DL_Vente_boutique_L` | `DL_Vente_boutique_M` | DomainLocal |
| `DL_Vente_boutique_accueil-boutique_L` | `DL_Vente_boutique_accueil-boutique_M` | DomainLocal |
| `DL_Vente_boutique_caisse_L` | `DL_Vente_boutique_caisse_M` | DomainLocal |
| `DL_Vente_boutique_communs-boutique_L` | `DL_Vente_boutique_communs-boutique_M` | DomainLocal |
| `DL_Vente_boutique_direction-boutique_L` | `DL_Vente_boutique_direction-boutique_M` | DomainLocal |
| `DL_Vente_commercial_L` | `DL_Vente_commercial_M` | DomainLocal |
| `DL_Vente_commercial_ventes-pro_L` | `DL_Vente_commercial_ventes-pro_M` | DomainLocal |
| `DL_Vente_commercial_marketing_L` | `DL_Vente_commercial_marketing_M` | DomainLocal |
| `DL_Vente_commercial_direction-commercial_L` | `DL_Vente_commercial_direction-commercial_M` | DomainLocal |
| `DL_Vente_livraisons_L` | `DL_Vente_livraisons_M` | DomainLocal |
| `DL_Vente_livraisons_tournees_L` | `DL_Vente_livraisons_tournees_M` | DomainLocal |
| `DL_Vente_livraisons_planning_L` | `DL_Vente_livraisons_planning_M` | DomainLocal |
| `DL_Vente_ressources_L` | `DL_Vente_ressources_M` | DomainLocal |
| `DL_Vente_ressources_secretariat_L` | `DL_Vente_ressources_secretariat_M` | DomainLocal |
| `DL_Vente_ressources_comptabilite_L` | `DL_Vente_ressources_comptabilite_M` | DomainLocal |
| `DL_Vente_ressources_rh_L` | `DL_Vente_ressources_rh_M` | DomainLocal |
| `DL_Vente_ressources_informatique_L` | `DL_Vente_ressources_informatique_M` | DomainLocal |
| `DL_Vente_ressources_communs-ressources_L` | `DL_Vente_ressources_communs-ressources_M` | DomainLocal |
| `DL_Vente_ressources_direction-ressources_L` | `DL_Vente_ressources_direction-ressources_M` | DomainLocal |
| `DL_Vente_communs-vente_L` | `DL_Vente_communs-vente_M` | DomainLocal |
| `DL_Vente_direction-vente_L` | `DL_Vente_direction-vente_M` | DomainLocal |

### Dossiers NTFS créés avec permissions

| Dossier | Groupe DL Lecture (ReadAndExecute) | Groupe DL Modification (Modify) |
|---------|-----------------------------------|--------------------------------|
| `C:\fournil` | `DL_fournil_L` | `DL_fournil_M` |
| `C:\fournil\Laboratoire` | `DL_Laboratoire_L` | `DL_Laboratoire_M` |
| `C:\fournil\Laboratoire\fabrication` | `DL_Laboratoire_fabrication_L` | `DL_Laboratoire_fabrication_M` |
| `C:\fournil\Laboratoire\fabrication\boulangerie` | `DL_Laboratoire_fabrication_boulangerie_L` | `DL_Laboratoire_fabrication_boulangerie_M` |
| `C:\fournil\Laboratoire\fabrication\patisserie` | `DL_Laboratoire_fabrication_patisserie_L` | `DL_Laboratoire_fabrication_patisserie_M` |
| `C:\fournil\Laboratoire\fabrication\viennoiserie` | `DL_Laboratoire_fabrication_viennoiserie_L` | `DL_Laboratoire_fabrication_viennoiserie_M` |
| `C:\fournil\Laboratoire\fabrication\communs-fabrication` | `DL_Laboratoire_fabrication_communs-fabrication_L` | `DL_Laboratoire_fabrication_communs-fabrication_M` |
| `C:\fournil\Laboratoire\fabrication\direction-fabrication` | `DL_Laboratoire_fabrication_direction-fabrication_L` | `DL_Laboratoire_fabrication_direction-fabrication_M` |
| `C:\fournil\Laboratoire\approvisionnement` | `DL_Laboratoire_approvisionnement_L` | `DL_Laboratoire_approvisionnement_M` |
| `C:\fournil\Laboratoire\approvisionnement\achats` | `DL_Laboratoire_approvisionnement_achats_L` | `DL_Laboratoire_approvisionnement_achats_M` |
| `C:\fournil\Laboratoire\approvisionnement\stock` | `DL_Laboratoire_approvisionnement_stock_L` | `DL_Laboratoire_approvisionnement_stock_M` |
| `C:\fournil\Laboratoire\conditionnement` | `DL_Laboratoire_conditionnement_L` | `DL_Laboratoire_conditionnement_M` |
| `C:\fournil\Laboratoire\conditionnement\emballage` | `DL_Laboratoire_conditionnement_emballage_L` | `DL_Laboratoire_conditionnement_emballage_M` |
| `C:\fournil\Laboratoire\conditionnement\expedition` | `DL_Laboratoire_conditionnement_expedition_L` | `DL_Laboratoire_conditionnement_expedition_M` |
| `C:\fournil\Laboratoire\qualite-hygiene` | `DL_Laboratoire_qualite-hygiene_L` | `DL_Laboratoire_qualite-hygiene_M` |
| `C:\fournil\Laboratoire\maintenance` | `DL_Laboratoire_maintenance_L` | `DL_Laboratoire_maintenance_M` |
| `C:\fournil\Laboratoire\communs-laboratoire` | `DL_Laboratoire_communs-laboratoire_L` | `DL_Laboratoire_communs-laboratoire_M` |
| `C:\fournil\Laboratoire\direction-laboratoire` | `DL_Laboratoire_direction-laboratoire_L` | `DL_Laboratoire_direction-laboratoire_M` |
| `C:\fournil\Vente` | `DL_Vente_L` | `DL_Vente_M` |
| `C:\fournil\Vente\boutique` | `DL_Vente_boutique_L` | `DL_Vente_boutique_M` |
| `C:\fournil\Vente\boutique\accueil-boutique` | `DL_Vente_boutique_accueil-boutique_L` | `DL_Vente_boutique_accueil-boutique_M` |
| `C:\fournil\Vente\boutique\caisse` | `DL_Vente_boutique_caisse_L` | `DL_Vente_boutique_caisse_M` |
| `C:\fournil\Vente\boutique\communs-boutique` | `DL_Vente_boutique_communs-boutique_L` | `DL_Vente_boutique_communs-boutique_M` |
| `C:\fournil\Vente\boutique\direction-boutique` | `DL_Vente_boutique_direction-boutique_L` | `DL_Vente_boutique_direction-boutique_M` |
| `C:\fournil\Vente\commercial` | `DL_Vente_commercial_L` | `DL_Vente_commercial_M` |
| `C:\fournil\Vente\commercial\ventes-pro` | `DL_Vente_commercial_ventes-pro_L` | `DL_Vente_commercial_ventes-pro_M` |
| `C:\fournil\Vente\commercial\marketing` | `DL_Vente_commercial_marketing_L` | `DL_Vente_commercial_marketing_M` |
| `C:\fournil\Vente\commercial\direction-commercial` | `DL_Vente_commercial_direction-commercial_L` | `DL_Vente_commercial_direction-commercial_M` |
| `C:\fournil\Vente\livraisons` | `DL_Vente_livraisons_L` | `DL_Vente_livraisons_M` |
| `C:\fournil\Vente\livraisons\tournees` | `DL_Vente_livraisons_tournees_L` | `DL_Vente_livraisons_tournees_M` |
| `C:\fournil\Vente\livraisons\planning` | `DL_Vente_livraisons_planning_L` | `DL_Vente_livraisons_planning_M` |
| `C:\fournil\Vente\ressources` | `DL_Vente_ressources_L` | `DL_Vente_ressources_M` |
| `C:\fournil\Vente\ressources\secretariat` | `DL_Vente_ressources_secretariat_L` | `DL_Vente_ressources_secretariat_M` |
| `C:\fournil\Vente\ressources\comptabilite` | `DL_Vente_ressources_comptabilite_L` | `DL_Vente_ressources_comptabilite_M` |
| `C:\fournil\Vente\ressources\rh` | `DL_Vente_ressources_rh_L` | `DL_Vente_ressources_rh_M` |
| `C:\fournil\Vente\ressources\informatique` | `DL_Vente_ressources_informatique_L` | `DL_Vente_ressources_informatique_M` |
| `C:\fournil\Vente\ressources\communs-ressources` | `DL_Vente_ressources_communs-ressources_L` | `DL_Vente_ressources_communs-ressources_M` |
| `C:\fournil\Vente\ressources\direction-ressources` | `DL_Vente_ressources_direction-ressources_L` | `DL_Vente_ressources_direction-ressources_M` |
| `C:\fournil\Vente\communs-vente` | `DL_Vente_communs-vente_L` | `DL_Vente_communs-vente_M` |
| `C:\fournil\Vente\direction-vente` | `DL_Vente_direction-vente_L` | `DL_Vente_direction-vente_M` |

> **Rappel :** Chaque dossier a également les permissions `FullControl` pour `BUILTIN\Administrateurs` et `NT AUTHORITY\SYSTEM`, et l'héritage est désactivé.

### Utilisateurs créés (30 comptes)

| Prénom | Nom | Login | Entité | Pôle | Service | Fonction | Groupe Global |
|--------|-----|-------|--------|------|---------|----------|---------------|
| Claire | Fontaine | `cfontaine` | Laboratoire | direction-laboratoire | -- | Directrice Laboratoire | `G_Laboratoire_direction-laboratoire` |
| Marc | Lebrun | `mlebrun` | Laboratoire | fabrication | boulangerie | Chef Boulanger | `G_Laboratoire_fabrication_boulangerie` |
| Romain | Dubois | `rdubois` | Laboratoire | fabrication | boulangerie | Boulanger | `G_Laboratoire_fabrication_boulangerie` |
| Lucie | Martin | `lmartin` | Laboratoire | fabrication | boulangerie | Boulangere | `G_Laboratoire_fabrication_boulangerie` |
| Sophie | Dupont | `sdupont` | Laboratoire | fabrication | patisserie | Chef Patissiere | `G_Laboratoire_fabrication_patisserie` |
| Emilie | Bernard | `ebernard` | Laboratoire | fabrication | patisserie | Patissiere | `G_Laboratoire_fabrication_patisserie` |
| Paul | Thomas | `pthomas` | Laboratoire | fabrication | viennoiserie | Viennoisier | `G_Laboratoire_fabrication_viennoiserie` |
| Kevin | Garnier | `kgarnier` | Laboratoire | fabrication | direction-fabrication | Responsable Fabrication | `G_Laboratoire_fabrication_direction-fabrication` |
| Olivier | Leroy | `oleroy` | Laboratoire | approvisionnement | achats | Responsable Achats | `G_Laboratoire_approvisionnement_achats` |
| Mathieu | Blanc | `mblanc` | Laboratoire | approvisionnement | stock | Magasinier | `G_Laboratoire_approvisionnement_stock` |
| Nadine | Richard | `nrichard` | Laboratoire | conditionnement | emballage | Operatrice Emballage | `G_Laboratoire_conditionnement_emballage` |
| Celine | Simon | `csimon` | Laboratoire | conditionnement | expedition | Responsable Expedition | `G_Laboratoire_conditionnement_expedition` |
| Jerome | Duval | `jduval` | Laboratoire | qualite-hygiene | -- | Responsable Qualite | `G_Laboratoire_qualite-hygiene` |
| Florian | Petit | `fpetit` | Laboratoire | maintenance | -- | Technicien Maintenance | `G_Laboratoire_maintenance` |
| Gaelle | Renaud | `grenaud` | Vente | direction-vente | -- | Directrice Vente | `G_Vente_direction-vente` |
| Amelie | Girard | `agirard` | Vente | boutique | accueil-boutique | Vendeuse | `G_Vente_boutique_accueil-boutique` |
| Camille | Perrin | `cperrin` | Vente | boutique | caisse | Caissiere | `G_Vente_boutique_caisse` |
| Isabelle | Faure | `ifaure` | Vente | boutique | direction-boutique | Responsable Boutique | `G_Vente_boutique_direction-boutique` |
| Thomas | Vidal | `tvidal` | Vente | commercial | ventes-pro | Responsable Commercial | `G_Vente_commercial_ventes-pro` |
| David | Meyer | `dmeyer` | Vente | commercial | ventes-pro | Commercial | `G_Vente_commercial_ventes-pro` |
| Hugo | Lopez | `hlopez` | Vente | commercial | marketing | Charge de Marketing | `G_Vente_commercial_marketing` |
| Pierre | Aubert | `paubert` | Vente | commercial | direction-commercial | Directeur Commercial | `G_Vente_commercial_direction-commercial` |
| Baptiste | Moreau | `bmoreau` | Vente | livraisons | tournees | Chauffeur-Livreur | `G_Vente_livraisons_tournees` |
| Thierry | Roux | `troux` | Vente | livraisons | tournees | Chauffeur-Livreur | `G_Vente_livraisons_tournees` |
| Victor | Noel | `vnoel` | Vente | livraisons | planning | Responsable Planning | `G_Vente_livraisons_planning` |
| Adele | Mercier | `amercier` | Vente | ressources | secretariat | Secretaire | `G_Vente_ressources_secretariat` |
| Nathalie | Bouchard | `nbouchard` | Vente | ressources | comptabilite | Comptable | `G_Vente_ressources_comptabilite` |
| Julie | Renard | `jrenard` | Vente | ressources | rh | Gestionnaire RH | `G_Vente_ressources_rh` |
| Luc | Morin | `lmorin` | Vente | ressources | informatique | Administrateur Systemes | `G_Vente_ressources_informatique` |
| Laura | Morin | `lmorin2` | Vente | ressources | direction-ressources | Directrice Ressources | `G_Vente_ressources_direction-ressources` |

> **Note :** Les utilisateurs sans service (comme `cfontaine`, `jduval`, `fpetit`, `grenaud`) sont placés directement dans l'OU de leur pôle sous la branche Utilisateurs, et sont membres du groupe G de leur pôle (par exemple `G_Laboratoire_direction-laboratoire`).
