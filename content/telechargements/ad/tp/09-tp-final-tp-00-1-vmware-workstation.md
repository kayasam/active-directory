# 00.1 — Variante VMware Workstation

> Durée : **1 h**
> Où : 💻 **SUR VOTRE POSTE**, VMware Workstation installé
> Alternative à : [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm)

> [!important] Réponse courte
> VMware Workstation ne fournit pas de cmdlets PowerShell équivalentes à `New-VM` ou `New-VMSwitch`.
> **PowerCLI ne convient pas ici** : ses cmdlets `New-VM` pilotent vCenter ou ESXi, pas Workstation local.
>
> On peut néanmoins automatiser presque la même chose avec :
> - `vmware-vdiskmanager.exe` pour créer les disques ;
> - un fichier `.vmx` généré par PowerShell pour définir chaque VM ;
> - `vmrun.exe` pour démarrer, arrêter et prendre des snapshots.

---

## 1 — NAT ou Host-only ?

VMware propose deux réseaux différents :

| Réseau | Rôle |
|--------|------|
| `VMnet1` **Host-only** | Réseau privé entre l'hôte et les VM, sans Internet par défaut |
| `VMnet8` **NAT** | Réseau privé auquel VMware ajoute son propre routeur NAT |

`VMnet8` possède bien une carte virtuelle sur l'hôte, mais il ne devient pas pour autant un réseau Host-only. Le TP n'utilise pas `VMnet8`, car sa passerelle VMware utilise habituellement une adresse basse du sous-réseau et risquerait d'entrer en conflit avec `DC02` en `192.168.3.2`.

Pour conserver exactement le plan du TP Hyper-V, utilisez :

```text
VMnet1 Host-only : 192.168.3.0/24
PC hôte          : 192.168.3.254
DC01             : 192.168.3.10
DC02             : 192.168.3.2
NAT              : assuré par Windows avec New-NetNat
```

---

## 2 — Configurer VMnet1

Dans VMware Workstation :

1. ouvrez **Edit > Virtual Network Editor** ;
2. cliquez sur **Change Settings** ;
3. sélectionnez `VMnet1` ;
4. choisissez **Host-only** ;
5. mettez le sous-réseau `192.168.3.0` et le masque `255.255.255.0` ;
6. cochez la connexion de l'adaptateur virtuel de l'hôte ;
7. décochez le serveur DHCP VMware ;
8. appliquez.

> [!warning] Cette partie reste graphique
> VMware Workstation n'expose pas de cmdlet PowerShell prise en charge pour créer et configurer ses VMnet locaux.

---

## 3 — Configurer l'adresse de l'hôte et le NAT

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

```powershell
$carte = Get-NetAdapter -Name "VMware Network Adapter VMnet1"

Get-NetIPAddress -InterfaceIndex $carte.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false

New-NetIPAddress -InterfaceIndex $carte.ifIndex `
    -IPAddress "192.168.3.254" -PrefixLength 24

New-NetNat -Name "NAT-Fournil" `
    -InternalIPInterfaceAddressPrefix "192.168.3.0/24"
```

Vérifiez :

```powershell
Get-NetIPAddress -InterfaceIndex $carte.ifIndex -AddressFamily IPv4
Get-NetNat -Name "NAT-Fournil"
```

> [!failure] `NAT-Fournil` existe déjà
> Vérifiez-le avec `Get-NetNat`. S'il utilise déjà `192.168.3.0/24`, gardez-le et continuez.

---

## 4 — Préparer l'ISO et le script

Créez les dossiers :

```powershell
New-Item -ItemType Directory -Path "D:\VMware-Fournil\ISO" -Force
New-Item -ItemType Directory -Path "D:\VMware-Fournil\VM" -Force
```

Placez l'ISO de Windows Server 2025 ici :

```text
D:\VMware-Fournil\ISO\ws2025.iso
```

Copiez également le script fourni dans `D:\VMware-Fournil` :

```text
00-Creer-VMware-Workstation.ps1
```

Si vous utilisez `C:`, modifiez simplement `$IsoPath` et `$VmRoot` au début du script.

---

## 5 — Créer DC01 et DC02

