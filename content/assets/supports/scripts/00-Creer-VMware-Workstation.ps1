# Crée DC01 et DC02 pour VMware Workstation.
# Prérequis : VMnet1 configuré en Host-only, 192.168.3.0/24, DHCP désactivé.

$IsoPath = "D:\VMware-Fournil\ISO\ws2025.iso"
$VmRoot = "D:\VMware-Fournil\VM"
$Vmnet = "VMnet1"
$DiskSize = "80GB"
$MemoryMB = 4096
$CpuCount = 4

$workstationFolders = @(
    "C:\Program Files (x86)\VMware\VMware Workstation",
    "C:\Program Files\VMware\VMware Workstation"
)

$workstationFolder = $workstationFolders |
    Where-Object { Test-Path (Join-Path $_ "vmware-vdiskmanager.exe") } |
    Select-Object -First 1

if (-not $workstationFolder) {
    throw "VMware Workstation ou vmware-vdiskmanager.exe est introuvable."
}

$vdiskManager = Join-Path $workstationFolder "vmware-vdiskmanager.exe"
$vmware = Join-Path $workstationFolder "vmware.exe"

if (-not (Test-Path $IsoPath)) {
    throw "ISO introuvable : $IsoPath"
}

New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null
$isoVmx = $IsoPath -replace '\\','/'

foreach ($vmName in "DC01","DC02") {
    $vmFolder = Join-Path $VmRoot $vmName
    $diskPath = Join-Path $vmFolder "$vmName.vmdk"
    $vmxPath = Join-Path $vmFolder "$vmName.vmx"

    if (Test-Path $vmxPath) {
        throw "La VM $vmName existe déjà : $vmxPath"
    }

    New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null

    & $vdiskManager -c -s $DiskSize -a lsilogic -t 0 $diskPath
    if ($LASTEXITCODE -ne 0) {
        throw "Échec de création du disque de $vmName."
    }

    $vmx = @"
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "20"
displayName = "$vmName"
guestOS = "windows2022srvnext-64"
firmware = "efi"
uefi.secureBoot.enabled = "TRUE"

memsize = "$MemoryMB"
numvcpus = "$CpuCount"
cpuid.coresPerSocket = "2"

scsi0.present = "TRUE"
scsi0.virtualDev = "lsisas1068"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$vmName.vmdk"

sata0.present = "TRUE"
sata0:1.present = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "$isoVmx"
sata0:1.startConnected = "TRUE"

ethernet0.present = "TRUE"
ethernet0.connectionType = "custom"
ethernet0.vnet = "$Vmnet"
ethernet0.virtualDev = "e1000e"
ethernet0.addressType = "generated"

usb.present = "TRUE"
sound.present = "FALSE"
floppy0.present = "FALSE"
tools.syncTime = "TRUE"
bios.bootOrder = "cdrom,hdd"
"@

    Set-Content -LiteralPath $vmxPath -Value $vmx -Encoding utf8
    Write-Host "VM $vmName créée : $vmxPath" -ForegroundColor Green
}

# Ouvre la première VM dans VMware Workstation pour commencer l'installation.
& $vmware -x (Join-Path $VmRoot "DC01\DC01.vmx")

Write-Host "Installez Windows sur DC01, puis ouvrez DC02\DC02.vmx." -ForegroundColor Cyan
