---
title: "TP Intermédiaire — Déployer l'AD depuis les CSV"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-01-tp-intermediaire-ad.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : **2 h**
> Niveau : **Intermédiaire** — CSV, variables et boucles simples
> Prérequis : **[00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail)** terminé (checkpoint C validé)
> Fichiers fournis : `orga-fournil.csv` et `utilisateurs-fournil.csv` dans `C:\Deploy`

> [!important] Principe de ce TP
> Vous utilisez les CSV comme dans le TP avancé, mais vous ne créez **aucune fonction**.
> Exécutez les blocs dans l'ordre, sur une infrastructure AD vide.

> [!important] Où taper les commandes ?
> 🖥️ **SUR DC01**, dans un terminal PowerShell ouvert **en administrateur**.

---

## Objectif

À partir des deux fichiers CSV, vous allez :

1. créer toutes les OUs ;
2. créer les groupes `G_`, `DL_..._L` et `DL_..._M` ;
3. imbriquer les groupes selon le modèle AGDLP ;
4. créer les dossiers et appliquer les droits NTFS ;
5. créer les 30 utilisateurs et les ajouter à leur groupe.

Ce TP est prévu pour un environnement propre. Si vous relancez les blocs de création, Active Directory indiquera que certains objets existent déjà.

---

# Exercice 1 — Importer les CSV

Placez-vous dans le dossier qui contient les fichiers, chargez le module AD puis importez les données :

```powershell
Set-Location C:\Deploy
Import-Module ActiveDirectory

$dn = (Get-ADDomain).DistinguishedName
$orga = Import-Csv ".\orga-fournil.csv" -Delimiter ","
$utilisateurs = Import-Csv ".\utilisateurs-fournil.csv" -Delimiter ","
```

Vérifiez l'import :

```powershell
$orga | Select-Object -First 3
$utilisateurs | Select-Object -First 3
$orga.Count
$utilisateurs.Count
```

> Résultat attendu : **30 lignes** dans chaque CSV.

---

# Exercice 2 — Créer les OUs

## 2.1 — Structure de base

```powershell
New-ADOrganizationalUnit -Name "Fournil" -Path $dn -ProtectedFromAccidentalDeletion $false

$racine = "OU=Fournil,$dn"

foreach ($type in "Utilisateurs","Groupes","Ordinateurs") {
    New-ADOrganizationalUnit -Name $type -Path $racine -ProtectedFromAccidentalDeletion $false
}
```

## 2.2 — Arborescence du CSV

La même structure est créée sous `Utilisateurs`, `Groupes` et `Ordinateurs`.

```powershell
foreach ($type in "Utilisateurs","Groupes","Ordinateurs") {
    $base = "OU=$type,$racine"

    foreach ($entite in ($orga.Entite | Sort-Object -Unique)) {
        New-ADOrganizationalUnit -Name $entite -Path $base -ProtectedFromAccidentalDeletion $false
        $ouEntite = "OU=$entite,$base"

        $poles = $orga | Where-Object Entite -eq $entite |
            Select-Object -ExpandProperty Poles -Unique

        foreach ($pole in $poles) {
            New-ADOrganizationalUnit -Name $pole -Path $ouEntite -ProtectedFromAccidentalDeletion $false
            $ouPole = "OU=$pole,$ouEntite"

            $services = $orga | Where-Object {
                $_.Entite -eq $entite -and $_.Poles -eq $pole -and $_.Service
            } | Select-Object -ExpandProperty Service -Unique

            foreach ($service in $services) {
                New-ADOrganizationalUnit -Name $service -Path $ouPole -ProtectedFromAccidentalDeletion $false
            }
        }
    }
}
```

Vérifiez :

```powershell
(Get-ADOrganizationalUnit -SearchBase $racine -Filter *).Count
```

> Résultat attendu : **121 OUs**, en comptant l'OU `Fournil` elle-même.

---

# Exercice 3 — Créer et imbriquer les groupes

Rappel :

- `G_` contient les comptes ou les groupes métier ;
- `DL_..._L` porte le droit de lecture ;
- `DL_..._M` porte le droit de modification.

## 3.1 — Niveau entreprise