> 💻 **SUR VOTRE POSTE** — PowerShell **en administrateur**

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
Set-Location "D:\VMware-Fournil"
.\00-Creer-VMware-Workstation.ps1
```

Le script crée pour chaque VM :

| Élément | Valeur |
|---------|--------|
| Firmware | UEFI + Secure Boot |
| Processeurs | 4 vCPU |
| Mémoire | 4 Go fixes |
| Disque | 80 Go extensible |
| Réseau | `VMnet1` Host-only |
| ISO | Windows Server 2025 |

> [!note] Différence avec Hyper-V
> Le script Hyper-V utilise la mémoire dynamique. VMware Workstation utilise ici **4 Go fixes** par VM : évitez de démarrer les deux simultanément sur un poste disposant de peu de RAM.

Le script ouvre DC01. Pour ouvrir ensuite DC02 :

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmware.exe" `
    -x "D:\VMware-Fournil\VM\DC02\DC02.vmx"
```

Si VMware est installé sous `C:\Program Files`, adaptez le chemin.

---

## 6 — Installer Windows Server

Sur chaque VM :

1. démarrez sur l'ISO ;
2. sélectionnez **Windows Server 2025 Standard (Expérience de bureau)** ;
3. choisissez l'installation **Personnalisée** ;
4. installez sur le disque de 80 Go ;
5. définissez le mot de passe de l'administrateur local.

Si le démarrage passe directement sur le disque vide, redémarrez la VM et appuyez rapidement sur une touche lorsque le message de démarrage sur CD apparaît.

---

## 7 — Prendre le premier snapshot

`vmrun` est fourni avec VMware Workstation. Fermez les deux systèmes proprement, puis lancez sur l'hôte :

```powershell
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"

& $vmrun -T ws snapshot "D:\VMware-Fournil\VM\DC01\DC01.vmx" "01-Windows-installe"
& $vmrun -T ws snapshot "D:\VMware-Fournil\VM\DC02\DC02.vmx" "01-Windows-installe"

& $vmrun -T ws listSnapshots "D:\VMware-Fournil\VM\DC01\DC01.vmx"
& $vmrun -T ws listSnapshots "D:\VMware-Fournil\VM\DC02\DC02.vmx"
```

Pour revenir au snapshot :

```powershell
& $vmrun -T ws revertToSnapshot `
    "D:\VMware-Fournil\VM\DC01\DC01.vmx" "01-Windows-installe"
```

---

## 8 — Différence importante pour la suite

`Invoke-Command -VMName`, `Start-VM`, `Restart-VM` et `Checkpoint-VM` sont des commandes **Hyper-V**. Elles ne fonctionnent pas avec VMware Workstation.

Dans les étapes `00.2`, `00.3` et `00.4` :

- ouvrez la console de la VM concernée ;
- exécutez directement dans cette VM le contenu placé entre `{` et `}` dans les blocs `Invoke-Command -VMName` ;
- remplacez `Restart-VM` par `Restart-Computer` dans la VM ;
- remplacez `Checkpoint-VM` par `vmrun snapshot` depuis l'hôte.

À partir de [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail), l'administration passe par SSH et WinRM réseau : les commandes exécutées dans les serveurs sont identiques. Seules les commandes de démarrage et de snapshot restent propres à l'hyperviseur.

---

## Checkpoint final

- [ ] `VMnet1` est en Host-only sur `192.168.3.0/24`, DHCP désactivé
- [ ] l'hôte possède `192.168.3.254/24` sur VMnet1
- [ ] `NAT-Fournil` existe
- [ ] DC01 et DC02 possèdent chacune un disque de 80 Go et 4 Go de RAM
- [ ] Windows Server 2025 avec interface graphique est installé
- [ ] le snapshot `01-Windows-installe` existe sur les deux VM

---

## Références

- [Créer une VM dans VMware Workstation](https://knowledge.broadcom.com/external/article/315434)
- [VMware Workstation, réseaux NAT et Host-only](https://knowledge.broadcom.com/external/article/315594)
- [Installer Windows Server 2025 dans une VM VMware](https://knowledge.broadcom.com/external/article/371350)

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.0-DEMARRER-ICI](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-0-demarrer-ici) | [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-2-preparer-les-serveurs) |
