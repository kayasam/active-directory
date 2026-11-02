---
title: "00.3 — Installer AD DS et promouvoir DC01"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-00-3-promouvoir-dc01.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée : **30 min**
> Où : 💻 **SUR VOTRE POSTE**, via PowerShell Direct
> Précédent : [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-2-preparer-les-serveurs)

> [!info] Vous utilisez VMware Workstation ?
> Ouvrez la console de **DC01** et exécutez directement dans DC01 le contenu situé entre `{` et `}` dans les blocs `Invoke-Command -VMName DC01`.
> Utilisez `Restart-Computer` pour redémarrer et `vmrun snapshot` pour le checkpoint ; voir [00.1-VMware-Workstation](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-vmware-workstation).

> [!important] C'est le moment où le domaine `ad.fournil.lab` naît
> Jusqu'ici vous aviez deux PC Windows isolés. À la fin de cette note, vous avez un **annuaire d'entreprise**.

---

## Comprendre avant de lancer

### Rôle ≠ promotion

C'est la confusion classique. Ce sont **deux étapes distinctes** :

| Étape | Commande | Ce que ça fait |
|-------|----------|----------------|
| **Installer le rôle** | `Install-WindowsFeature AD-Domain-Services` | Copie les fichiers et les outils sur le disque. Le serveur ne fait encore **rien**. |
| **Promouvoir** | `Install-ADDSForest` | Crée réellement la base d'annuaire, le DNS, SYSVOL. Le serveur **devient** contrôleur de domaine. |

> Une analogie : installer le rôle, c'est livrer les meubles. Promouvoir, c'est ouvrir le magasin.

### Le vocabulaire de la promotion

| Terme | Ce que c'est ici |
|-------|------------------|
| **Forêt** | Le conteneur le plus large. On en crée une nouvelle, elle s'appellera `ad.fournil.lab`. |
| **Domaine** | `ad.fournil.lab` — le premier domaine de cette forêt, donc aussi sa racine. |
| **Nom NetBIOS** | `AD` — le nom court, historique, utilisé dans `AD\Administrateur`. |
| **DSRM** | *Directory Services Restore Mode* — un mot de passe de secours pour réparer l'annuaire s'il se corrompt. **Différent** du mot de passe administrateur. |
| **Niveau fonctionnel** | La version minimale d'AD supportée. On laisse la valeur par défaut. |

---

## Étape 1 — Installer le rôle AD DS + DNS

> 💻 **SUR VOTRE POSTE**