```powershell
$baseGroupes = "OU=Groupes,$racine"

New-ADGroup -Name "G_fournil" -GroupScope Global -GroupCategory Security -Path $baseGroupes
New-ADGroup -Name "DL_fournil_L" -GroupScope DomainLocal -GroupCategory Security -Path $baseGroupes
New-ADGroup -Name "DL_fournil_M" -GroupScope DomainLocal -GroupCategory Security -Path $baseGroupes

Add-ADGroupMember -Identity "DL_fournil_L" -Members "G_fournil"
```

## 3.2 — Entités, pôles et services

```powershell
foreach ($entite in ($orga.Entite | Sort-Object -Unique)) {
    $nomEntite = "G_$entite"
    $ouEntite = "OU=$entite,$baseGroupes"

    New-ADGroup -Name $nomEntite -GroupScope Global -GroupCategory Security -Path $ouEntite
    New-ADGroup -Name "DL_${entite}_L" -GroupScope DomainLocal -GroupCategory Security -Path $ouEntite
    New-ADGroup -Name "DL_${entite}_M" -GroupScope DomainLocal -GroupCategory Security -Path $ouEntite

    Add-ADGroupMember -Identity "G_fournil" -Members $nomEntite
    Add-ADGroupMember -Identity "DL_${entite}_L" -Members $nomEntite

    $poles = $orga | Where-Object Entite -eq $entite |
        Select-Object -ExpandProperty Poles -Unique

    foreach ($pole in $poles) {
        $nomPole = "G_${entite}_${pole}"
        $ouPole = "OU=$pole,$ouEntite"

        New-ADGroup -Name $nomPole -GroupScope Global -GroupCategory Security -Path $ouPole
        New-ADGroup -Name "DL_${entite}_${pole}_L" -GroupScope DomainLocal -GroupCategory Security -Path $ouPole
        New-ADGroup -Name "DL_${entite}_${pole}_M" -GroupScope DomainLocal -GroupCategory Security -Path $ouPole

        Add-ADGroupMember -Identity $nomEntite -Members $nomPole

        $services = $orga | Where-Object {
            $_.Entite -eq $entite -and $_.Poles -eq $pole -and $_.Service
        } | Select-Object -ExpandProperty Service -Unique

        if (@($services).Count -eq 0) {
            Add-ADGroupMember -Identity "DL_${entite}_${pole}_M" -Members $nomPole
        }
        else {
            Add-ADGroupMember -Identity "DL_${entite}_${pole}_L" -Members $nomPole
        }

        foreach ($service in $services) {
            $nomService = "G_${entite}_${pole}_${service}"
            $ouService = "OU=$service,$ouPole"

            New-ADGroup -Name $nomService -GroupScope Global -GroupCategory Security -Path $ouService
            New-ADGroup -Name "DL_${entite}_${pole}_${service}_L" -GroupScope DomainLocal -GroupCategory Security -Path $ouService
            New-ADGroup -Name "DL_${entite}_${pole}_${service}_M" -GroupScope DomainLocal -GroupCategory Security -Path $ouService

            Add-ADGroupMember -Identity $nomPole -Members $nomService
            Add-ADGroupMember -Identity "DL_${entite}_${pole}_${service}_M" -Members $nomService
        }
    }
}
```

Vérifiez les groupes :

```powershell
(Get-ADGroup -Filter 'Name -like "G_*"' -SearchBase $baseGroupes).Count
(Get-ADGroup -Filter 'Name -like "DL_*"' -SearchBase $baseGroupes).Count

Get-ADGroupMember "G_Laboratoire_fabrication" | Select-Object Name
Get-ADGroupMember "DL_Laboratoire_fabrication_boulangerie_M" | Select-Object Name
```

> Résultat attendu : **40 groupes G_** et **80 groupes DL_**.

---

# Exercice 4 — Créer les dossiers et poser les droits

Pour rester simple, les droits sont appliqués avec `icacls` :

- `(OI)(CI)` : les droits descendent sur les fichiers et sous-dossiers ;
- `RX` : lecture et exécution ;
- `M` : modification ;
- `F` : contrôle total.

## 4.1 — Dossier entreprise

```powershell
New-Item "C:\fournil" -ItemType Directory -Force
icacls "C:\fournil" /inheritance:r
icacls "C:\fournil" /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "DL_fournil_L:(OI)(CI)RX" "DL_fournil_M:(OI)(CI)M"
```

## 4.2 — Dossiers du CSV

