# TP 08 — Tiering : cloisonner l'administration

> Durée estimée : 1h45

> Chapitres associés : [08. Tiering : cloisonner l'administration](https://cours.kaya.ovh/active-directory/ad/08-tiering/)

---

## Contexte — Fournil

Aujourd'hui, chez Fournil, l'admin système utilise le même compte pour tout, et le support se connecte aux postes avec un compte très privilégié. Après un audit, la direction veut **cloisonner l'administration** : chaque compte d'administration ne doit pouvoir se connecter qu'au niveau qui le concerne.

## Objectifs

- Classer les machines et les comptes de Fournil en Tier 0 / 1 / 2
- Créer l'arborescence, les groupes et les comptes d'administration par niveau
- Interdire par GPO la connexion des comptes Tier 0 et Tier 1 sur les postes
- Protéger le compte Tier 0 avec `Protected Users`
- Déployer Windows LAPS sur les postes

## Prérequis

- `DC01` (`192.168.3.10`) et `PC-PROD-01` joint au domaine, dans `OU=Postes,OU=Ordinateurs` (TP 03)
- Stratégie de mot de passe du TP 06 en place : **10 caractères minimum**. Dans ce TP, les comptes d'administration utilisent `Adm!Fournil@2026`.

---

## Partie A — Classer en niveaux (15 min)

**A1.** Classe chaque élément dans le bon niveau (Tier 0, 1 ou 2) et justifie en une phrase :

| Élément | Tier ? |
|---|---|
| `DC01`, `DC02` | |
| `PC-PROD-01`, `PC-DIRECTION-01` | |
| Le futur serveur de fichiers `SRV-FIC01` | |
| L'hôte **Hyper-V** qui fait tourner `DC01` | |
| `svc_backup`, s'il sauvegarde l'état du système des DC (TP 07) | |
| Le groupe `Admins du domaine` | |
| `helpdesk` et `jrenard` (support) | |

**A2.** Un technicien, membre de `Admins du domaine`, ouvre une session sur `PC-PROD-01` pour réinstaller une imprimante. Le poste était infecté depuis la veille. Explique ce que l'attaquant peut obtenir, et jusqu'où il peut aller.

**A3.** Pourquoi la règle d'or interdit-elle de « descendre » (un compte Tier 0 sur un poste), mais pas de « monter » de la même façon (un compte Tier 2 qui tente d'ouvrir une session sur un DC) ?

---

## Partie B — Comptes et groupes par niveau (20 min)

**B1.** Crée l'OU `Administration` à la racine du domaine, avec trois sous-OU `Tier0`, `Tier1` et `Tier2`.

**B2.** Crée dans chaque sous-OU le groupe global de sécurité correspondant : `GG_Tier0_Admins`, `GG_Tier1_Admins`, `GG_Tier2_Admins`.

**B3.** Crée les trois comptes d'administration (mot de passe `Adm!Fournil@2026`) et ajoute-les à leur groupe :

| Compte | OU | Groupe |
|---|---|---|
| `adm0.sysinfo` | `Tier0` | `GG_Tier0_Admins` |
| `adm1.sysinfo` | `Tier1` | `GG_Tier1_Admins` |
| `adm2.jrenard` | `Tier2` | `GG_Tier2_Admins` |

**B4.** Ajoute `GG_Tier0_Admins` au groupe `Admins du domaine`. Vérifie avec une commande que `adm0.sysinfo` est bien, indirectement, administrateur du domaine.

**B5.** `adm.sysinfo`, créé au TP 06, est membre de `Opérateurs de compte`. Dans quel niveau ce compte se trouve-t-il réellement ? Que faudrait-il en faire ?

---

## Partie C — Faire respecter la règle (30 min)