> [!tip] Vos identifiants ont peut-être expiré
> Si vous avez fermé PowerShell depuis l'étape 00.2, retapez :
> ```powershell
> $credDC01 = Get-Credential -Message "Admin LOCAL DC01 (Administrateur)"
> $credDC2  = Get-Credential -Message "Admin LOCAL DC02 (Administrateur)"
> ```

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
}
```

**Résultat attendu :**

```
Success Restart Needed Exit Code      Feature Result
------- -------------- ---------      --------------
True    No             Success        {Active Directory Domain Services, DNS...}
```

> [!question] À quoi sert `-IncludeManagementTools` ?
> Sans lui, le rôle s'installe mais vous n'avez **ni les consoles graphiques** (`dsa.msc`, `dnsmgmt.msc`), **ni le module PowerShell `ActiveDirectory`**.
> Vous vous retrouveriez à l'exercice 0 du TP AD avec un `Get-ADUser : terme non reconnu` incompréhensible. Ne l'oubliez jamais.

---

## Étape 2 — Créer la forêt (la promotion)

> [!warning] Lisez les paramètres avant de lancer
> La VM va **redémarrer automatiquement** à la fin. C'est normal, ne paniquez pas.

```powershell
Invoke-Command -VMName DC01 -Credential $credDC01 -ScriptBlock {

    Import-Module ADDSDeployment

    Install-ADDSForest `
        -DomainName "ad.fournil.lab" `
        -DomainNetbiosName "AD" `
        -InstallDNS `
        -SafeModeAdministratorPassword (ConvertTo-SecureString "Fournil@2026" -AsPlainText -Force) `
        -DatabasePath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -NoRebootOnCompletion:$false `
        -Force
}
```

### Chaque paramètre, expliqué

| Paramètre | Rôle |
|-----------|------|
| `-DomainName "ad.fournil.lab"` | Le nom DNS du domaine. **Doit** être celui-là : les scripts du TP le contiennent en dur. |
| `-DomainNetbiosName "AD"` | Le nom court. Vous le verrez partout : `AD\mlebrun`. |
| `-InstallDNS` | Installe et configure le serveur DNS. **Indispensable** : AD ne fonctionne pas sans DNS. |
| `-SafeModeAdministratorPassword` | Le mot de passe DSRM. Notez-le, même si vous ne vous en servirez pas au TP. |
| `-DatabasePath` / `-SysvolPath` | Où vivent la base d'annuaire et le partage SYSVOL. Valeurs par défaut, on les écrit pour que vous sachiez qu'ils existent. |
| `-Force` | Pas de confirmation interactive (elle bloquerait `Invoke-Command`). |

> [!question] Pourquoi `.lab` et pas `.local` ou `fournil.fr` ?
> - `.local` est **réservé** au protocole mDNS (Bonjour/Avahi) et provoque des résolutions erratiques. Microsoft le déconseille depuis des années.
> - `fournil.fr` serait un vrai domaine public : vos machines internes tenteraient de résoudre des noms sur Internet.
> - Dans ce lab isolé, `ad.fournil.lab` est conservé parce que tous les scripts du TP l'utilisent. En production, choisissez un **sous-domaine dédié d'un domaine que vous possédez**.

---

## Étape 3 — Attendre le redémarrage

La promotion prend 5 à 10 minutes, puis la VM redémarre. Patientez.

```powershell
# Attendre que la VM soit à nouveau prête
Wait-VM -Name DC01 -For Heartbeat
Write-Host "DC01 est reparti" -ForegroundColor Green
```

> [!important] Vos identifiants viennent de changer de nature
> `Administrateur` n'est plus un **compte local** : il est devenu l'**administrateur du domaine**.
> Pour les `Invoke-Command` suivants, saisissez le login sous la forme `AD\Administrateur` :
> ```powershell
> $credDom = Get-Credential -Message "Admin du DOMAINE (login : AD\Administrateur)"
> ```

---

## Étape 4 — Vérifier que la promotion a réussi

```powershell
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    hostname
    Get-Service ADWS, NTDS, DNS, KDC | Select-Object Name, Status
}
```

**Résultat attendu — les 4 services en `Running` :**

```
DC01

