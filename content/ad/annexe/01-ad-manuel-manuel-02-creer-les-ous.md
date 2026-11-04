---
title: "Etape 2 — Créer les OUs (Unités d'Organisation)"
---

> Retour vers l'index : [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index)
> Etape précédente : [Manuel-01-Charger-Module-AD](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-01-charger-module-ad) | Etape suivante : [Manuel-03-Creer-les-Groupes](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-03-creer-les-groupes)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

> Structure cible :

![Schema-Structure-OUs](https://cours.kaya.ovh/active-directory/assets/supports/0148111e35e5100b08f6.svg)

---

## Qu'est-ce qu'une OU ?

Une **OU** (Organizational Unit) est un conteneur dans Active Directory. C'est comme un dossier qui permet de ranger et organiser les objets (utilisateurs, groupes, ordinateurs). On peut y appliquer des **GPO** (stratégies de groupe) et **déléguer** l'administration.

## Qu'est-ce qu'un chemin LDAP ?

Chaque objet AD a une adresse unique appelée **Distinguished Name** (DN). Elle se lit **de droite à gauche** (du plus général au plus précis) :

```
OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
│              │               │              │                │           └── le domaine
│              │               │              │                └── l'OU racine de l'entreprise
│              │               │              └── l'OU de type (Utilisateurs)
│              │               └── l'entité
│              └── le pôle
└── le service
```

## La commande expliquée

```powershell
New-ADOrganizationalUnit -Name "Fournil" -Path "DC=ad,DC=fournil,DC=lab"
```

| Paramètre | Rôle |
|-----------|------|
| `-Name` | Le nom de l'OU à créer |
| `-Path` | Le chemin LDAP du conteneur parent |

---

## 2.1 — OU racine et OUs de type

On crée d'abord `Fournil`, puis 3 sous-OUs pour séparer les types d'objets (bonne pratique Microsoft) :

```powershell
# Créer l'OU racine "Fournil" directement sous le domaine
New-ADOrganizationalUnit -Name "Fournil" -Path "DC=ad,DC=fournil,DC=lab"

# Créer les 3 OUs de type sous Fournil
New-ADOrganizationalUnit -Name "Utilisateurs" -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Groupes"      -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Ordinateurs"  -Path "OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

> **Pourquoi séparer ?**
> - `Utilisateurs` : on y appliquera les GPO utilisateurs (scripts de connexion, bureau, etc.)
> - `Ordinateurs` : on y appliquera les GPO machines (pare-feu, mises à jour, etc.)
> - `Groupes` : les groupes de sécurité ne polluent pas les autres OUs

## 2.2 — OUs sous Utilisateurs

On reproduit l'organigramme de l'entreprise :

```powershell
# --- Laboratoire ---
New-ADOrganizationalUnit -Name "Laboratoire" -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Pôles du Laboratoire
New-ADOrganizationalUnit -Name "fabrication"          -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "approvisionnement"    -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "conditionnement"      -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "qualite-hygiene"      -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "maintenance"          -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "communs-laboratoire"  -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-laboratoire" -Path "OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous fabrication
New-ADOrganizationalUnit -Name "boulangerie"          -Path "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "patisserie"           -Path "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "viennoiserie"         -Path "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "communs-fabrication"  -Path "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-fabrication" -Path "OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous approvisionnement
New-ADOrganizationalUnit -Name "achats" -Path "OU=approvisionnement,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "stock"  -Path "OU=approvisionnement,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous conditionnement
New-ADOrganizationalUnit -Name "emballage"   -Path "OU=conditionnement,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "expedition"  -Path "OU=conditionnement,OU=Laboratoire,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# --- Vente ---
New-ADOrganizationalUnit -Name "Vente" -Path "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Pôles de Vente
New-ADOrganizationalUnit -Name "boutique"       -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "commercial"     -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "livraisons"     -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "ressources"     -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "communs-vente"  -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-vente" -Path "OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous boutique
New-ADOrganizationalUnit -Name "accueil-boutique"  -Path "OU=boutique,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "caisse"            -Path "OU=boutique,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "communs-boutique"  -Path "OU=boutique,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-boutique" -Path "OU=boutique,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous commercial
New-ADOrganizationalUnit -Name "ventes-pro"          -Path "OU=commercial,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "marketing"           -Path "OU=commercial,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-commercial" -Path "OU=commercial,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous livraisons
New-ADOrganizationalUnit -Name "tournees" -Path "OU=livraisons,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "planning" -Path "OU=livraisons,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Services sous ressources
New-ADOrganizationalUnit -Name "secretariat"          -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "comptabilite"         -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "rh"                   -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "informatique"         -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "communs-ressources"   -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "direction-ressources" -Path "OU=ressources,OU=Vente,OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

## 2.3 — OUs sous Groupes

On reproduit la **même arborescence** sous `OU=Groupes`. Il suffit de remplacer `OU=Utilisateurs` par `OU=Groupes` dans chaque `-Path`.

> Toutes les commandes sont identiques à la section 2.2, en remplacant `OU=Utilisateurs` par `OU=Groupes` dans le chemin `-Path`.

## 2.4 — OUs sous Ordinateurs

```powershell
New-ADOrganizationalUnit -Name "Laboratoire" -Path "OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
New-ADOrganizationalUnit -Name "Vente"       -Path "OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

## 2.5 — OU Administration (tiering)

Les comptes, groupes et machines d'administration ne vont **pas** sous `Fournil`. On crée une OU `Administration` **directement sous le domaine**, à côté de `Fournil` (voir chapitre 08) :

```
ad.fournil.lab
├── OU=Administration      ← hors de Fournil
│   ├── OU=Tier0  → Comptes, Groupes, PAW, Services
│   ├── OU=Tier1  → Comptes, Groupes, PAW, Serveurs, Services
│   └── OU=Tier2  → Comptes, Groupes, PAW
├── OU=Fournil             ← objets métier (sections 2.1 à 2.4)
└── OU=Domain Controllers  ← les DC restent ici (Tier 0)
```

> [!WARNING] Pourquoi pas sous `Fournil` ?
> Délégations et GPO sont **héritées** par les sous-OUs. Sous `Fournil`, une délégation métier (réinitialisation de mots de passe, par exemple) permettrait de prendre la main sur un compte Tier 0, et les GPO des utilisateurs s'appliqueraient aux comptes d'administration.

```powershell
$domaine = "DC=ad,DC=fournil,DC=lab"
$admin   = "OU=Administration,$domaine"

New-ADOrganizationalUnit -Name "Administration" -Path $domaine

$sousOU = @{
    0 = "Comptes","Groupes","PAW","Services"
    1 = "Comptes","Groupes","PAW","Serveurs","Services"
    2 = "Comptes","Groupes","PAW"
}
foreach ($t in 0,1,2) {
    New-ADOrganizationalUnit -Name "Tier$t" -Path $admin
    foreach ($nom in $sousOU[$t]) {
        New-ADOrganizationalUnit -Name $nom -Path "OU=Tier$t,$admin"
    }
}
```

## Vérification

```powershell
# Voir les 3 OUs de type
Get-ADOrganizationalUnit -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab" -Filter * -SearchScope OneLevel | Select-Object Name

# Compter toutes les OUs créées
(Get-ADOrganizationalUnit -SearchBase "OU=Fournil,DC=ad,DC=fournil,DC=lab" -Filter *).Count
```

```powershell
# Voir les deux branches à la racine du domaine : Administration et Fournil
Get-ADOrganizationalUnit -SearchBase "DC=ad,DC=fournil,DC=lab" -Filter * -SearchScope OneLevel | Select-Object Name

# Voir l'arborescence d'administration
Get-ADOrganizationalUnit -SearchBase "OU=Administration,DC=ad,DC=fournil,DC=lab" -Filter * |
    Select-Object DistinguishedName | Sort-Object DistinguishedName
```
