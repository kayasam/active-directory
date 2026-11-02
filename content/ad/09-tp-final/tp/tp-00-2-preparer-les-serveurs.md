---
title: "00.2 — Préparer les deux serveurs"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-00-2-preparer-les-serveurs.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée : **45 min** (dont ~30 min de mises à jour Windows)
> Où : 💻 **SUR VOTRE POSTE**, via **PowerShell Direct**
> Précédent : [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm)

> [!info] Vous utilisez VMware Workstation ?
> PowerShell Direct est réservé à Hyper-V. Ouvrez la console de DC01 ou DC02 et exécutez **directement dans la VM concernée** le contenu situé entre `{` et `}` dans chaque bloc `Invoke-Command -VMName`.
> Remplacez `Restart-VM` par `Restart-Computer` et les checkpoints Hyper-V par `vmrun snapshot`, comme expliqué dans [00.1-VMware-Workstation](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-vmware-workstation).

---

## Ce qu'on fait, et dans quel ordre

Un serveur fraîchement installé a un nom au hasard, une IP en DHCP et aucune mise à jour.
On corrige tout ça **avant** d'installer le moindre rôle.

| # | Action | Pourquoi maintenant |
|---|--------|---------------------|
| 1 | Renommer en `DC01` / `DC02` | Renommer un DC **après** promotion est très compliqué |
| 2 | IP statique + passerelle + DNS | Un DC doit avoir une IP fixe, jamais du DHCP |
| 3 | Fuseau horaire | Kerberos refuse un écart > 5 min entre machines |
| 4 | Mises à jour Windows | Un serveur non à jour = bugs inexpliqués plus tard |
| 5 | Confort (IE ESC, RDP) | Pour ne pas galérer pendant le reste du TP |

---

## PowerShell Direct : le tunnel qui passe partout

> [!tip] La commande magique de cette note
> ```powershell
> Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock { ... }
> ```
> `-VMName` (et non `-ComputerName`) passe par le **bus Hyper-V**, pas par le réseau.
> Résultat : ça marche même quand la VM n'a pas encore d'IP, pas de DNS, pas de pare-feu ouvert.
> C'est pour ça qu'on peut tout configurer depuis l'hôte, sans jamais taper dans la petite fenêtre `vmconnect`.

### Récupérer les identifiants une bonne fois

> 💻 **SUR VOTRE POSTE**

```powershell
$credDC01 = Get-Credential -Message "Admin LOCAL de la VM DC01 (login : Administrateur)"
$credDC2  = Get-Credential -Message "Admin LOCAL de la VM DC02  (login : Administrateur)"
```

