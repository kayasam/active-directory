---
title: "Phase 7 — Configuration du HomeDirectory des utilisateurs"
---

> Retour vers l'index : [Index DFS Manuel](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-00-index)
> Phase precedente : [DFS-06-Homes](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-06-homes) | Phase suivante : [DFS-08-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/02-dfs-manuel-dfs-08-verification-depannage)

## Objectif

Associer à chaque utilisateur Active Directory un dossier personnel (home directory) et un lecteur réseau mappé automatiquement à l'ouverture de session.

## Commandes détaillées

### 7.1 -- Lecture du fichier utilisateurs

```powershell
$utilisateurs = Import-Csv -Path ".\utilisateurs-fournil.csv" -Delimiter ";"
```

Le fichier contient les informations de chaque utilisateur, dont le login (`SamAccountName`) et l'entité de rattachement.

### 7.2 -- Configuration du HomeDirectory pour chaque utilisateur

```powershell
foreach ($user in $utilisateurs) {
    $login  = $user.Login       # ou le nom de la colonne correspondante
    $entite = $user.Entite

    # Vérifier si le HomeDirectory est déjà configuré
    $adUser = Get-ADUser -Identity $login -Properties HomeDirectory, HomeDrive
    if (-not $adUser.HomeDirectory) {
        Set-ADUser -Identity $login `
            -HomeDirectory "\\ad.fournil.lab\HOMES\$entite\$login" `
            -HomeDrive "H:"
    }
}
```

**Explication des paramètres de `Set-ADUser` :**

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `-Identity` | `$login` | Identifie l'utilisateur AD à modifier. Accepte un `SamAccountName`, un `DistinguishedName`, un `SID` ou un `GUID`. Ici, on utilise le login (SamAccountName). |
| `-HomeDirectory` | `"\\ad.fournil.lab\HOMES\$entite\$login"` | Chemin UNC du dossier personnel de l'utilisateur. Le chemin passe par l'espace de noms DFS : `\\ad.fournil.lab\HOMES\<Entite>\<Login>`. Par exemple, pour l'utilisateur `jdupont` de l'entité `Laboratoire` : `\\ad.fournil.lab\HOMES\Laboratoire\jdupont`. |
| `-HomeDrive` | `"H:"` | Lettre de lecteur qui sera automatiquement mappée au `HomeDirectory` lors de l'ouverture de session Windows de l'utilisateur. `H:` est une convention courante (H pour Home). |

**Explication de la vérification préalable :**

```powershell
$adUser = Get-ADUser -Identity $login -Properties HomeDirectory, HomeDrive
if (-not $adUser.HomeDirectory) { ... }
```

- `Get-ADUser -Properties HomeDirectory, HomeDrive` : par défaut, `Get-ADUser` ne retourne qu'un sous-ensemble de propriétés. Il faut explicitement demander `HomeDirectory` et `HomeDrive` avec le paramètre `-Properties`.
- `if (-not $adUser.HomeDirectory)` : vérifie que le `HomeDirectory` n'est pas déjà configuré. Si la propriété est `$null` ou vide, `-not` retourne `$true` et la configuration est appliquée. Cela rend le script idempotent : on peut le relancer sans risquer d'écraser une configuration existante.

## Comportement côté utilisateur

Lors de l'ouverture de session :

1. Windows lit les attributs `HomeDirectory` et `HomeDrive` de l'utilisateur dans Active Directory.
2. Windows mappe automatiquement le lecteur `H:` vers `\\ad.fournil.lab\HOMES\<Entite>\<Login>`.
3. Si le dossier n'existe pas encore, Windows le crée automatiquement (grâce à la permission `CreateDirectories` accordée aux « Utilisateurs du domaine » à l'étape 6.3).
4. L'utilisateur devient le « créateur propriétaire » de son dossier et obtient les droits de modification (grâce à la permission CREATEUR PROPRIETAIRE configurée à l'étape 6.3).
5. L'utilisateur peut stocker ses fichiers personnels dans `H:\`, qui sera répliqué entre DC01 et DC02.
