# TP 05 — Stratégies de groupe (GPO)

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

**A2.** Crée une GPO nommée `GPO_Fond_Ecran` liée à `OU=Utilisateurs`.

**A3.** Modifie la GPO pour imposer un fond d'écran. Chemin du paramètre :
`Configuration utilisateur → Modèles d'administration → Bureau → Bureau → Papier peint du Bureau`

Utilise `\\DC01\NETLOGON\fond.jpg` comme chemin (le dossier NETLOGON est un partage accessible à tous les utilisateurs du domaine).

**A4.** Sur un poste client (ou via `runas`), ouvre une session avec `jrenard`. Lance `gpupdate /force` puis vérifie si le fond d'écran est appliqué.

**A5.** Quelle commande permet de voir toutes les GPO appliquées à `jrenard` ?

---

## Partie B — GPO ordinateur : verrouillage de session (20 min)

**B1.** Crée une GPO nommée `GPO_Securite_Postes` liée à `OU=Ordinateurs`.

**B2.** Configure le verrouillage automatique après **10 minutes** d'inactivité. Chemin :
`Configuration ordinateur → Paramètres Windows → Paramètres de sécurité → Stratégies locales → Options de sécurité → Ouverture de session interactive : limite d'inactivité de la machine`

**B3.** Configure également le nombre de tentatives de connexion avant verrouillage du compte à **5**. Où se trouve ce paramètre dans la GPO ?

**B4.** Force l'application sur le poste client et vérifie avec :
```powershell
gpresult /r
```
La GPO `GPO_Securite_Postes` apparaît-elle dans les GPO ordinateur appliquées ?

---

## Partie C — Mappage de lecteur réseau (20 min)

**C1.** Crée un partage réseau `\\DC01\Production` pointant vers `C:\Partages\fournil\Production` (créé au TP 03). Les permissions **de partage** doivent permettre au groupe `DL_Partage_Production_Ecriture` d'**écrire** : n'oublie pas qu'elles se combinent avec les permissions NTFS.

**C2.** Crée une GPO nommée `GPO_Lecteur_Production` liée à `OU=Utilisateurs`.

**C3.** Dans la GPO, configure un mappage du lecteur `P:` vers `\\DC01\Production` :
`Configuration utilisateur → Préférences → Paramètres Windows → Mappages de lecteurs`
→ Nouveau lecteur mappé, action : **Créer**, lettre : `P:`, chemin : `\\DC01\Production`

**C4.** La GPO doit s'appliquer uniquement au groupe `GG_Production`. Configure le filtrage de sécurité pour cibler uniquement ce groupe.

**C5.** Connecte-toi avec `sdupont` (membre de `GG_Production`) et vérifie que le lecteur `P:` est mappé. Connecte-toi ensuite avec `tvidal` (Commercial) : le lecteur doit être absent.

---



## Partie E — Bonus

**E1.** Génère un rapport HTML complet des GPO appliquées à `jrenard` :
```powershell
gpresult /user jrenard /H C:\rapport_jrenard.html
```
Ouvre le rapport et identifie la section "Objets de stratégie de groupe gagnants".

**E2.** Via PowerShell, liste toutes les GPO du domaine et leur état de liaison :
```powershell
Get-GPO -All | Select-Object DisplayName, GpoStatus
```

---

[Ouvrir la correction](https://cours.kaya.ovh/active-directory/ad/05-gpo/tp-corrigev2)


[Afficher les corrections](https://cours.kaya.ovh/active-directory/ad/05-gpo/tp-corrigev2)