> Login à saisir : `Administrateur` (celui que vous avez défini pendant l'installation Windows).

```powershell
# Test : est-ce que ça répond ?
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock { hostname }
Invoke-Command -VMName DC02  -Credential $credDC2  -ScriptBlock { hostname }
```
> Attendu : deux noms du genre `WIN-K3J8DQ2`. On va les changer tout de suite.

> [!failure] `Le processus de virtualisation ne répond pas`
> La VM est éteinte ou en cours de démarrage : `Start-VM DC01`, attendez 1 min, réessayez.

> [!failure] `Nom d'utilisateur ou mot de passe incorrect`
> Le clavier de l'installation était peut-être en QWERTY au moment où vous avez tapé le mot de passe.
> Testez-le dans la console `vmconnect` pour lever le doute.

---

## Étape 1 — Renommer, adresser, configurer DC01

> 💻 **SUR VOTRE POSTE**

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {

    # --- Nom de la machine ---
    Rename-Computer -NewName "DC01" -Force

    # --- Carte réseau ---
    $if = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1

    # On enlève l'IP obtenue en DHCP avant d'en poser une fixe
    Remove-NetIPAddress -InterfaceIndex $if.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute     -InterfaceIndex $if.ifIndex -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress -InterfaceIndex $if.ifIndex `
        -IPAddress "192.168.3.10" -PrefixLength 24 -DefaultGateway "192.168.3.254"

    # DNS public, le temps de faire les mises à jour.
    # Ça changera à la promotion (étape 00.3) — voir l'encadré ci-dessous.
    Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses "8.8.8.8"

    # --- Fuseau horaire ---
    Set-TimeZone -Id "Romance Standard Time"

    Write-Host "DC01 configure" -ForegroundColor Green
}
```

## Étape 2 — Idem pour DC02

```powershell
Invoke-Command -VMName DC02 -Credential $credDC2 -ScriptBlock {

    Rename-Computer -NewName "DC02" -Force

    $if = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1

    Remove-NetIPAddress -InterfaceIndex $if.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute     -InterfaceIndex $if.ifIndex -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress -InterfaceIndex $if.ifIndex `
        -IPAddress "192.168.3.2" -PrefixLength 24 -DefaultGateway "192.168.3.254"

    Set-DnsClientServerAddress -InterfaceIndex $if.ifIndex -ServerAddresses "8.8.8.8"

    Set-TimeZone -Id "Romance Standard Time"

    Write-Host "DC02 configure" -ForegroundColor Green
}
```

## Étape 3 — Redémarrer pour appliquer les noms

```powershell
Restart-VM -Name DC01 -Force -Wait -For Heartbeat
Restart-VM -Name DC02  -Force -Wait -For Heartbeat
```

> `-Wait -For Heartbeat` rend la main quand Windows a fini de redémarrer. Comptez 1 à 2 minutes.

### Vérification

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {
    hostname
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" } |
        Select-Object IPAddress, PrefixLength
    (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses).ServerAddresses
}
```

**Résultat attendu :**

```
DC01
IPAddress    PrefixLength
---------    ------------
192.168.3.10            24
8.8.8.8
```

Faites la même chose pour DC02 (attendu : `DC02` / `192.168.3.2`).

> [!question] Pourquoi `8.8.8.8` en DNS, et `192.168.3.254` en passerelle ?
> Ce sont **deux rôles différents**, et les confondre est une erreur classique :
> - La **passerelle** (`.254`, votre PC) sait *router* les paquets vers Internet.
> - Le **serveur DNS** sait *traduire* un nom en adresse IP.
>
> Le NAT Hyper-V (`New-NetNat`) fait uniquement du routage : **ce n'est pas un serveur DNS**.
> Pointer le DNS vers `192.168.3.254` ne résoudrait aucun nom. On utilise donc un résolveur public le temps des mises à jour.
>
> C'est provisoire : dès l'étape 00.3, DC01 devient lui-même le serveur DNS du domaine.

> [!success] Checkpoint 3
> Les deux serveurs sont nommés et adressés. Testez qu'ils se voient :
> ```powershell
> Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock { Test-Connection 192.168.3.2 -Count 2 }
> ```

> [!failure] Le ping échoue
> C'est **normal à ce stade** : le pare-feu Windows bloque l'ICMP par défaut, et les deux serveurs ne sont pas encore dans un domaine. Ce n'est pas bloquant, on ouvrira tout ça à l'étape [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail).
> Pour lever le doute tout de suite :
> ```powershell
> Invoke-Command -VMName DC02 -Credential $credDC2 -ScriptBlock {
>     New-NetFirewallRule -DisplayName "ICMPv4-In" -Direction Inbound `
>         -Protocol ICMPv4 -IcmpType 8 -Action Allow -Profile Any
> }
> ```

---

## Étape 4 — Vérifier l'accès Internet

Sans Internet, pas de mises à jour. Testez avant de lancer l'étape 5.

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {
    Test-NetConnection 8.8.8.8 -InformationLevel Quiet       # la route sort-elle ?
    Resolve-DnsName www.microsoft.com -ErrorAction SilentlyContinue | Select-Object -First 1
}
```

> Attendu : `True`, puis une réponse DNS.

