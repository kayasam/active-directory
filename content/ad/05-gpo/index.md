---
title: "05. Stratégies de groupe (GPO)"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/05-gpo"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/05-gpo/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/05-gpo/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/cours/05-gpo.md">↓ Télécharger le cours (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>

> **Objectif** : Créer, configurer et appliquer des stratégies de groupe. Comprendre l'héritage et le filtrage. Diagnostiquer une GPO qui ne s'applique pas.

> [!INFO] Fil rouge — Fournil
> Domaine : `ad.fournil.lab` — NetBIOS : `FOURNIL` — DC : `DC01`

**Outils abordés :** `gpmc.msc`, `gpedit.msc`, `gpupdate`, `gpresult`
**Concepts clés :** GPO, liaison, héritage LSDOU, filtrage, RSOP

---

## 1. Qu'est-ce qu'une GPO ?

Une **Group Policy Object (GPO)** est un ensemble de paramètres appliqués automatiquement aux **ordinateurs** et aux **utilisateurs** dans un domaine Active Directory.

Les GPO permettent de :
- configurer la sécurité
- imposer des restrictions (fond d'écran, Panneau de configuration...)
- déployer des paramètres Windows
- mapper des lecteurs réseau à la connexion
- gérer les applications et scripts

> Les GPO sont un pilier de l'administration Windows : elles garantissent **homogénéité et sécurité** sans intervention manuelle sur chaque poste.

- [Qu'est-ce qu'une stratégie de groupe ou GPO ? — IT-Connect](https://www.it-connect.fr/chapitres/quest-ce-quune-strategie-de-groupe-ou-gpo/)
- [Vue d'ensemble des stratégies de groupe — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

---

## 2. Les outils pour gérer les GPO

### GPMC (Group Policy Management Console)

Commande : `gpmc.msc`

Permet :
- créer / modifier des GPO
- les lier aux OUs
- gérer l'héritage
- faire du filtrage par groupe

```
Forêt: ad.fournil.lab
└── Domaines
    └── ad.fournil.lab
        ├── Default Domain Policy        ← GPO liée au domaine (stratégie mdp)
        ├── OU=Fournil
        │   ├── OU=Utilisateurs
        │   │   └── OU=Production
        │   │       └── GPO_Lecteur_Production
        │   └── OU=Ordinateurs
        │       └── GPO_Securite_Postes
        └── Domain Controllers
            └── Default Domain Controllers Policy
```

> [!WARNING] Default Domain Policy
> Cette GPO s'applique à tout le domaine. Elle contient la **stratégie de mot de passe**. Ne pas la modifier pour autre chose — créer des GPO dédiées à la place.

> [Gestion des GPO sur l'OU Domain Controllers — IT-Connect](https://www.it-connect.fr/securite-active-directory-gestion-des-gpo-sur-lou-domain-controllers/)
> [Console GPMC — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/group-policy/group-policy-management-console)

### Éditeur de GPO

Commande : `gpedit.msc` (local) ou depuis GPMC → Modifier une GPO.

Contient :
- **Configuration ordinateur** — s'applique à la machine au démarrage
- **Configuration utilisateur** — s'applique à l'utilisateur à la connexion

---

## 3. Structure d'une GPO

Chaque GPO est divisée en deux sections :

| Section | S'applique à | Quand |
|---------|-------------|-------|
| **Configuration ordinateur** | La machine | Au démarrage |
| **Configuration utilisateur** | L'utilisateur connecté | À l'ouverture de session |

Dans chaque section, on trouve :
- **Stratégies** — paramètres Windows gérés (sécurité, scripts, modèles d'administration)
- **Préférences** — paramètres non forcés (lecteurs réseau, raccourcis, variables d'environnement)

---

## 4. Créer et lier une GPO

### Via GPMC (GUI)

**Créer une GPO :**
1. Dans `gpmc.msc`, clic droit sur l'OU cible → **Créer un objet GPO dans ce domaine et le lier ici**
2. Donner un nom explicite (ex : `GPO_Fournil_FondEcran`)
3. Clic droit sur la GPO → **Modifier** → configurer les paramètres

**Lier une GPO existante à une OU :**
1. Clic droit sur l'OU → **Lier un objet GPO existant**
2. Sélectionner la GPO

### Via PowerShell

```powershell
# Créer une GPO
New-GPO -Name "GPO_Fournil_FondEcran"

# Lier la GPO à une OU
New-GPLink -Name "GPO_Fournil_FondEcran" `
           -Target "OU=Fournil,DC=ad,DC=fournil,DC=lab"

# Créer et lier en une seule commande
New-GPO -Name "GPO_Securite_Postes" | New-GPLink -Target "OU=Ordinateurs,OU=Fournil,DC=ad,DC=fournil,DC=lab"
```

- [New-GPO — Microsoft Learn](https://learn.microsoft.com/fr-fr/powershell/module/grouppolicy/new-gpo)

---

## 5. Héritage et ordre d'application — LSDOU

Ordre d'application des stratégies (le dernier gagne en cas de conflit) :

```
L → Local   (GPO locale sur la machine)
S → Site    (GPO liée au site AD)
D → Domaine (GPO liée au domaine)
OU → Unités d'organisation (de la racine vers la feuille)
```

> **Les GPO d'OU ont généralement le plus fort impact.**

- [Group Policy processing — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/group-policy/group-policy-processing)

### Priorité entre plusieurs GPO liées à la même OU

Quand plusieurs GPO sont liées à une même OU, celle avec **l'ordre de lien le plus bas** est appliquée en dernier (priorité la plus haute). On modifie l'ordre via les flèches haut/bas dans GPMC.

### Blocage et forçage de l'héritage

| Option | Effet | Utilisation |
|--------|-------|------------|
| **Bloquer l'héritage** (sur une OU) | Ignore les GPO des niveaux supérieurs | OU avec règles spéciales |
| **Appliqué / Enforced** (sur une GPO) | Impossible à bloquer par les OUs enfants | GPO critique de sécurité |

---

## 6. Filtrage des GPO

Par défaut, une GPO s'applique à tous les objets de l'OU. On peut la restreindre par groupe de sécurité.

### Via GPMC

Dans les propriétés de la GPO → onglet **Étendue** → **Filtrage de sécurité** :
1. Retirer `Utilisateurs authentifiés`
2. Ajouter uniquement le groupe cible (ex : `GG_Production`)

> [!WARNING] Permissions "Lire" obligatoires
> Pour qu'une GPO s'applique à un groupe, ce groupe doit avoir les permissions **Lire** ET **Appliquer la stratégie de groupe**. Vérifier l'onglet **Délégation** après modification du filtrage.

### Via PowerShell

```powershell
# Retirer Utilisateurs authentifiés
Set-GPPermission -Name "GPO_Lecteur_Production" `
                 -TargetName "Utilisateurs authentifiés" `
                 -TargetType Group -PermissionLevel None

# Ajouter uniquement GG_Production
Set-GPPermission -Name "GPO_Lecteur_Production" `
                 -TargetName "GG_Production" `
                 -TargetType Group -PermissionLevel GpoApply
```

---

## 7. Paramètres courants

### Fond d'écran (Configuration utilisateur)

`Configuration utilisateur → Modèles d'administration → Bureau → Bureau`
→ **Papier peint du Bureau** : `\\DC01\NETLOGON\fond.jpg` (le fichier doit être déposé dans `NETLOGON`, c'est-à-dire `C:\Windows\SYSVOL\sysvol\ad.fournil.lab\scripts` sur le DC)

![ad-tp05-sdupont-fond-gpo](https://cours.kaya.ovh/active-directory/assets/supports/b8e25f9d4b9d680e862a.png)
*Session d'un utilisateur de l'OU `Utilisateurs` sur un poste du domaine : le fond est imposé par la GPO.*

### Mappage de lecteurs réseau (Configuration utilisateur — Préférences)

`Configuration utilisateur → Préférences → Paramètres Windows → Mappages de lecteurs`
→ **Nouveau → Lecteur mappé** : lettre `P:`, chemin `\\DC01\Production`

![ad-tp05-sdupont-lecteur-p](https://cours.kaya.ovh/active-directory/assets/supports/e86e4f3242145dae9487.png)
*Le lecteur `P:` apparaît dans « Emplacements réseau ». Avec un filtrage de sécurité sur `GG_Production`, seuls les membres de ce groupe le reçoivent.*

> [!WARNING] Lecteur mappé ≠ droit d'écrire
> Le mappage ne donne aucun droit. Ce qui compte, c'est la combinaison des permissions **de partage** et **NTFS**, et c'est la **plus restrictive** qui l'emporte. Un partage en *Lecture* seule bloque l'écriture même avec un droit NTFS *Modification*.

### Verrouillage de session (Configuration ordinateur)

`Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Options de sécurité`
→ **Ouverture de session interactive : limite d'inactivité de la machine** : 600 secondes

### Désactiver le Panneau de configuration (Configuration utilisateur)

`Configuration utilisateur → Modèles d'administration → Panneau de configuration`
→ **Interdire l'accès au Panneau de configuration et à l'application Paramètres du PC** : Activé

- [Modèles d'administration GPO — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/group-policy/group-policy-administrative-templates)

---

## 8. Forcer l'application et diagnostiquer

### Rafraîchissement automatique

Les GPO se rafraîchissent automatiquement toutes les **90 minutes** (avec un décalage aléatoire de 30 min pour éviter les tempêtes réseau).

### Forcer l'actualisation

```powershell
# Sur la machine locale
gpupdate /force

# À distance sur une machine du domaine
Invoke-GPUpdate -Computer "PC-DIRECTION-01" -Force
```

### Diagnostiquer avec gpresult

```powershell
# Rapport HTML complet (ouvrir dans un navigateur)
gpresult /H C:\rapport_gpo.html

# Résumé dans la console
gpresult /r

# Pour un utilisateur spécifique (qui a déjà ouvert une session sur ce poste)
gpresult /user cfontaine /r
```

![ad-tp05-gpresult-tvidal](https://cours.kaya.ovh/active-directory/assets/supports/782a5a8a28e3cc7c14b3.png)
*`gpresult /r /scope user` dans la session de `tvidal` : `GPO_Fond_Ecran` est appliquée, `GPO_Lecteur_Production` est écartée par le filtrage de sécurité (« Refusé (Sécurité) »).*

> [!TIP] Checklist de dépannage GPO
> 1. La GPO est-elle bien **liée** à la bonne OU ?
> 2. La GPO est-elle **activée** (`gpmc.msc` → État de la liaison) ?
> 3. Le **filtrage de sécurité** inclut-il bien l'objet ciblé ?
> 4. Y a-t-il une GPO de **priorité supérieure** qui écrase le paramètre ?
> 5. A-t-on fait un `gpupdate /force` après la modification ?
> 6. `gpresult` affiche « applied from: **N/A** » et aucune GPO ? Le poste **n'a pas redémarré depuis sa jonction au domaine**.

- [Dépannage des GPO — Microsoft Learn](https://learn.microsoft.com/fr-fr/windows-server/identity/ad-ds/manage/group-policy/group-policy-troubleshooting)

---

## 9. Bonnes pratiques GPO

- **Créer une GPO par besoin**, pas des GPO fourre-tout
- Ne pas lier de GPO directement au **domaine** (sauf stratégie de mot de passe)
- Préférer les **OUs** bien structurées pour lier les GPO
- Documenter les GPO (champ description obligatoire)
- Tester dans une OU de test avant déploiement
- Utiliser le **filtrage par groupe** si la GPO ne doit pas s'appliquer à tout le monde
- Ne jamais modifier la **Default Domain Controllers Policy** sans raison

---

> [!NOTE] À retenir
>
> - Les GPO configurent utilisateurs et ordinateurs via AD — zéro intervention manuelle sur les postes.
> - L'ordre d'application est **LSDOU** — les GPO d'OU ont la priorité.
> - Les GPO doivent être **liées** à une OU, un site ou le domaine pour s'appliquer.
> - **gpupdate /force** rafraîchit les GPO, **gpresult** diagnostique ce qui s'applique.
> - Bonne pratique : une GPO = un besoin, liée à l'OU la plus précise possible.

---

## Résumé commandes

| Action | GUI | PowerShell |
|--------|-----|-----------|
| Créer une GPO | `gpmc.msc` → Créer et lier | `New-GPO` + `New-GPLink` |
| Forcer l'application | `gpupdate /force` | `Invoke-GPUpdate` |
| Diagnostiquer | `gpresult /H rapport.html` | `Get-GPResultantSetOfPolicy` |
| Lister les GPO | `gpmc.msc` | `Get-GPO -All` |
| Filtrage par groupe | Propriétés → Étendue → Filtrage | `Set-GPPermission` |
