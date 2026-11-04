# TP 05 — Stratégies de groupe (GPO) — Correction

> Essaie chaque question avant d’ouvrir **Afficher la correction**. Chaque réponse se replie indépendamment.

> Durée estimée : 1h30

> Chapitres associés : [05. Stratégies de groupe (GPO)](https://cours.kaya.ovh/active-directory/ad/05-gpo/)

---

## Objectifs

- Créer et lier des GPO via GPMC et PowerShell
- Configurer des paramètres utilisateur et ordinateur courants
- Comprendre l'héritage et tester le filtrage par groupe
- Diagnostiquer l'application des GPO avec `gpresult`

---

## Prérequis

- Domaine `ad.fournil.lab` avec les OUs du TP 02
- Utilisateurs et groupes du TP 03
- Un poste client joint au domaine (ou utiliser le DC pour les tests utilisateur)

---

## Partie A — Première GPO : fond d'écran (20 min)

**A1.** Ouvre la console `gpmc.msc`. Quelles GPO sont déjà liées au domaine ?

> [!success]- Afficher la correction — A1
> GPO liées par défaut au domaine :
> - **Default Domain Policy** — contient la stratégie de mot de passe du domaine
> - **Default Domain Controllers Policy** — s'applique uniquement à l'OU `Domain Controllers`

**A2.** Crée une GPO nommée `GPO_Fond_Ecran` liée à `OU=Utilisateurs`.

> [!success]- Afficher la correction — A2
> Via `gpmc.msc` : clic droit sur `OU=Utilisateurs` → Créer un objet GPO dans ce domaine et le lier ici → nom : `GPO_Fond_Ecran`.
>
> Via PowerShell :
> ```powershell
> New-GPO -Name "GPO_Fond_Ecran" | New-GPLink -Target "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```

**A3.** Modifie la GPO pour imposer un fond d'écran. Chemin du paramètre :
`Configuration utilisateur → Modèles d'administration → Bureau → Bureau → Papier peint du Bureau`

Utilise `\\DC01\NETLOGON\fond.jpg` comme chemin (le dossier NETLOGON est un partage accessible à tous les utilisateurs du domaine).

> [!success]- Afficher la correction — A3
> Dans l'éditeur de GPO :
> `Configuration utilisateur → Modèles d'administration → Bureau → Bureau → Papier peint du Bureau`
> - État : **Activé**
> - Papier peint : `\\DC01\NETLOGON\fond.jpg`
> - Style : Étendu (ou Centre)
>
> > L'image doit **exister** dans le partage. `NETLOGON` correspond à `C:\Windows\SYSVOL\sysvol\ad.fournil.lab\scripts` sur le DC :
> > ```powershell
> > Copy-Item C:\Users\Administrateur\Pictures\fond.jpg "\\DC01\NETLOGON\fond.jpg"
> > ```
> > Elle est ensuite répliquée vers les autres DC avec SYSVOL. Utiliser une image **reconnaissable** (logo Fournil, couleur unie) : avec l'image par défaut de Windows, on ne voit pas si la GPO s'applique.

**A4.** Sur un poste client (ou via `runas`), ouvre une session avec `jrenard`. Lance `gpupdate /force` puis vérifie si le fond d'écran est appliqué.

> [!success]- Afficher la correction — A4
> ```
> gpupdate /force
> ```
> Le fond d'écran s'applique à la **prochaine ouverture de session** (déconnexion/reconnexion) : `gpupdate /force` met à jour la stratégie, mais l'Explorateur ne recharge pas toujours le papier peint à chaud. Si le fichier image n'est pas accessible, Windows affiche un fond uni : vérifier que le chemin UNC est accessible à l'utilisateur.
>
> ![ad-tp05-sdupont-fond-gpo](https://cours.kaya.ovh/active-directory/assets/supports/b8e25f9d4b9d680e862a.png)
> *Session de `sdupont` sur PC-PROD-01 : le fond imposé par `GPO_Fond_Ecran` est appliqué.*

**A5.** Quelle commande permet de voir toutes les GPO appliquées à `jrenard` ?

> [!success]- Afficher la correction — A5
> ```powershell
> gpresult /r /scope user          # dans la session de l'utilisateur
> # depuis une session administrateur, pour un utilisateur déjà connecté au poste :
> gpresult /user FOURNIL\jrenard /r
> # ou rapport HTML :
> gpresult /user FOURNIL\jrenard /H C:\gpo_jrenard.html
> ```
> > `gpresult /user` ne fonctionne que si l'utilisateur **a déjà ouvert une session** sur ce poste (le résultat RSoP est enregistré à la connexion). Sinon : *« The user does not have RSoP data »*.

## Partie B — GPO ordinateur : verrouillage de session (20 min)

**B1.** Crée une GPO nommée `GPO_Securite_Postes` liée à `OU=Ordinateurs`.

> [!success]- Afficher la correction — B1
> ```powershell
> New-GPO -Name "GPO_Securite_Postes" | New-GPLink -Target "OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```

**B2.** Configure le verrouillage automatique après **10 minutes** d'inactivité. Chemin :
`Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Options de sécurité → Ouverture de session interactive : limite d'inactivité de la machine`

> [!success]- Afficher la correction — B2
> Chemin : `Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Options de sécurité`
> Paramètre : **Ouverture de session interactive : limite d'inactivité de la machine** → 600 secondes (10 minutes).

**B3.** Configure également le nombre de tentatives de connexion avant verrouillage du compte à **5**. Où se trouve ce paramètre dans la GPO ?

> [!success]- Afficher la correction — B3
> Le seuil de verrouillage de compte se trouve dans :
> `Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies de compte → Stratégie de verrouillage du compte`
> → **Seuil de verrouillage du compte** : 5 tentatives.
>
> > [!warning] Piège à faire émerger
> > Les **stratégies de compte** (mot de passe, verrouillage) d'une GPO liée à une **OU** ne s'appliquent qu'aux comptes **locaux** des postes de cette OU, **pas aux comptes du domaine**. Pour que `jrenard` soit verrouillé après 5 essais, le réglage doit être dans la **Default Domain Policy** (ou une GPO liée à la racine du domaine) — c'est ce que fait le TP 06.

**B4.** Force l'application sur le poste client et vérifie avec :
```powershell
gpresult /r
```
La GPO `GPO_Securite_Postes` apparaît-elle dans les GPO ordinateur appliquées ?

> [!success]- Afficher la correction — B4
> ```powershell
> gpresult /r
> ```
> Section "Stratégies de groupe d'ordinateur appliquées" : `GPO_Securite_Postes` doit apparaître. Résultat attendu (`gpresult /scope computer /r`) :
> ```
> CN=PC-PROD-01,OU=Postes,OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab
> Group Policy was applied from:      DC01.ad.fournil.lab
> Applied Group Policy Objects
>     GPO_Securite_Postes
>     Default Domain Policy
> ```
> Vérification du réglage : `Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name InactivityTimeoutSecs` → `600`.
>
> Si la GPO est absente :
> - vérifier que l'ordinateur est bien sous `OU=Ordinateurs` et que `gpupdate /force` a été lancé (en administrateur, sinon la partie ordinateur n'est pas affichée) ;
> - si `gpresult` affiche **« Group Policy was applied from: N/A »** et aucune GPO, le poste **n'a pas redémarré depuis sa jonction au domaine** (il est encore vu comme `WORKGROUP\PC-PROD-01$`).

## Partie C — Mappage de lecteur réseau (20 min)

**C1.** Crée un partage réseau `\\DC01\Production` pointant vers `C:\Partages\fournil\Production` (créé au TP 03). Les permissions **de partage** doivent permettre au groupe `DL_Partage_Production_Ecriture` d'**écrire** : n'oublie pas qu'elles se combinent avec les permissions NTFS.

> [!success]- Afficher la correction — C1
> ```powershell
> New-SmbShare -Name "Production" -Path "C:\Partages\fournil\Production" `
>   -FullAccess "FOURNIL\Admins du domaine" `
>   -ChangeAccess "FOURNIL\DL_Partage_Production_Ecriture" `
>   -ReadAccess "FOURNIL\DL_Partage_Production_Lecture"
> ```
> Ou via le Gestionnaire de serveur : Fichiers et stockage → Partages → Nouveau partage.
>
> > [!warning] Permissions de partage ET permissions NTFS
> > Le droit effectif est le **plus restrictif des deux**. Si le partage ne donne que `-ReadAccess` à `DL_Partage_Production_Lecture`, `sdupont` (droit NTFS **Modification** via `DL_Partage_Production_Ecriture`) obtient **« L’accès au chemin d’accès 'P:\…' est refusé »** en écriture. Il faut donner **Modifier** (`-ChangeAccess`) au groupe Écriture sur le partage.
> >
> > ![ad-tp05-sdupont-ecriture-p](https://cours.kaya.ovh/active-directory/assets/supports/99bcd5a3004797b202a4.png)
> >
> > Après `Grant-SmbShareAccess -Name Production -AccountName "FOURNIL\DL_Partage_Production_Ecriture" -AccessRight Change -Force` :
> >
> > ![ad-tp05-sdupont-ecriture-p-ok](https://cours.kaya.ovh/active-directory/assets/supports/6813fe14a9bebba54610.png)
> >
> > Pratique courante en entreprise : partage en *Utilisateurs authentifiés : Modifier* (ou Contrôle total) et toute la finesse en **NTFS**. On évite ainsi ce type de conflit.
>
> > Sur un serveur en **anglais**, le groupe s'appelle `FOURNIL\Domain Admins`. Les noms des groupes intégrés dépendent de la langue d'installation.

**C2.** Crée une GPO nommée `GPO_Lecteur_Production` liée à `OU=Utilisateurs`.

> [!success]- Afficher la correction — C2
> ```powershell
> New-GPO -Name "GPO_Lecteur_Production" | New-GPLink -Target "OU=Utilisateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
> ```

**C3.** Dans la GPO, configure un mappage du lecteur `P:` vers `\\DC01\Production` :
`Configuration utilisateur → Préférences → Paramètres Windows → Mappages de lecteurs`
→ Nouveau lecteur mappé, action : **Créer**, lettre : `P:`, chemin : `\\DC01\Production`

> [!success]- Afficher la correction — C3
> Dans l'éditeur de GPO :
> `Configuration utilisateur → Préférences → Paramètres Windows → Mappages de lecteurs`
> → Clic droit → Nouveau → Lecteur mappé
> - Action : Créer
> - Emplacement : `\\DC01\Production`
> - Lettre de lecteur : `P:`
> - Reconnecter : coché

**C4.** La GPO doit s'appliquer uniquement au groupe `GG_Production`. Configure le filtrage de sécurité pour cibler uniquement ce groupe.

> [!success]- Afficher la correction — C4
> Dans les propriétés de `GPO_Lecteur_Production` → onglet **Étendue** → **Filtrage de sécurité** :
> 1. Sélectionner `Utilisateurs authentifiés` → Supprimer
> 2. Ajouter → `GG_Production`
>
> Vérifier dans l'onglet **Délégation** que `GG_Production` possède bien les permissions **Lire** et **Appliquer la stratégie de groupe**.
>
> > [!warning] MS16-072
> > Depuis ce correctif, les GPO **utilisateur** sont lues avec le compte **ordinateur**. Si on retire `Utilisateurs authentifiés` sans rien ajouter, la GPO n'est plus appliquée à personne. Dans l'onglet **Délégation**, ajouter `Ordinateurs du domaine` avec la permission **Lecture** (sans « Appliquer »).
>
> Équivalent PowerShell : on garde `Utilisateurs authentifiés` en **lecture seule** (ce qui règle aussi MS16-072) et on donne **Appliquer** à `GG_Production` :
> ```powershell
> Set-GPPermission -Name GPO_Lecteur_Production -TargetName "GG_Production" `
>   -TargetType Group -PermissionLevel GpoApply
> Set-GPPermission -Name GPO_Lecteur_Production -TargetName "Utilisateurs authentifiés" `
>   -TargetType Group -PermissionLevel GpoRead -Replace
> ```
> > Retirer complètement `Utilisateurs authentifiés` en PowerShell (`-PermissionLevel None`) déclenche une **demande de confirmation** : le script reste bloqué en session non interactive.

**C5.** Connecte-toi avec `sdupont` (membre de `GG_Production`) et vérifie que le lecteur `P:` est mappé. Connecte-toi ensuite avec `tvidal` (Commercial) : le lecteur doit être absent.

> [!success]- Afficher la correction — C5
> - `sdupont` (membre GG_Production) → lecteur `P:` mappé ✅
> - `tvidal` (Commercial, non membre GG_Production) → lecteur `P:` absent ✅
>
> Sessions de `sdupont` puis de `tvidal` sur PC-PROD-01 :
>
> ![ad-tp05-sdupont-lecteur-p](https://cours.kaya.ovh/active-directory/assets/supports/e86e4f3242145dae9487.png)
>
> ![ad-tp05-tvidal-sans-p](https://cours.kaya.ovh/active-directory/assets/supports/96de3ce6587a1db7b722.png)
>
> Le `gpresult` de `tvidal` le confirme : `GPO_Lecteur_Production` est **filtrée** (« Refusé (Sécurité) »), `GPO_Fond_Ecran` est appliquée.
>
> ![ad-tp05-gpresult-tvidal](https://cours.kaya.ovh/active-directory/assets/supports/782a5a8a28e3cc7c14b3.png)

## Partie E — Bonus

**E1.** Génère un rapport HTML complet des GPO appliquées à `jrenard` :
```powershell
gpresult /user jrenard /H C:\rapport_jrenard.html
```
Ouvre le rapport et identifie la section "Objets de stratégie de groupe gagnants".

> [!success]- Afficher la correction — E1
> ```powershell
> gpresult /user jrenard /H C:\rapport_jrenard.html
> Start-Process "C:\rapport_jrenard.html"
> ```
> Dans le rapport, la section **"Objets de stratégie de groupe gagnants"** liste les GPO effectivement appliquées. Les GPO en conflit qui ont été écrasées apparaissent dans la section **"Objets de stratégie de groupe refusés"**.

**E2.** Via PowerShell, liste toutes les GPO du domaine et leur état de liaison :
```powershell
Get-GPO -All | Select-Object DisplayName, GpoStatus
```

> [!success]- Afficher la correction — E2
> ```powershell
> Get-GPO -All | Select-Object DisplayName, GpoStatus | Sort-Object DisplayName
> ```
> Statuts possibles : `AllSettingsEnabled`, `UserSettingsDisabled`, `ComputerSettingsDisabled`, `AllSettingsDisabled`.

---

[Retour à l’énoncé](https://cours.kaya.ovh/active-directory/ad/05-gpo/tp)