> [!failure] `False` — pas d'Internet dans la VM
> Vérifiez, **sur l'hôte**, les trois éléments du NAT :
> ```powershell
> Get-NetIPAddress -IPAddress 192.168.3.254        # l'IP de la passerelle existe ?
> Get-NetNat                                        # le NAT existe ?
> Get-NetIPInterface -InterfaceAlias "vEthernet (vSwitch-Rennes)" | Select AddressFamily, Forwarding
> ```
> Si le NAT manque, reprenez l'étape 3.3 de [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm).

---

## Étape 5 — Les mises à jour Windows

> [!note] C'est long, lancez-le et allez prendre un café
> Comptez 20 à 40 min et **un à deux redémarrages** par serveur.

Le module de mise à jour n'est pas installé par défaut, on l'ajoute :

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module PSWindowsUpdate -Force -Confirm:$false
    Import-Module PSWindowsUpdate

    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Verbose
}
```

Puis exactement la même chose pour DC02 (`-VMName DC02 -Credential $credDC2`).

```powershell
# Redémarrer une fois les mises à jour posées
Restart-VM -Name DC01 -Force -Wait -For Heartbeat
Restart-VM -Name DC02  -Force -Wait -For Heartbeat
```

### Vérification

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {
    (Get-CimInstance Win32_OperatingSystem).Caption
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 3 HotFixID, InstalledOn
}
```

> [!tip] Pas d'Internet en salle ? Vous pouvez sauter cette étape
> Le TP fonctionne sur un Windows Server non patché. Passez directement à l'étape 6 — mais signalez-le, certains messages d'erreur peuvent différer.

---

## Étape 6 — Le confort (2 min, mais ça change la vie)

```powershell
foreach ($vm in @(@{N="DC01";C=$credDC01}, @{N="DC02";C=$credDC2})) {
    Invoke-Command -VMName $vm.N -Credential $vm.C -ScriptBlock {

        # Désactiver la sécurité renforcée d'Internet Explorer
        # (sinon chaque page web ouvre 15 popups de confirmation)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -ErrorAction SilentlyContinue

        # Autoriser le Bureau à distance
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Bureau à distance" -ErrorAction SilentlyContinue

        # Ne jamais éteindre l'écran / mettre en veille
        powercfg /change standby-timeout-ac 0
        powercfg /change monitor-timeout-ac 0

        Write-Host "$env:COMPUTERNAME : confort applique" -ForegroundColor Green
    }
}
```

---

## Étape 7 — Nouveau point de contrôle

```powershell
Checkpoint-VM -Name DC01 -SnapshotName "02-Serveurs-prepares"
Checkpoint-VM -Name DC02  -SnapshotName "02-Serveurs-prepares"
```

> [!important] C'est le point de retour le plus utile du TP
> Si la promotion AD de l'étape suivante se passe mal, vous revenez ici et vous réessayez — au lieu de tout réinstaller.

---

## Checkpoint final de l'étape 00.2

| Élément | DC01 | DC02 |
|---------|------|-----|
| Nom | `DC01` | `DC02` |
| IP | `192.168.3.10/24` | `192.168.3.2/24` |
| Passerelle | `192.168.3.254` | `192.168.3.254` |
| DNS | `8.8.8.8` *(provisoire)* | `8.8.8.8` *(provisoire)* |
| Fuseau | Romance Standard Time | Romance Standard Time |
| Rôles installés | aucun | aucun |
| Domaine | aucun (groupe de travail) | aucun (groupe de travail) |

> [!warning] Le DNS est provisoire, c'est voulu
> Pour l'instant les serveurs interrogent le résolveur public `8.8.8.8`, uniquement pour aller chercher les mises à jour.
> Dès l'étape suivante, ça change — et c'est **le** point sensible du montage :

![Schema-DNS-Etapes](https://cours.kaya.ovh/active-directory/assets/supports/d056c37c377914ce04cd.svg)

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm) | [00.3-Promouvoir-DC01](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-3-promouvoir-dc01) |
