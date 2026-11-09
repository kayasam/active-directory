---
title: "00.5 — Brancher votre poste de travail"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="html" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 28 32"><path d="M2 2h24l-2 25-10 3-10-3Z" fill="#e44d26"/><path d="M14 5v22l7-2 2-20Z" fill="#f16529"/><path d="M7 8h15l-.3 3H11l.3 3h10l-.8 9-6.5 2-6.5-2-.4-5h3l.2 2.6 3.7 1 3.7-1 .3-3.6H8Z" fill="#fff"/></svg>
</span><span class="resource-label">Projet guidé</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-00-5-poste-de-travail.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée : **30 min** · À faire **une seule fois**, avant le premier TP.
> Précédent : [00.4-Joindre-DC02](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-4-joindre-dc02)

> [!important] Vous arrivez directement ici ?
> - Si le lab est **déjà monté** (par vous ou par le formateur) : vous êtes au bon endroit.
> - Si vous **n'avez pas encore de serveurs** : revenez à [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-0-demarrer-ici), puis montez le lab avec les notes 00.1 à 00.4. Rien de ce qui suit ne marchera sans ça.

---

## Ce qu'on va faire, et pourquoi

Le TP se pilote **entièrement depuis votre poste**, avec VSCode, comme un vrai admin.
Pour ça il faut trois choses, dans cet ordre :

| Étape | On fait quoi | Pourquoi |
|-------|--------------|----------|
| **A** | Vérifier la maquette | Ne pas découvrir à l'exercice 4 que DC02 n'est pas dans le domaine |
| **B** | Brancher VSCode en SSH sur DC01 | Pour écrire et lancer du PowerShell confortablement, sans la console pourrie de la VM |
| **C** | Ouvrir les ports du pare-feu | Pour que DC01 puisse piloter DC02 (WinRM, SMB, RPC) |

À la fin, vous devez avoir **un terminal PowerShell DC01 ouvert dans VSCode**, et `Invoke-Command -ComputerName DC02` qui répond.

---

## Rappel : la maquette

