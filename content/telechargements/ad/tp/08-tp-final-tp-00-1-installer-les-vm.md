# 00.1 — Créer les deux machines virtuelles

> Durée : **1 h** (dont ~30 min d'attente pendant l'installation de Windows)
> Où : 💻 **SUR VOTRE POSTE**, l'hôte Hyper-V
> Précédent : [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-0-demarrer-ici)

> [!important] On part vraiment de zéro
> À la fin de cette note, vous aurez deux serveurs Windows fraîchement installés qui démarrent.
> Ils ne seront ni nommés, ni configurés, ni dans un domaine : c'est normal, ça vient après.

---

## Ce qu'on construit

![Schema-Montage-Lab](https://cours.kaya.ovh/active-directory/assets/supports/57c7f5c51af00acdf351.svg)

---

## Étape 1 — Vérifier que votre PC peut faire tourner le lab

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

```powershell
# Le processeur supporte-t-il la virtualisation, et est-elle activée dans le BIOS ?
Get-ComputerInfo -Property "HyperV*"
```

> Attendu : `HyperVRequirementVirtualizationFirmwareEnabled : True`
> ❌ Si c'est `False` : la virtualisation est désactivée dans le BIOS/UEFI. Redémarrez, entrez dans le BIOS, activez **Intel VT-x** ou **AMD-V**.

| Ressource | Minimum | Confortable |
|-----------|---------|-------------|
| RAM totale | 12 Go | **16 Go** |
| Espace disque libre | 80 Go | **150 Go** |
| Processeur | 4 cœurs | 8 cœurs |

> [!warning] 12 Go de RAM, c'est juste
> Les deux VM demandent 4 Go chacune au démarrage. Avec 12 Go au total, laissez la mémoire dynamique activée (c'est le cas dans le script) et fermez les autres applications.

---

## Étape 2 — Activer Hyper-V

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

```powershell
# Hyper-V est-il déjà là ?
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All |
    Select-Object FeatureName, State
```

Si `State : Disabled` :

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All
```

> ⚠️ **Redémarrage obligatoire** après cette commande.

> [!failure] La fonctionnalité n'apparaît pas du tout
> Vous êtes en **Windows Famille / Home**, qui n'a pas Hyper-V. Il vous faut Windows Pro, Entreprise ou Éducation.
> Alternative documentée : **[00.1-VMware-Workstation](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-1-vmware-workstation)**.

---

## Étape 3 — Créer le réseau virtuel du lab

C'est l'étape que tout le monde bâcle, et c'est celle qui fait échouer le TP trois heures plus tard.

### 3.1 — Créer le switch virtuel interne

```powershell
New-VMSwitch -Name "vSwitch-Rennes" -SwitchType Internal
```

> [!question] Pourquoi **Internal** et pas **External** ?
> - **External** = les VM sont branchées sur le réseau de la salle. Elles prendraient une IP en DHCP, et si 12 élèves créent 12 domaines `ad.fournil.lab` sur le même LAN, c'est le chaos (conflits DNS, machines qui rejoignent le mauvais domaine).
> - **Internal** = un réseau privé entre vos VM et votre PC uniquement. Chacun son lab, isolé.
>
> L'inconvénient d'Internal, c'est qu'il n'y a pas d'Internet. On corrige ça juste après avec le NAT.

### 3.2 — Donner une IP à l'hôte sur ce réseau

Le switch interne a créé une carte réseau virtuelle **sur votre PC**. C'est elle qui servira de passerelle aux VM.

```powershell
# Retrouver l'index de cette nouvelle carte
$idx = (Get-NetAdapter -Name "vEthernet (vSwitch-Rennes)").ifIndex
$idx

# Lui donner l'adresse .254 — ce sera la passerelle des VM
New-NetIPAddress -InterfaceIndex $idx -IPAddress 192.168.3.254 -PrefixLength 24
```

### 3.3 — Activer le NAT pour donner Internet aux VM

```powershell
New-NetNat -Name "NAT-Fournil" -InternalIPInterfaceAddressPrefix 192.168.3.0/24
```

> [!question] Ça fait quoi, concrètement ?
> Votre PC devient un petit routeur. Quand DC01 veut joindre Windows Update, il envoie le paquet à `192.168.3.254` (votre PC), qui le réexpédie par votre Wi-Fi en se faisant passer pour l'expéditeur. C'est exactement ce que fait votre box à la maison.

### 3.4 — Vérification

```powershell
Get-VMSwitch -Name "vSwitch-Rennes" | Select-Object Name, SwitchType
Get-NetIPAddress -IPAddress 192.168.3.254 | Select-Object IPAddress, InterfaceAlias
Get-NetNat -Name "NAT-Fournil" | Select-Object Name, InternalIPInterfaceAddressPrefix
```

> [!success] Checkpoint 3
> Un switch `Internal`, l'IP `192.168.3.254` sur la carte `vEthernet (vSwitch-Rennes)`, et un NAT sur `192.168.3.0/24`.

> [!failure] `New-NetNat : L'objet existe déjà` ou conflit
> Un ancien NAT traîne. Listez-les et supprimez celui qui gêne :
> ```powershell
> Get-NetNat
> Remove-NetNat -Name "<nom>" -Confirm:$false
> ```
> ⚠️ Windows n'accepte **qu'un seul NAT** à la fois par préfixe.

---

## Étape 4 — Préparer les dossiers et l'ISO

> 💻 **SUR VOTRE POSTE**

```powershell
New-Item -ItemType Directory -Path "D:\HyperV\ISO" -Force
New-Item -ItemType Directory -Path "D:\HyperV\VHD" -Force
```

> Adaptez `D:\` si vous n'avez qu'un disque `C:`.

Téléchargez l'**ISO d'évaluation de Windows Server 2025** (180 jours, gratuit) depuis le centre d'évaluation Microsoft, et placez-le dans `D:\HyperV\ISO\ws2025.iso`.

```powershell
# Vérifier que l'ISO est bien là
Get-Item "D:\HyperV\ISO\ws2025.iso" | Select-Object Name, @{N='Go';E={[math]::Round($_.Length/1GB,2)}}
```
> Attendu : environ **5 Go**.

---

## Étape 5 — Créer les deux VM

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

Copiez ce bloc entier. Il crée DC01 et DC02 d'un coup.

```powershell
# ====== Variables ======
$IsoPath = "D:\HyperV\ISO\ws2025.iso"
$VmRoot  = "D:\HyperV"
$VhdRoot = "D:\HyperV\VHD"
$Switch  = "vSwitch-Rennes"
$VhdSize = 80GB
$RAM     = 4GB
$CPU     = 4

foreach ($VMName in "DC01","DC02") {

    $VmPath  = Join-Path $VmRoot $VMName
    $VhdPath = Join-Path $VhdRoot "$VMName.vhdx"

    New-VM -Name $VMName -Generation 2 `
           -MemoryStartupBytes $RAM `
           -Path $VmPath `
           -NewVHDPath $VhdPath -NewVHDSizeBytes $VhdSize `
           -SwitchName $Switch

    Set-VM -Name $VMName -ProcessorCount $CPU

    # Monter l'ISO et démarrer dessus
    Add-VMDvdDrive -VMName $VMName
    Set-VMDvdDrive -VMName $VMName -Path $IsoPath
    Set-VMFirmware -VMName $VMName -FirstBootDevice (Get-VMDvdDrive -VMName $VMName)

    # Mémoire dynamique : la VM rend la RAM qu'elle n'utilise pas
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true `
                 -MinimumBytes 2GB -StartupBytes 4GB -MaximumBytes 8GB

    Write-Host "VM $VMName creee" -ForegroundColor Green
}
```

### Ce que font les paramètres importants

| Paramètre | Pourquoi |
|-----------|----------|
| `-Generation 2` | VM en **UEFI** — le choix recommandé pour Windows Server 2025 |
| `-NewVHDSizeBytes 80GB` | Disque **dynamique** : il ne prend que la place réellement utilisée (~15 Go au début) |
| `Set-VMFirmware -FirstBootDevice` | Force le démarrage sur le DVD, sinon la VM boote sur un disque vide |
| `-DynamicMemoryEnabled $true` | La VM rend la RAM inutilisée à votre PC — vital si vous avez 8 Go |

### Vérification

```powershell
Get-VM DC01,DC02 | Format-Table Name, State, Generation, MemoryStartup, ProcessorCount
Get-VMNetworkAdapter DC01,DC02 | Format-Table VMName, SwitchName
```

> [!success] Checkpoint 5
> Deux VM en état `Off`, Generation `2`, toutes les deux sur `vSwitch-Rennes`.

---

## Étape 6 — Installer Windows Server sur chaque VM

> [!note] À faire **deux fois** : une fois pour DC01, une fois pour DC02
> Vous pouvez lancer les deux en parallèle si votre PC a 16 Go de RAM.

```powershell
Start-VM -Name DC01
vmconnect.exe localhost DC01
```

Puis, dans la fenêtre de la VM :

| # | Écran | Ce que vous faites |
|---|-------|--------------------|
| 1 | *Press any key to boot from CD* | **Appuyez vite sur une touche** — vous avez 5 secondes |
| 2 | Langue | Français (France) / Français (France) / Clavier **Français** |
| 3 | — | **Installer maintenant** |
| 4 | Édition | **Windows Server 2025 Standard (Expérience de bureau)** |
| 5 | Licence | Accepter les termes |
| 6 | Type d'installation | **Personnalisé (avancé)** |
| 7 | Disque | Sélectionner le disque vierge de 80 Go → **Suivant**. Ne créez aucune partition à la main. |
| 8 | Installation | ~20 min. La VM redémarre toute seule. |
| 9 | Mot de passe Administrateur | Choisissez-en un et **notez-le** |
| 10 | Connexion | `Ctrl+Alt+Suppr` → via le menu **Action** de la fenêtre VM, ou `Ctrl+Alt+Fin` |

> [!warning] Choisissez bien « Expérience de bureau »
> L'autre option (**Server Core**) n'a pas d'interface graphique. Le TP DFS utilise les consoles `dfsmgmt.msc` et `gpmc.msc` : sans bureau, vous serez coincé.

> [!tip] Vous avez raté le « Press any key » ?
> La VM affiche un shell UEFI ou « boot failed ». Éteignez et relancez :
> ```powershell
> Stop-VM DC01 -TurnOff -Force
> Start-VM DC01
> ```
> Et cette fois, cliquez dans la fenêtre et martelez une touche.

Répétez pour DC02 :

```powershell
Start-VM -Name DC02
vmconnect.exe localhost DC02
```

---

## Étape 7 — Le filet de sécurité : faire un point de contrôle

> [!important] Ne sautez pas cette étape
> Vous venez de passer une heure. Un point de contrôle Hyper-V vous permet de revenir ici en 30 secondes si vous cassez quelque chose plus tard.

```powershell
Checkpoint-VM -Name DC01 -SnapshotName "01-Windows-installe"
Checkpoint-VM -Name DC02  -SnapshotName "01-Windows-installe"

Get-VMSnapshot -VMName DC01,DC02 | Format-Table VMName, Name, CreationTime
```

> Pour revenir en arrière plus tard :
> ```powershell
> Restore-VMSnapshot -VMName DC01 -Name "01-Windows-installe" -Confirm:$false
> ```

---

## Checkpoint final de l'étape 00.1

- [ ] Hyper-V activé
- [ ] `vSwitch-Rennes` créé en **Internal**
- [ ] IP `192.168.3.254` sur la carte de l'hôte
- [ ] NAT `192.168.3.0/24` actif
- [ ] DC01 et DC02 créées, Windows Server installé, session ouverte sur le bureau
- [ ] Point de contrôle `01-Windows-installe` sur les deux VM

> [!success] État attendu
> Deux serveurs qui démarrent, avec un nom généré au hasard (genre `WIN-K3J8DQ2`), en DHCP, sans aucun rôle.
> **C'est exactement ce qu'on veut.** On les configure à l'étape suivante.

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-0-demarrer-ici) | [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/08-tp-final/tp/tp-00-2-preparer-les-serveurs) |