**C1.** Crée la GPO `GPO_Tier2_Postes`, liée à `OU=Postes,OU=Ordinateurs`. Dans **Attribution des droits utilisateur**, ajoute `GG_Tier0_Admins`, `GG_Tier1_Admins` et `Admins du domaine` aux quatre droits suivants :
- Interdire l'ouverture d'une session locale
- Interdire l'ouverture de session par les services Bureau à distance
- Interdire l'ouverture de session en tant que tâche
- Interdire l'ouverture de session en tant que service

**C2.** Dans la même GPO, utilise les **Groupes restreints** pour que `GG_Tier2_Admins` devienne membre du groupe local `Administrateurs` des postes. Quelle section utilises-tu : « Membres de ce groupe » ou « Ce groupe est membre de » ? Pourquoi ?

**C3.** Sur `PC-PROD-01` : lance `gpupdate /force`, puis vérifie avec `gpresult` que la GPO est appliquée. Affiche ensuite les membres du groupe local `Administrateurs`.

**C4.** Toujours sur `PC-PROD-01`, tente d'ouvrir une session avec :
- `FOURNIL\adm0.sysinfo`
- `FOURNIL\adm2.jrenard`

Que se passe-t-il dans chaque cas ? `adm2.jrenard` est-il administrateur du poste ?

**C5.** Crée de la même façon la GPO `GPO_Tier1_Serveurs`, liée à `OU=Serveurs,OU=Ordinateurs` : elle interdit la connexion de `GG_Tier0_Admins`, `GG_Tier2_Admins` et `Admins du domaine`, et rend `GG_Tier1_Admins` administrateur local.

**C6.** Pourquoi ne faut-il **jamais** lier ces GPO à la racine du domaine ni à l'OU `Domain Controllers` ?

---

## Partie D — Protected Users (10 min)

**D1.** Ajoute `adm0.sysinfo` au groupe `Protected Users`, puis vérifie.

**D2.** Depuis `PC-PROD-01` (session `adm2.jrenard`), compare :
```powershell
net use \\DC01\IPC$ /user:FOURNIL\adm0.sysinfo *
net use \\192.168.3.10\IPC$ /user:FOURNIL\adm0.sysinfo *
```
Supprime chaque connexion après l'essai (`net use * /delete /y`). Explique la différence de résultat.

**D3.** Pourquoi ne faut-il pas ajouter `svc_backup` (TP 06) à `Protected Users` ?

---

## Partie E — Windows LAPS sur les postes (25 min)

**E1.** Sur `DC01`, étends le schéma AD pour Windows LAPS.

**E2.** Autorise les ordinateurs de `OU=Postes,OU=Ordinateurs` à enregistrer leur propre mot de passe LAPS.

**E3.** Crée la GPO `GPO_LAPS_Postes`, liée à `OU=Postes,OU=Ordinateurs`, avec les paramètres :
- Configurer le répertoire de sauvegarde des mots de passe : **Active Directory**
- Paramètres du mot de passe : complexité maximale, **16** caractères, **30** jours

**E4.** Sur `PC-PROD-01` : applique la stratégie, puis force le traitement LAPS. Dans quel journal vérifier que tout s'est bien passé ?

**E5.** Sur `DC01`, affiche le mot de passe administrateur local de `PC-PROD-01`. Retrouve-le aussi dans `dsa.msc`.

**E6.** Donne le droit de lire les mots de passe LAPS des postes au groupe `GG_Tier2_Admins`, et à lui seul.

---

## Partie F — Bonus

**F1.** Liste les comptes marqués `adminCount = 1`. Que signifie cet attribut ? Retrouves-tu des comptes qui ne devraient plus être privilégiés ?

**F2.** Après une intervention avec le mot de passe LAPS de `PC-PROD-01`, quelle commande force immédiatement un nouveau mot de passe ?

---

[Ouvrir la correction](https://cours.kaya.ovh/active-directory/ad/08-tiering/tp-corrigev2)


[Afficher les corrections](https://cours.kaya.ovh/active-directory/ad/08-tiering/tp-corrigev2)
