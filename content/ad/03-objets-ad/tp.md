---
title: "TP 03 — Objets AD : utilisateurs, ordinateurs, groupes"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/03-objets-ad"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/03-objets-ad/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/03-objets-ad.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 1h30

> Chapitres associés : [03. Objets AD : utilisateurs, ordinateurs, groupes](https://cours.kaya.ovh/active-directory/ad/03-objets-ad/)

---

## Objectifs

- Créer des comptes utilisateurs via l'interface graphique et PowerShell
- Importer des utilisateurs en masse depuis un fichier CSV
- Gérer les comptes ordinateurs
- Créer des groupes et appliquer le modèle AGDLP

---

## Contexte

Tu continues sur le domaine `ad.fournil.lab` de la société **Fournil**. La structure d'OUs du TP 02 doit être en place (Direction, Production, Commercial, Support).

---

## Partie A — Comptes utilisateurs (25 min)

**A1.** Crée les utilisateurs suivants via **`dsa.msc`** dans les bonnes OUs :

| Prénom | Nom | Pôle | Login |
|--------|-----|------|-------|
| Claire | Fontaine | Direction | `cfontaine` |
| Marc | Lebrun | Production | `mlebrun` |

Options : mot de passe `P@ssw0rd!`, changer le mot de passe à la prochaine connexion.

**A2.** Crée les utilisateurs suivants via **PowerShell** :

| Prénom | Nom | Pôle | Login |
|--------|-----|------|-------|
| Sophie | Dupont | Production | `sdupont` |
| Thomas | Vidal | Commercial | `tvidal` |
| Julie | Renard | Support | `jrenard` |

**A3.** Vérifie que tous les comptes sont créés :
```powershell
Get-ADUser -Filter * -SearchBase "OU=Utilisateurs,DC=ad,DC=fournil,DC=lab" -SearchScope Subtree | Select-Object Name, SamAccountName, Enabled
```

**A4.** Le compte de `Marc Lebrun` doit être temporairement désactivé (arrêt maladie longue durée). Désactive-le via PowerShell.

**A5.** Réinitialise le mot de passe de `Julie Renard` à `NewP@ss2025!` sans forcer le changement au prochain logon.

---

## Partie B — Import en masse (20 min)

**B1.** Crée le fichier `C:\import_users.csv` avec le contenu suivant :

```
Prenom,Nom,OU
Laura,Morin,Support
Kevin,Garnier,Production
Nathalie,Bouchard,Direction
Pierre,Aubert,Commercial
```

**B2.** Écris le script PowerShell qui importe ces utilisateurs. Le login doit être construit automatiquement : première lettre du prénom + nom en minuscules (ex : `lmorin`).

**B3.** Vérifie l'import. Combien d'utilisateurs sont maintenant présents dans l'OU `Utilisateurs` (toutes sous-OUs confondues) ?

---

## Partie C — Jonction Windows 11 et comptes ordinateurs (30 min)

> **Contexte réseau** : DC01 est sur le réseau interne Hyper-V `192.168.3.0/24`. Le poste Windows 11 que tu vas joindre sera `PC-PROD-01` à l'adresse `192.168.3.100`.

**C1.** Configure l'adresse IP fixe de ta machine Windows 11. Via PowerShell (administrateur local) :

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.3.100 -PrefixLength 24 -DefaultGateway 192.168.3.254
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.3.10
```

Ou via l'interface graphique : **Paramètres → Réseau et Internet → Ethernet → Modifier** → attribution manuelle.

| Paramètre | Valeur |
|-----------|--------|
| Adresse IP | `192.168.3.100` |
| Masque | `255.255.255.0` |
| Passerelle | `192.168.3.254` |
| DNS préféré | `192.168.3.10` (DC01) |

**C2.** Avant de joindre, vérifie la connectivité depuis Windows 11 :

```powershell
# Le DC doit répondre
Test-NetConnection 192.168.3.10

# Le domaine doit se résoudre
Resolve-DnsName ad.fournil.lab
```

Que retourne `Resolve-DnsName ad.fournil.lab` ? Sur quelle IP pointe le domaine ? Que se passerait-il si le DNS était 8.8.8.8 ?

**C3.** Joins la machine au domaine `ad.fournil.lab` via l'interface graphique :

1. Clic droit sur **Démarrer → Système**
2. Cliquer sur **Renommer ce PC (Paramètres avancés)**
3. Onglet **Nom de l'ordinateur** → **Modifier**
4. Cocher **Domaine** → saisir `ad.fournil.lab`
5. S'authentifier avec le compte `Administrateur` du domaine
6. **Redémarrer** — indispensable : sans redémarrage, le poste se considère encore en `WORKGROUP` et n'applique aucune GPO

Ou via PowerShell (le redémarrage sera automatique) :

```powershell
Add-Computer -DomainName "ad.fournil.lab" -Credential (Get-Credential) -Restart
```

**C4.** Après le redémarrage, connecte-toi avec un compte de domaine :
- Clique sur **Autre utilisateur**
- Saisis `FOURNIL\cfontaine` (compte créé en Partie A)
- Dans quel chemin le profil local est-il créé ?

**C5.** Depuis **DC01**, vérifie la présence du compte ordinateur :

```powershell
Get-ADComputer -Filter * | Select-Object Name, DistinguishedName
```

Dans quelle OU le compte a-t-il atterri ? Pourquoi ? (Pense à ce que tu as fait au TP 02, partie C.)

S'il est resté dans `CN=Computers` (redirection non faite), déplace-le dans `OU=Postes,OU=Ordinateurs` via `dsa.msc` (glisser-déposer) ou PowerShell :

```powershell
Get-ADComputer PC-PROD-01 | Move-ADObject -TargetPath "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab"
```

**C6.** Pré-crée un second compte ordinateur `PC-DIRECTION-01` directement dans la bonne OU :

```powershell
New-ADComputer -Name "PC-DIRECTION-01" `
               -Path "OU=Postes,OU=Ordinateurs,DC=ad,DC=fournil,DC=lab" `
               -Enabled $true
```

Quel est l'avantage de pré-créer le compte avant de joindre la machine physique ?

---

## Partie D — Groupes et AGDLP (30 min)

**D1.** Crée les groupes suivants via PowerShell dans `OU=Groupes` (à créer si elle n'existe pas) :

| Nom | Portée | Type |
|-----|--------|------|
| `GG_Direction` | Global | Sécurité |
| `GG_Production` | Global | Sécurité |
| `GG_Commercial` | Global | Sécurité |
| `GG_Support` | Global | Sécurité |
| `DL_Partage_Production_Lecture` | Domaine local | Sécurité |
| `DL_Partage_Production_Ecriture` | Domaine local | Sécurité |

**D2.** Ajoute les utilisateurs dans les groupes globaux correspondants à leur pôle.

**D3.** Imbrique les groupes globaux dans les groupes domaine local :
- `GG_Production` → `DL_Partage_Production_Ecriture`

**D4.** Crée le dossier `C:\Partages\fournil\Production` sur le DC, puis applique les permissions NTFS :
- `DL_Partage_Production_Lecture` → droit **Lecture**
- `DL_Partage_Production_Ecriture` → droit **Modification**

**D5.** Explique en une phrase pourquoi on n'attribue pas directement les permissions aux utilisateurs ou aux groupes globaux.

---

## Partie E — Bonus

**E1.** Trouve la commande PowerShell pour lister tous les groupes dont `jrenard` est membre.

**E2.** L'utilisatrice `sdupont` quitte la Production pour rejoindre le pôle Commercial. Quelles actions dois-tu effectuer dans AD pour que ses accès suivent automatiquement son changement de pôle ?

---


