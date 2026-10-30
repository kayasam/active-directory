---
title: "Etape 6 — Créer les utilisateurs"
---

> Retour vers l'index : [Index AD Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-00-index)
> Etape précédente : [Manuel-05-Permissions-NTFS](https://cours.kaya.ovh/active-directory/ad/annexe/01-ad-manuel-manuel-05-permissions-ntfs)

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

---

## La commande expliquée (exemple Marc Lebrun)

### Convertir le mot de passe

```powershell
$mdp = ConvertTo-SecureString "a12345!" -AsPlainText -Force
```

> **ConvertTo-SecureString** : transforme du texte en chaîne sécurisée (chiffrée en mémoire)
> **-AsPlainText** : on part de texte en clair
> **-Force** : confirme qu'on accepte de convertir du texte en clair

### Créer le compte

```powershell
New-ADUser `
    -Name "Marc Lebrun" `
    -GivenName "Marc" `
    -Surname "Lebrun" `
    -SamAccountName "mlebrun" `
    -UserPrincipalName "mlebrun@ad.fournil.lab" `
    -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" `
    -AccountPassword $mdp `
    -ChangePasswordAtLogon $true `
    -Enabled $true `
    -Description "Chef Boulanger"
```

| Paramètre | Rôle |
|-----------|------|
| `-Name` | Nom complet affiché dans AD |
| `-GivenName` / `-Surname` | Prénom / Nom de famille |
| `-SamAccountName` | Login court (max 20 car., format pré-Windows 2000) |
| `-UserPrincipalName` | Login au format email (utilisé pour se connecter) |
| `-Path` | L'OU où créer le compte (dans la branche Utilisateurs) |
| `-AccountPassword` | Doit être un **SecureString**, pas du texte |
| `-ChangePasswordAtLogon $true` | Oblige à changer le mot de passe à la 1ère connexion |
| `-Enabled $true` | Le compte est activé immédiatement |

### Ajouter au groupe

```powershell
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" -Members "mlebrun"
```

> Marc est ajouté au groupe le plus profond. Grâce à l'imbrication AGDLP, il hérite automatiquement des accès de tous les niveaux supérieurs.

---

## Tous les utilisateurs

```powershell
$mdp = ConvertTo-SecureString "a12345!" -AsPlainText -Force

# === LABORATOIRE ===

# Claire Fontaine — Directrice Laboratoire
New-ADUser -Name "Claire Fontaine" -GivenName "Claire" -Surname "Fontaine" -SamAccountName "cfontaine" -UserPrincipalName "cfontaine@ad.fournil.lab" -Path "OU=direction-laboratoire,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Directrice Laboratoire"
Add-ADGroupMember -Identity "G_Laboratoire_direction-laboratoire" -Members "cfontaine"

# Marc Lebrun — Chef Boulanger
New-ADUser -Name "Marc Lebrun" -GivenName "Marc" -Surname "Lebrun" -SamAccountName "mlebrun" -UserPrincipalName "mlebrun@ad.fournil.lab" -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Chef Boulanger"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" -Members "mlebrun"

# Romain Dubois — Boulanger
New-ADUser -Name "Romain Dubois" -GivenName "Romain" -Surname "Dubois" -SamAccountName "rdubois" -UserPrincipalName "rdubois@ad.fournil.lab" -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Boulanger"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" -Members "rdubois"

# Lucie Martin — Boulangere
New-ADUser -Name "Lucie Martin" -GivenName "Lucie" -Surname "Martin" -SamAccountName "lmartin" -UserPrincipalName "lmartin@ad.fournil.lab" -Path "OU=boulangerie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Boulangere"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_boulangerie" -Members "lmartin"

# Sophie Dupont — Chef Patissiere
New-ADUser -Name "Sophie Dupont" -GivenName "Sophie" -Surname "Dupont" -SamAccountName "sdupont" -UserPrincipalName "sdupont@ad.fournil.lab" -Path "OU=patisserie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Chef Patissiere"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_patisserie" -Members "sdupont"

# Emilie Bernard — Patissiere
New-ADUser -Name "Emilie Bernard" -GivenName "Emilie" -Surname "Bernard" -SamAccountName "ebernard" -UserPrincipalName "ebernard@ad.fournil.lab" -Path "OU=patisserie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Patissiere"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_patisserie" -Members "ebernard"

# Paul Thomas — Viennoisier
New-ADUser -Name "Paul Thomas" -GivenName "Paul" -Surname "Thomas" -SamAccountName "pthomas" -UserPrincipalName "pthomas@ad.fournil.lab" -Path "OU=viennoiserie,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Viennoisier"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_viennoiserie" -Members "pthomas"

# Kevin Garnier — Responsable Fabrication
New-ADUser -Name "Kevin Garnier" -GivenName "Kevin" -Surname "Garnier" -SamAccountName "kgarnier" -UserPrincipalName "kgarnier@ad.fournil.lab" -Path "OU=direction-fabrication,OU=fabrication,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Fabrication"
Add-ADGroupMember -Identity "G_Laboratoire_fabrication_direction-fabrication" -Members "kgarnier"

# Olivier Leroy — Responsable Achats
New-ADUser -Name "Olivier Leroy" -GivenName "Olivier" -Surname "Leroy" -SamAccountName "oleroy" -UserPrincipalName "oleroy@ad.fournil.lab" -Path "OU=achats,OU=approvisionnement,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Achats"
Add-ADGroupMember -Identity "G_Laboratoire_approvisionnement_achats" -Members "oleroy"

# Mathieu Blanc — Magasinier
New-ADUser -Name "Mathieu Blanc" -GivenName "Mathieu" -Surname "Blanc" -SamAccountName "mblanc" -UserPrincipalName "mblanc@ad.fournil.lab" -Path "OU=stock,OU=approvisionnement,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Magasinier"
Add-ADGroupMember -Identity "G_Laboratoire_approvisionnement_stock" -Members "mblanc"

# Nadine Richard — Operatrice Emballage
New-ADUser -Name "Nadine Richard" -GivenName "Nadine" -Surname "Richard" -SamAccountName "nrichard" -UserPrincipalName "nrichard@ad.fournil.lab" -Path "OU=emballage,OU=conditionnement,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Operatrice Emballage"
Add-ADGroupMember -Identity "G_Laboratoire_conditionnement_emballage" -Members "nrichard"

# Celine Simon — Responsable Expedition
New-ADUser -Name "Celine Simon" -GivenName "Celine" -Surname "Simon" -SamAccountName "csimon" -UserPrincipalName "csimon@ad.fournil.lab" -Path "OU=expedition,OU=conditionnement,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Expedition"
Add-ADGroupMember -Identity "G_Laboratoire_conditionnement_expedition" -Members "csimon"

# Jerome Duval — Responsable Qualite
New-ADUser -Name "Jerome Duval" -GivenName "Jerome" -Surname "Duval" -SamAccountName "jduval" -UserPrincipalName "jduval@ad.fournil.lab" -Path "OU=qualite-hygiene,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Qualite"
Add-ADGroupMember -Identity "G_Laboratoire_qualite-hygiene" -Members "jduval"

# Florian Petit — Technicien Maintenance
New-ADUser -Name "Florian Petit" -GivenName "Florian" -Surname "Petit" -SamAccountName "fpetit" -UserPrincipalName "fpetit@ad.fournil.lab" -Path "OU=maintenance,OU=Laboratoire,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Technicien Maintenance"
Add-ADGroupMember -Identity "G_Laboratoire_maintenance" -Members "fpetit"

# === VENTE ===

# Gaelle Renaud — Directrice Vente
New-ADUser -Name "Gaelle Renaud" -GivenName "Gaelle" -Surname "Renaud" -SamAccountName "grenaud" -UserPrincipalName "grenaud@ad.fournil.lab" -Path "OU=direction-vente,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Directrice Vente"
Add-ADGroupMember -Identity "G_Vente_direction-vente" -Members "grenaud"

# Amelie Girard — Vendeuse
New-ADUser -Name "Amelie Girard" -GivenName "Amelie" -Surname "Girard" -SamAccountName "agirard" -UserPrincipalName "agirard@ad.fournil.lab" -Path "OU=accueil-boutique,OU=boutique,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Vendeuse"
Add-ADGroupMember -Identity "G_Vente_boutique_accueil-boutique" -Members "agirard"

# Camille Perrin — Caissiere
New-ADUser -Name "Camille Perrin" -GivenName "Camille" -Surname "Perrin" -SamAccountName "cperrin" -UserPrincipalName "cperrin@ad.fournil.lab" -Path "OU=caisse,OU=boutique,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Caissiere"
Add-ADGroupMember -Identity "G_Vente_boutique_caisse" -Members "cperrin"

# Isabelle Faure — Responsable Boutique
New-ADUser -Name "Isabelle Faure" -GivenName "Isabelle" -Surname "Faure" -SamAccountName "ifaure" -UserPrincipalName "ifaure@ad.fournil.lab" -Path "OU=direction-boutique,OU=boutique,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Boutique"
Add-ADGroupMember -Identity "G_Vente_boutique_direction-boutique" -Members "ifaure"

# Thomas Vidal — Responsable Commercial
New-ADUser -Name "Thomas Vidal" -GivenName "Thomas" -Surname "Vidal" -SamAccountName "tvidal" -UserPrincipalName "tvidal@ad.fournil.lab" -Path "OU=ventes-pro,OU=commercial,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Commercial"
Add-ADGroupMember -Identity "G_Vente_commercial_ventes-pro" -Members "tvidal"

# David Meyer — Commercial
New-ADUser -Name "David Meyer" -GivenName "David" -Surname "Meyer" -SamAccountName "dmeyer" -UserPrincipalName "dmeyer@ad.fournil.lab" -Path "OU=ventes-pro,OU=commercial,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Commercial"
Add-ADGroupMember -Identity "G_Vente_commercial_ventes-pro" -Members "dmeyer"

# Hugo Lopez — Charge de Marketing
New-ADUser -Name "Hugo Lopez" -GivenName "Hugo" -Surname "Lopez" -SamAccountName "hlopez" -UserPrincipalName "hlopez@ad.fournil.lab" -Path "OU=marketing,OU=commercial,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Charge de Marketing"
Add-ADGroupMember -Identity "G_Vente_commercial_marketing" -Members "hlopez"

# Pierre Aubert — Directeur Commercial
New-ADUser -Name "Pierre Aubert" -GivenName "Pierre" -Surname "Aubert" -SamAccountName "paubert" -UserPrincipalName "paubert@ad.fournil.lab" -Path "OU=direction-commercial,OU=commercial,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Directeur Commercial"
Add-ADGroupMember -Identity "G_Vente_commercial_direction-commercial" -Members "paubert"

# Baptiste Moreau — Chauffeur-Livreur
New-ADUser -Name "Baptiste Moreau" -GivenName "Baptiste" -Surname "Moreau" -SamAccountName "bmoreau" -UserPrincipalName "bmoreau@ad.fournil.lab" -Path "OU=tournees,OU=livraisons,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Chauffeur-Livreur"
Add-ADGroupMember -Identity "G_Vente_livraisons_tournees" -Members "bmoreau"

# Thierry Roux — Chauffeur-Livreur
New-ADUser -Name "Thierry Roux" -GivenName "Thierry" -Surname "Roux" -SamAccountName "troux" -UserPrincipalName "troux@ad.fournil.lab" -Path "OU=tournees,OU=livraisons,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Chauffeur-Livreur"
Add-ADGroupMember -Identity "G_Vente_livraisons_tournees" -Members "troux"

# Victor Noel — Responsable Planning
New-ADUser -Name "Victor Noel" -GivenName "Victor" -Surname "Noel" -SamAccountName "vnoel" -UserPrincipalName "vnoel@ad.fournil.lab" -Path "OU=planning,OU=livraisons,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Responsable Planning"
Add-ADGroupMember -Identity "G_Vente_livraisons_planning" -Members "vnoel"

# Adele Mercier — Secretaire
New-ADUser -Name "Adele Mercier" -GivenName "Adele" -Surname "Mercier" -SamAccountName "amercier" -UserPrincipalName "amercier@ad.fournil.lab" -Path "OU=secretariat,OU=ressources,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Secretaire"
Add-ADGroupMember -Identity "G_Vente_ressources_secretariat" -Members "amercier"

# Nathalie Bouchard — Comptable
New-ADUser -Name "Nathalie Bouchard" -GivenName "Nathalie" -Surname "Bouchard" -SamAccountName "nbouchard" -UserPrincipalName "nbouchard@ad.fournil.lab" -Path "OU=comptabilite,OU=ressources,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Comptable"
Add-ADGroupMember -Identity "G_Vente_ressources_comptabilite" -Members "nbouchard"

# Julie Renard — Gestionnaire RH
New-ADUser -Name "Julie Renard" -GivenName "Julie" -Surname "Renard" -SamAccountName "jrenard" -UserPrincipalName "jrenard@ad.fournil.lab" -Path "OU=rh,OU=ressources,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Gestionnaire RH"
Add-ADGroupMember -Identity "G_Vente_ressources_rh" -Members "jrenard"

# Luc Morin — Administrateur Systemes
New-ADUser -Name "Luc Morin" -GivenName "Luc" -Surname "Morin" -SamAccountName "lmorin" -UserPrincipalName "lmorin@ad.fournil.lab" -Path "OU=informatique,OU=ressources,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Administrateur Systemes"
Add-ADGroupMember -Identity "G_Vente_ressources_informatique" -Members "lmorin"

# Laura Morin — Directrice Ressources
New-ADUser -Name "Laura Morin" -GivenName "Laura" -Surname "Morin" -SamAccountName "lmorin2" -UserPrincipalName "lmorin2@ad.fournil.lab" -Path "OU=direction-ressources,OU=ressources,OU=Vente,OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" -AccountPassword $mdp -ChangePasswordAtLogon $true -Enabled $true -Description "Directrice Ressources"
Add-ADGroupMember -Identity "G_Vente_ressources_direction-ressources" -Members "lmorin2"
```

---

## Vérification

```powershell
# Lister tous les utilisateurs créés
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,OU=fournil,DC=ad,DC=fournil,DC=lab" |
    Select-Object Name, SamAccountName | Sort-Object SamAccountName

# Vérifier la chaîne AGDLP de Marc Lebrun
Get-ADPrincipalGroupMembership -Identity "mlebrun" | Select-Object Name, GroupScope
```

Résultat attendu pour mlebrun :

```
mlebrun
  └── G_Laboratoire_fabrication_boulangerie     (Global)
        └── G_Laboratoire_fabrication            (Global)
              └── G_Laboratoire                  (Global)
                    └── G_fournil                (Global)

G_Laboratoire_fabrication_boulangerie → DL_..._boulangerie_M  → Modification sur C:\fournil\...\boulangerie
G_Laboratoire_fabrication             → DL_..._fabrication_L  → Lecture sur C:\fournil\...\fabrication
G_Laboratoire                         → DL_Laboratoire_L     → Lecture sur C:\fournil\Laboratoire
```