```powershell
foreach ($entite in ($orga.Entite | Sort-Object -Unique)) {
    $dossierEntite = "C:\fournil\$entite"
    New-Item $dossierEntite -ItemType Directory -Force
    icacls $dossierEntite /inheritance:r
    icacls $dossierEntite /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "DL_${entite}_L:(OI)(CI)RX" "DL_${entite}_M:(OI)(CI)M"

    $poles = $orga | Where-Object Entite -eq $entite |
        Select-Object -ExpandProperty Poles -Unique

    foreach ($pole in $poles) {
        $dossierPole = "$dossierEntite\$pole"
        New-Item $dossierPole -ItemType Directory -Force
        icacls $dossierPole /inheritance:r
        icacls $dossierPole /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "DL_${entite}_${pole}_L:(OI)(CI)RX" "DL_${entite}_${pole}_M:(OI)(CI)M"

        $services = $orga | Where-Object {
            $_.Entite -eq $entite -and $_.Poles -eq $pole -and $_.Service
        } | Select-Object -ExpandProperty Service -Unique

        foreach ($service in $services) {
            $dossierService = "$dossierPole\$service"
            New-Item $dossierService -ItemType Directory -Force
            icacls $dossierService /inheritance:r
            icacls $dossierService /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "DL_${entite}_${pole}_${service}_L:(OI)(CI)RX" "DL_${entite}_${pole}_${service}_M:(OI)(CI)M"
        }
    }
}
```

Vérifiez un dossier :

```powershell
icacls "C:\fournil\Laboratoire\fabrication\boulangerie"
```

> Vous devez voir `Administrateurs` et `SYSTEM` en contrôle total, le groupe `_L` en lecture et le groupe `_M` en modification.

---

# Exercice 5 — Créer les utilisateurs du CSV

```powershell
foreach ($user in $utilisateurs) {
    $cheminOU = "OU=$($user.Pole),OU=$($user.Entite),OU=Utilisateurs,$racine"

    if ($user.Service) {
        $cheminOU = "OU=$($user.Service),$cheminOU"
    }

    $motDePasse = ConvertTo-SecureString $user.MotDePasse -AsPlainText -Force

    New-ADUser -Name "$($user.Prenom) $($user.Nom)" `
        -GivenName $user.Prenom `
        -Surname $user.Nom `
        -SamAccountName $user.Login `
        -UserPrincipalName $user.Email `
        -EmailAddress $user.Email `
        -Description $user.Fonction `
        -Path $cheminOU `
        -AccountPassword $motDePasse `
        -Enabled $true `
        -ChangePasswordAtLogon $true

    $groupe = "G_$($user.Entite)_$($user.Pole)"

    if ($user.Service) {
        $groupe = "${groupe}_$($user.Service)"
    }

    Add-ADGroupMember -Identity $groupe -Members $user.Login
}
```

Vérifiez :

```powershell
(Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,$racine").Count

Get-ADUser "mlebrun" -Properties MemberOf,Enabled |
    Select-Object Name,SamAccountName,Enabled,MemberOf
```

> Résultat attendu : **30 utilisateurs**, dont `mlebrun`, activés et membres de leur groupe métier.

---

# Exercice 6 — Contrôle final

```powershell
# OUs
(Get-ADOrganizationalUnit -SearchBase $racine -Filter *).Count

# Groupes
(Get-ADGroup -Filter 'Name -like "G_*"' -SearchBase $baseGroupes).Count
(Get-ADGroup -Filter 'Name -like "DL_*"' -SearchBase $baseGroupes).Count

# Utilisateurs
(Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,$racine").Count

# Chaîne AGDLP de Marc Lebrun
Get-ADPrincipalGroupMembership "mlebrun" | Select-Object Name,GroupScope

# Droits sur son dossier de service
icacls "C:\fournil\Laboratoire\fabrication\boulangerie"
```

| Élément | Résultat attendu |
|---------|-----------------|
| OUs, avec `Fournil` | 121 |
| Groupes `G_` | 40 |
| Groupes `DL_` | 80 |
| Utilisateurs | 30 |

> [!success] TP terminé
> Vous avez automatisé le déploiement depuis les CSV avec des boucles simples, sans fonction ni cache.
> L'étape suivante consiste à transformer ces blocs en fonctions réutilisables dans le [TP avancé](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-avance-ad).

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-debutant-ad) | [01.TP-Avance-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-avance-ad) |

> Accueil : [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-0-demarrer-ici)