![Schema-Reseau-Lab](https://cours.kaya.ovh/active-directory/assets/supports/697b562bfdf85aeaad03.svg)

> [!tip] Les badges dans les blocs de commandes
> 💻 **SUR VOTRE POSTE** · 🖥️ **SUR DC01** · 🖧 **VERS DC02** (tapé sur DC01, exécuté sur DC02)

---

# ÉTAPE A — Vérifier la maquette (5 min)

> 🖥️ **SUR DC01** — console de la VM, PowerShell **en administrateur**

Ces 4 commandes valident l'environnement. **Ne passez pas à l'étape B tant qu'elles ne sont pas toutes vertes.**

```powershell
# A1 — Suis-je bien sur DC01 ?
$env:COMPUTERNAME
```
> Attendu : `DC01`

```powershell
# A2 — Le domaine existe-t-il ?
Get-ADDomain | Select-Object DNSRoot, NetBIOSName
```
> Attendu : `ad.fournil.lab` / `AD`
> ❌ `Get-ADDomain n'est pas reconnu` → `Install-WindowsFeature RSAT-AD-PowerShell`

```powershell
# A3 — Quelle est mon IP, et DC02 répond-il ?
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object IPAddress, InterfaceAlias
Test-Connection DC02 -Count 2
Resolve-DnsName DC02
```
> Attendu : votre IP DC01, un ping qui répond, et une résolution DNS de DC02.
> **Notez l'IP de DC01**, vous en aurez besoin à l'étape B.
> ❌ `Resolve-DnsName : DNS name does not exist` → DC02 n'est pas enregistré dans le DNS. Vérifiez que DC02 est bien joint au domaine et que **sa carte réseau pointe vers l'IP de DC01 comme serveur DNS**.

```powershell
# A4 — Les deux serveurs sont-ils en profil réseau Domaine ?
Get-NetConnectionProfile | Select-Object InterfaceAlias, NetworkCategory
```
> Attendu : `NetworkCategory : DomainAuthenticated`

> [!warning] Le piège n°1 du TP : le profil réseau
> Si vous voyez `Private` ou `Public` au lieu de `DomainAuthenticated`, **arrêtez-vous ici**.
> Toutes les règles de pare-feu qu'on va créer sont en `-Profile Domain` : elles ne s'appliqueront pas, et vous passerez l'après-midi à chercher pourquoi DFS plante.
>
> **Cause quasi systématique** : la carte réseau du serveur n'a pas le DC comme serveur DNS. Corrigez le DNS, puis :
> ```powershell
> Restart-NetAdapter -Name "Ethernet"    # adaptez le nom vu en A3
> Get-NetConnectionProfile               # re-vérifiez
> ```

> [!success] Checkpoint A
> A1 → `DC01` · A2 → `ad.fournil.lab` · A3 → DC02 pingue et se résout · A4 → `DomainAuthenticated`

---

# ÉTAPE B — Brancher VSCode sur DC01 (15 min)

**But** : au lieu de taper vos commandes dans la petite console de la VM, vous les écrivez dans VSCode sur votre poste, et elles s'exécutent sur DC01.

**Comment** : VSCode se connecte en **SSH** à DC01. C'est pour ça qu'on ouvre le **port 22**.

## B1 — Activer SSH sur DC01

> 🖥️ **SUR DC01** — PowerShell **en administrateur**

```powershell
# Le serveur OpenSSH est-il présent ?
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
```

> **Windows Server 2025** : il est installé par défaut (`State : Installed`) → passez directement au démarrage du service.
> Sinon (`State : NotPresent`) :
> ```powershell
> Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
> ```

```powershell
# Démarrer le service et le rendre automatique
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Vérifier que la règle de pare-feu SSH existe
Get-NetFirewallRule -Name *ssh*
```

> Si aucune règle n'apparaît, créez-la — **c'est le port 22 de la flèche violette du schéma des flux** :
> ```powershell
> New-NetFirewallRule -DisplayName "OpenSSH-Server-In" `
>     -Direction Inbound -Protocol TCP -LocalPort 22 `
>     -Action Allow -Profile Domain
> ```

```powershell
# Faire en sorte que SSH ouvre PowerShell et non cmd.exe
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force
```

> [!question] Pourquoi changer le shell par défaut ?
> Sans ça, votre terminal VSCode s'ouvre sur `cmd.exe` : aucune commande `Get-AD*` ne fonctionnera et vous croirez que le module AD est cassé.

> [!success] Checkpoint B1
> ```powershell
> Get-Service sshd | Select-Object Name, Status, StartType
> ```
> Attendu : `sshd  Running  Automatic`

## B2 — Installer VSCode sur votre poste

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

```powershell
winget install Microsoft.VisualStudioCode --scope machine --accept-source-agreements
```

**Fermez puis rouvrez le terminal** (pour que `code` soit dans le PATH), puis :

```powershell
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode.powershell
```

## B3 — Créer votre clé SSH

> 💻 **SUR VOTRE POSTE**

```powershell
ssh-keygen -t ed25519 -C "admin-fournil"
```
> Appuyez sur **Entrée** à chaque question (chemin par défaut, pas de passphrase).

Deux fichiers sont créés dans `C:\Users\<votre-login>\.ssh\` :

| Fichier | Rôle |
|---------|------|
| `id_ed25519` | Clé **privée** — reste chez vous, ne se partage **jamais** |
| `id_ed25519.pub` | Clé **publique** — se copie sur les serveurs |

> [!question] Pourquoi une clé plutôt qu'un mot de passe ?
> Vous allez vous reconnecter des dizaines de fois pendant le TP. Avec une clé, VSCode ne demande plus rien.
> C'est aussi ce qui se fait en production : un mot de passe se devine ou s'intercepte, pas une clé de 256 bits.

## B4 — Copier la clé publique sur DC01

> 💻 **SUR VOTRE POSTE** — remplacez l'IP par celle relevée en A3

```powershell
$pubKey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"

ssh administrateur@192.168.3.10 "
    if (-not (Test-Path 'C:\ProgramData\ssh')) { New-Item -ItemType Directory -Path 'C:\ProgramData\ssh' -Force }
    Add-Content -Path 'C:\ProgramData\ssh\administrators_authorized_keys' -Value '$pubKey'
    icacls 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'Administrateurs:F' /grant 'SYSTEM:F'
"
```

> Le mot de passe est demandé **une dernière fois**. Ensuite, plus jamais.

> [!question] Pourquoi `administrators_authorized_keys` et pas `authorized_keys` ?
> Sur Windows, tous les comptes membres du groupe **Administrateurs** partagent un seul fichier de clés, situé dans `C:\ProgramData\ssh\`. Si vous mettez la clé dans le `.ssh\authorized_keys` du profil utilisateur, OpenSSH l'ignorera et redemandera le mot de passe.
> La ligne `icacls` est tout aussi obligatoire : OpenSSH **refuse** d'utiliser un fichier de clés dont les droits sont trop permissifs.

## B5 — Déclarer l'hôte dans la config SSH

> 💻 **SUR VOTRE POSTE** — créez / éditez `C:\Users\<votre-login>\.ssh\config`

```
Host dc01
    HostName 192.168.3.10
    User administrateur
    IdentityFile ~/.ssh/id_ed25519
```

> Remplacez l'IP par la vôtre. Grâce à ce fichier, vous taperez juste `dc01` au lieu de l'IP complète.

## B6 — Se connecter

> 💻 **SUR VOTRE POSTE — dans VSCode**

1. `Ctrl+Shift+P` → **Remote-SSH: Connect to Host...**
2. Choisissez **dc01**
3. Plateforme : **Windows**
4. La connexion se fait **sans mot de passe**

Puis **Fichier → Ouvrir le dossier** → `C:\Deploy`

> [!success] Checkpoint B
> Dans le terminal VSCode (`Ctrl+ù` ou Terminal → Nouveau terminal) :
> ```powershell
> $env:COMPUTERNAME
> $PSVersionTable.PSVersion
> ```
> Attendu : `DC01` et un numéro de version PowerShell.
> Si vous voyez `Microsoft Windows [version ...]` au lieu d'un prompt `PS>`, le DefaultShell de B1 n'a pas été appliqué : refaites-le et reconnectez-vous.

## B7 — Déposer les fichiers du TP

> 🖥️ **SUR DC01** — copiez le contenu du dossier `scripts/` du TP dans `C:\Deploy`

```
C:\Deploy\
├── orga-fournil.csv              ← organigramme (31 lignes)
├── utilisateurs-fournil.csv      ← les 30 salariés
├── 01-AD-Arborescence.ps1        ← correction AD
├── 02-DFS-Deploiement.ps1        ← correction DFS
├── 03-GPO-Home.ps1               ← correction GPO
├── 00-Deploiement-Complet.ps1    ← script unifié
└── Set-NetworkLocation.ps1       ← script de connexion GPO
```

```powershell
# Vérifier
Get-ChildItem C:\Deploy | Select-Object Name, Length
```

> [!warning] Ne lancez AUCUN de ces scripts maintenant
> Ce sont les **corrections**. Si vous les lancez, le TP est déjà fait et vous n'apprenez rien.
> Ils servent au parcours Avancé et à la comparaison finale.

---

# ÉTAPE C — Ouvrir le pare-feu (10 min)

## C1 — Comprendre avant de copier-coller

Le pare-feu Windows bloque par défaut les connexions entrantes qui ne correspondent à aucune règle. Chaque règle qu'on va créer débloque **une flèche précise** de ce schéma :

![Schema-Flux-Firewall](https://cours.kaya.ovh/active-directory/assets/supports/81d8f24035759bb452ae.svg)

> [!question] Pourquoi DC01 doit-il parler à DC02 ?
> Parce qu'au TP DFS, les scripts font ceci :
> ```powershell
> Invoke-Command -ComputerName DC02 -ScriptBlock { New-Item -Path "D:\Labo" ... }
> ```
> DC01 exécute du code **sur** DC02 sans que vous ayez à ouvrir la console de DC02.
> Ça passe par **WinRM (5985)**. Sans ce port : `WinRM cannot complete the operation`.
>
> Ensuite, DFS copie des fichiers entre les deux serveurs → **SMB (445)**,
> et la console DFS + la réplication DFS-R négocient un port au hasard → **RPC (135 + plage haute)**.

> [!question] Pourquoi une plage de 16 000 ports ?
> RPC ne travaille pas sur un port fixe. Le client demande d'abord au **port 135** : *« sur quel port écoute le service DFS ? »*. Le serveur répond un numéro tiré au hasard entre **49152 et 65535**, et le client s'y reconnecte.
> Si on n'ouvre que le 135, la négociation démarre mais la vraie connexion est bloquée → la console DFS affiche un lapidaire **« erreur générale »**.

> [!question] Pourquoi `-Profile Domain` et pas tout ouvrir ?
> Windows a **trois pare-feux en un** : Domaine, Privé, Public. Une règle `-Profile Domain` ne s'active **que** si la carte réseau est authentifiée auprès du DC.
> Résultat : on ouvre grand sur le LAN de l'entreprise, et si ce serveur se retrouve un jour sur un autre réseau, **tous ces ports se referment automatiquement**. C'est le réflexe de sécurité à garder.

## C2 — Appliquer sur DC01

> 🖥️ **SUR DC01** — terminal VSCode, en administrateur

```powershell
# Active WinRM (le service qui reçoit les Invoke-Command)
Enable-PSRemoting -Force

# Flux WinRM entrant — port 5985
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True -Profile Domain

# Flux SMB — partages, DFS, SYSVOL, Robocopy
New-NetFirewallRule -DisplayName "SMB-In" `
    -Direction Inbound -Protocol TCP -LocalPort 445 `
    -Action Allow -Profile Domain -ErrorAction SilentlyContinue

# Flux RPC — l'annuaire qui dit "DFS écoute sur tel port"
New-NetFirewallRule -DisplayName "DFS-RPC-In" `
    -Direction Inbound -Protocol TCP -LocalPort 135 `
    -Action Allow -Profile Domain -ErrorAction SilentlyContinue

# Flux RPC dynamiques — le port réellement utilisé ensuite
New-NetFirewallRule -DisplayName "RPC-Dynamic-In" `
    -Direction Inbound -Protocol TCP -LocalPort 49152-65535 `
    -Action Allow -Profile Domain -ErrorAction SilentlyContinue

# Ping — uniquement pour le diagnostic
New-NetFirewallRule -DisplayName "ICMPv4-In" `
    -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
    -Action Allow -Profile Domain -ErrorAction SilentlyContinue
```

> `-ErrorAction SilentlyContinue` masque les erreurs non bloquantes. Si vous relancez ce bloc, Windows peut créer des règles portant le même nom d'affichage ; cela ne bloque pas le TP.

## C3 — Appliquer sur DC02, à distance

> 🖧 **VERS DC02** — on tape sur DC01, ça s'exécute sur DC02

C'est votre **première utilisation de `Invoke-Command`** : tout ce qui est entre `{ }` part s'exécuter sur l'autre serveur.

```powershell
Invoke-Command -ComputerName DC02 -ScriptBlock {
    Enable-PSRemoting -Force

    Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True -Profile Domain

    New-NetFirewallRule -DisplayName "SMB-In" `
        -Direction Inbound -Protocol TCP -LocalPort 445 `
        -Action Allow -Profile Domain -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "DFS-RPC-In" `
        -Direction Inbound -Protocol TCP -LocalPort 135 `
        -Action Allow -Profile Domain -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "RPC-Dynamic-In" `
        -Direction Inbound -Protocol TCP -LocalPort 49152-65535 `
        -Action Allow -Profile Domain -ErrorAction SilentlyContinue

    New-NetFirewallRule -DisplayName "ICMPv4-In" `
        -Direction Inbound -Protocol ICMPv4 -IcmpType 8 `
        -Action Allow -Profile Domain -ErrorAction SilentlyContinue
}
```

> [!failure] `Invoke-Command` échoue ici ? C'est normal et c'est l'œuf et la poule
> Si WinRM n'a jamais été activé sur DC02, vous ne pouvez pas l'activer... à distance.
> **Solution** : ouvrez la console de DC02 **une seule fois**, lancez-y `Enable-PSRemoting -Force`, puis revenez sur DC01 et relancez le bloc ci-dessus.

## C4 — Vérification finale

> 🖥️ **SUR DC01**

```powershell
# 1. Le service WinRM de DC02 répond-il ?
Test-WSMan -ComputerName DC02
```
> Attendu : un bloc avec `ProductVendor : Microsoft Corporation`

```powershell
# 2. Puis-je vraiment exécuter du code sur DC02 ?
Invoke-Command -ComputerName DC02 -ScriptBlock { $env:COMPUTERNAME }
```
> Attendu : **`DC02`** — c'est LE test qui compte.

```powershell
# 3. Mes règles sont-elles bien actives en profil Domaine ?
Get-NetFirewallRule -Direction Inbound -Enabled True |
    Where-Object { $_.Profile -match "Domain" -and $_.DisplayName -match "SMB-In|DFS-RPC-In|RPC-Dynamic-In|ICMPv4-In|OpenSSH" } |
    Select-Object DisplayName, Enabled | Sort-Object DisplayName
```

> [!success] Checkpoint C — et fin des prérequis
> `Invoke-Command -ComputerName DC02 { $env:COMPUTERNAME }` renvoie **`DC02`**.
> Si cette commande marche, **tout le TP DFS marchera**. Si elle ne marche pas, n'allez pas plus loin.

---

## Récapitulatif des ports ouverts

| Port | Protocole | Flux | Nécessaire pour | Symptôme si fermé |
|------|-----------|------|-----------------|-------------------|
| 22 | TCP | Poste → DC01 | VSCode Remote-SSH | `Could not establish connection` |
| 5985 | TCP | DC01 → DC02 | `Invoke-Command`, `Enter-PSSession` | `WinRM cannot complete the operation` |
| 445 | TCP | DC01 ⇄ DC02 | Partages, DFS, SYSVOL, Robocopy | `Le chemin réseau n'a pas été trouvé` |
| 135 | TCP | DC01 ⇄ DC02 | Annuaire RPC (DFS, réplication) | Console DFS : « erreur générale » |
| 49152-65535 | TCP | DC01 ⇄ DC02 | Ports RPC négociés dynamiquement | Réplication DFS-R bloquée à 0 % |
| ICMP type 8 | ICMPv4 | Tous | `Test-Connection` / ping | Diagnostic impossible |

> Toutes ces règles sont limitées au profil **Domaine** : elles ne s'appliquent pas sur un réseau public ou privé.

---

## En cas de problème

| Symptôme | Où chercher |
|----------|-------------|
| VSCode : `Could not establish connection to dc01` | Service `sshd` arrêté, ou règle port 22 absente (B1) |
| SSH redemande le mot de passe | Clé dans le mauvais fichier ou `icacls` oublié (B4) |
| Terminal VSCode ouvre `cmd.exe` | `DefaultShell` non appliqué (B1) — reconnectez-vous après |
| `Get-AD*` non reconnu | `Install-WindowsFeature RSAT-AD-PowerShell` |
| `Test-WSMan` échoue | WinRM pas activé sur DC02 — console DC02 → `Enable-PSRemoting -Force` |
| `NetworkCategory = Private` | Le DNS du serveur ne pointe pas vers DC01 (A4) |
| DC02 injoignable par son nom | `Resolve-DnsName DC02` — problème DNS, pas pare-feu |

---

## Vous êtes prêt !

La phase de montage est terminée. Le vrai TP commence maintenant.

| Parcours | Premier TP |
|----------|------------|
| **Débutant** (recommandé) | [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-debutant-ad) |
| Intermédiaire | [01.TP-Intermediaire-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-intermediaire-ad) |
| Avancé | [01.TP-Avance-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-avance-ad) |

> [!tip] Dernier point de contrôle avant de commencer
> ```powershell
> Checkpoint-VM -Name DC01 -SnapshotName "05-Lab-pret"
> Checkpoint-VM -Name DC02  -SnapshotName "05-Lab-pret"
> ```
> C'est votre retour arrière si le TP AD part de travers.

> [!info] Snapshot VMware Workstation
> Arrêtez proprement les deux VM, puis utilisez `vmrun` depuis l'hôte :
> ```powershell
> $vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
> & $vmrun -T ws snapshot "D:\VMware-Fournil\VM\DC01\DC01.vmx" "05-Lab-pret"
> & $vmrun -T ws snapshot "D:\VMware-Fournil\VM\DC02\DC02.vmx" "05-Lab-pret"
> ```

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.4-Joindre-DC02](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-4-joindre-dc02) | [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-debutant-ad) |

> Retour à l'accueil : [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-0-demarrer-ici)
