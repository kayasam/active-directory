---
title: "Etape 5 — Créer les dossiers et appliquer les permissions NTFS"
---

> Retour vers l'index : [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index)
> Etape précédente : [Manuel-04-Imbriquer-Groupes-AGDLP](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-04-imbriquer-groupes-agdlp) | Etape suivante : [Manuel-06-Creer-les-Utilisateurs](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-06-creer-les-utilisateurs)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

![Schema-Permissions-NTFS](https://cours.kaya.ovh/active-directory/assets/supports/8133a30adce77e3a9309.svg)

---

## Qu'est-ce qu'une ACL ?

L'**ACL** (Access Control List) est la liste des permissions sur un dossier. Chaque entrée dit : "tel groupe a tel droit". On va :
1. Créer le dossier
2. Désactiver l'**héritage** (pour que le dossier ne copie pas les permissions du dossier parent)
3. Supprimer toutes les permissions existantes
4. Ajouter nos propres permissions

---

## 5.1 — Créer l'arborescence de dossiers

```powershell
# Dossier racine
New-Item -Path "C:\fournil" -ItemType Directory -Force

# Entités
New-Item -Path "C:\fournil\Laboratoire" -ItemType Directory -Force
New-Item -Path "C:\fournil\Vente" -ItemType Directory -Force

# Pôles Laboratoire
New-Item -Path "C:\fournil\Laboratoire\fabrication" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\approvisionnement" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\conditionnement" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\qualite-hygiene" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\maintenance" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\communs-laboratoire" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\direction-laboratoire" -ItemType Directory -Force

# Services sous fabrication
New-Item -Path "C:\fournil\Laboratoire\fabrication\boulangerie" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\fabrication\patisserie" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\fabrication\viennoiserie" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\fabrication\communs-fabrication" -ItemType Directory -Force
New-Item -Path "C:\fournil\Laboratoire\fabrication\direction-fabrication" -ItemType Directory -Force

# (continuer pour approvisionnement, conditionnement, Vente, etc.)
```

> **-Force** : ne génère pas d'erreur si le dossier existe déjà

---

## 5.2 — Appliquer les permissions (exemple boulangerie)

### Etape par étape :

```powershell
# 1. Récupérer l'ACL actuelle du dossier
$acl = Get-Acl -Path "C:\fournil\Laboratoire\fabrication\boulangerie"
```

> **Get-Acl** retourne un objet contenant toutes les permissions du dossier

```powershell
# 2. Désactiver l'héritage et supprimer les permissions héritées
$acl.SetAccessRuleProtection($true, $false)
```

> **1er paramètre ($true)** : activer la protection = désactiver l'héritage
> **2ème paramètre ($false)** : ne PAS conserver les permissions héritées = tout supprimer

```powershell
# 3. Supprimer toutes les règles existantes
foreach ($access in $acl.Access) {
    $acl.RemoveAccessRule($access) | Out-Null
}
```

> On part d'une ACL vierge pour être sûr de ce qu'on met

```powershell
# 4. Ajouter les permissions
# Administrateurs : Contrôle total
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Administrateurs",       # QUI : le groupe Administrateurs
    "FullControl",                    # QUOI : contrôle total
    "ContainerInherit,ObjectInherit", # OÙ : sous-dossiers ET fichiers
    "None",                           # PROPAGATION : immédiate
    "Allow"                           # TYPE : autoriser
)))

# SYSTEM : Contrôle total (nécessaire pour que Windows fonctionne)
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)))

# Groupe DL en lecture
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "DL_Laboratoire_fabrication_boulangerie_L", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
)))

# Groupe DL en modification
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    "DL_Laboratoire_fabrication_boulangerie_M", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
)))
```

```powershell
# 5. Appliquer les nouvelles permissions
Set-Acl -Path "C:\fournil\Laboratoire\fabrication\boulangerie" -AclObject $acl
```

> **Répéter** ces 5 étapes pour chaque dossier de l'arborescence.

## Vérification

```powershell
(Get-Acl "C:\fournil\Laboratoire\fabrication\boulangerie").Access |
    Select-Object IdentityReference, FileSystemRights | Format-Table
```