Name  Status
----  ------
ADWS  Running       <- Active Directory Web Services (c'est lui qui répond aux Get-AD*)
DNS   Running       <- le serveur DNS du domaine
KDC   Running       <- Kerberos : la distribution des tickets d'authentification
NTDS  Running       <- la base de données de l'annuaire
```

```powershell
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode, DistinguishedName
    Get-ADForest | Select-Object Name, ForestMode, GlobalCatalogs
}
```

**Résultat attendu :**

```
DNSRoot        NetBIOSName DomainMode           DistinguishedName
-------        ----------- ----------           -----------------
ad.fournil.lab AD          Windows2025Domain    DC=ad,DC=fournil,DC=lab
```

> [!success] Checkpoint 4 — le domaine existe
> `DistinguishedName = DC=ad,DC=fournil,DC=lab`. C'est exactement le `$dn` que vous utiliserez dans tout le TP AD.

---

## Étape 5 — Vérifier que le DNS s'est bien reconfiguré tout seul

```powershell
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses).ServerAddresses
}
```

> Attendu : **`127.0.0.1`** — la promotion l'a changé automatiquement.

![Schema-DNS-Etapes](https://cours.kaya.ovh/active-directory/assets/supports/d056c37c377914ce04cd.svg)

> [!question] Pourquoi DC01 s'interroge-t-il lui-même ?
> Parce qu'il **est** devenu le serveur DNS du domaine. Les enregistrements `_ldap._tcp.ad.fournil.lab`, `_kerberos._tcp...` qui permettent aux machines de trouver le DC sont dans **sa** base. Pointer ailleurs reviendrait à demander son chemin à quelqu'un qui ne connaît pas la ville.

### Restaurer l'accès Internet : le redirecteur DNS

En passant en `127.0.0.1`, DC01 ne sait plus résoudre `microsoft.com`. On lui dit à qui faire suivre les questions qu'il ne connaît pas :

```powershell
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    Set-DnsServerForwarder -IPAddress "8.8.8.8" -PassThru
}
```

```powershell
# Vérifier que la résolution externe remarche
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    Resolve-DnsName ad.fournil.lab | Select-Object -First 2 Name, IPAddress   # interne
    Resolve-DnsName www.microsoft.com | Select-Object -First 1 Name           # externe
}
```

> [!question] Redirecteur ou serveur DNS du client : quelle différence ?
> - Le **serveur DNS du client** (`Set-DnsClientServerAddress`) = « à qui je pose mes questions ». Pour un membre du domaine, **toujours un DC**.
> - Le **redirecteur** (`Set-DnsServerForwarder`) = « à qui *mon serveur DNS* refile les questions qu'il ne sait pas traiter ».
>
> C'est cette distinction qui permet d'avoir à la fois un domaine qui marche **et** Internet. La confondre est l'erreur n°1 des labs AD.

---

## Étape 6 — Vérifier SYSVOL et NETLOGON

Ces deux partages sont créés par la promotion. Le TP GPO en dépend entièrement.

```powershell
Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
    Get-SmbShare | Where-Object Name -in "SYSVOL","NETLOGON" | Select-Object Name, Path
}
```

**Résultat attendu :**

```
Name     Path
----     ----
NETLOGON C:\Windows\SYSVOL\sysvol\ad.fournil.lab\SCRIPTS
SYSVOL   C:\Windows\SYSVOL\sysvol
```

> [!failure] Les partages n'existent pas
> La promotion ne s'est pas terminée correctement. Regardez le journal :
> ```powershell
> Invoke-Command -VMName DC01 -Credential $credDom -ScriptBlock {
>     Get-EventLog -LogName "Directory Service" -Newest 20 | Format-Table TimeGenerated, EntryType, Message -Wrap
> }
> ```
> Le plus simple reste de restaurer le point de contrôle `02-Serveurs-prepares` et de recommencer.

---

## Étape 7 — Point de contrôle

```powershell
Checkpoint-VM -Name DC01 -SnapshotName "03-DC01-promu"
```

> [!tip] Ne faites PAS de snapshot d'un DC en production
> En labo c'est parfait. En production, restaurer un instantané de contrôleur de domaine peut provoquer un **USN rollback** : l'annuaire repart avec des numéros de séquence déjà utilisés, et la réplication se corrompt silencieusement.
> Retenez-le, c'est une question classique en certification.

---

## Checkpoint final de l'étape 00.3

- [ ] Rôles AD DS + DNS installés avec `-IncludeManagementTools`
- [ ] Forêt `ad.fournil.lab` créée, NetBIOS `AD`
- [ ] Services `ADWS`, `NTDS`, `DNS`, `KDC` en `Running`
- [ ] `Get-ADDomain` renvoie `DC=ad,DC=fournil,DC=lab`
- [ ] DNS client de DC01 = `127.0.0.1`
- [ ] Redirecteur DNS = `8.8.8.8`, résolution externe OK
- [ ] Partages `SYSVOL` et `NETLOGON` présents
- [ ] Point de contrôle `03-DC01-promu`

> [!success] Vous avez un domaine
> DC02 n'en fait pas encore partie. C'est l'objet de l'étape suivante.

---

| ← Précédent | Suivant → |
|-------------|-----------|
| [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-2-preparer-les-serveurs) | [00.4-Joindre-DC02](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-4-joindre-dc02) |
