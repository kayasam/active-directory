---
title: "DÉMARRER ICI — TP Le Fournil"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-00-0-demarrer-ici.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> [!important] Vous êtes au bon endroit
> C'est la **première note à lire**. Elle prend 5 minutes et vous évite de perdre une heure.
> N'ouvrez aucune autre note avant d'avoir fini celle-ci.

---

## 1 — En une phrase, on fait quoi ?

Vous êtes l'administrateur système d'une boulangerie artisanale, **Le Fournil**, qui a 30 salariés.
Votre mission : **construire de zéro toute son infrastructure Windows** — les comptes, les groupes, les dossiers partagés, les droits d'accès et un raccourci automatique sur les PC.

À la fin, quand Marc Lebrun (chef boulanger) ouvre une session, il trouve tout seul :
- un lecteur **H:** avec son dossier personnel,
- un raccourci vers les dossiers de son service,
- l'accès **en écriture** à son dossier métier, **en lecture seule** aux dossiers des autres.

---

## 2 — Le parcours complet, en un coup d'œil

![Schema-Parcours-TP](https://cours.kaya.ovh/active-directory/assets/supports/069c4209301b6cc57a06.svg)

---

## 3 — La maquette : qui est qui

Avant de taper la moindre commande, vous devez savoir **sur quelle machine vous êtes**.
C'est la source de confusion n°1 du TP.

![Schema-Reseau-Lab](https://cours.kaya.ovh/active-directory/assets/supports/697b562bfdf85aeaad03.svg)

> [!tip] La règle simple
> Vous n'ouvrez **jamais** la console directement sur DC02.
> Vous travaillez depuis **votre poste**, connecté en SSH à **DC01**, et DC01 pilote DC02 à distance.

Dans toutes les notes du TP, chaque bloc de commandes est précédé d'un badge qui dit où le taper :

| Badge | Signification |
|-------|---------------|
| 💻 **SUR VOTRE POSTE** | PowerShell ouvert sur votre Windows 10/11 |
| 🖥️ **SUR DC01** | Terminal VSCode connecté en SSH à DC01 (ou console directe) |
| 🖧 **VERS DC02** | Vous tapez sur DC01, mais ça s'exécute sur DC02 via `Invoke-Command` |

---

## 4 — Vérifiez que vous avez tout

On part vraiment de **zéro** : vous allez créer les deux serveurs vous-même.
Il vous faut donc seulement ceci. S'il manque une ligne, appelez le formateur **maintenant**, pas dans 2 heures.

- [ ] Un PC en **Windows 10/11 Pro, Entreprise ou Éducation** (Famille n'a pas Hyper-V)
- [ ] La **virtualisation activée** dans le BIOS (Intel VT-x / AMD-V)
- [ ] **8 Go de RAM** minimum, 16 Go de préférence
- [ ] **80 Go d'espace disque libre** minimum, 150 Go de préférence
- [ ] Les **droits administrateur** sur ce PC
- [ ] L'**ISO de Windows Server 2025** (version d'évaluation, 180 jours, gratuite)
- [ ] Le dossier `scripts/` du TP (les 2 CSV + les 4 .ps1)

> [!note] Rien n'est préinstallé, et c'est le but
> Vous montez l'infrastructure de A à Z : les machines virtuelles, le réseau, les serveurs, le domaine.
> C'est exactement ce qu'on vous demandera de faire en entreprise. Comptez **3 h** pour cette phase.

---

## 5 — Ce que vous allez monter avant de commencer le TP

![Schema-Montage-Lab](https://cours.kaya.ovh/active-directory/assets/supports/57c7f5c51af00acdf351.svg)

Deux machines virtuelles sur votre PC, reliées par un réseau virtuel privé, avec un accès Internet via NAT.
À la fin de la phase de montage, `ad.fournil.lab` existera et vous en serez l'administrateur.

---

## 6 — L'ordre à suivre, sans exception

### Phase A — Monter le lab (≈ 3 h, une seule fois)

| Ordre | Note | Durée | C'est quoi |
|-------|------|-------|------------|
| **1** | [00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm) | 1 h | Hyper-V, le réseau virtuel, les 2 VM, Windows Server |
| **1 bis** | [00.1-VMware-Workstation](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-vmware-workstation) | 1 h | Variante pour un poste équipé de VMware Workstation |
| **2** | [00.2-Preparer-les-Serveurs](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-2-preparer-les-serveurs) | 45 min | Nommer, adresser, mettre à jour les 2 serveurs |
| **3** | [00.3-Promouvoir-DC01](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-3-promouvoir-dc01) | 30 min | Installer AD DS et créer le domaine `ad.fournil.lab` |
| **4** | [00.4-Joindre-DC02](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-4-joindre-dc02) | 30 min | Joindre DC02 et le promouvoir en DC additionnel |
| **5** | [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail) | 30 min | Brancher VSCode en SSH + ouvrir le pare-feu |

### Phase B — Le TP proprement dit (≈ 5 h)

| Ordre | Note | Durée | C'est quoi |
|-------|------|-------|------------|
| **6** | [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-debutant-ad) | 2 h | Les OUs, groupes, permissions, utilisateurs |
| **7** | [02.TP-Debutant-DFS](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-02-tp-debutant-dfs) | 2 h | Les partages, DFS, la réplication, les homes |
| **8** | [03.TP-Debutant-GPO](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-03-tp-debutant-gpo) | 1 h | La GPO qui pousse le raccourci réseau |

> [!info] Trois niveaux pour la partie PowerShell AD
> - **Débutant** : commandes une par une sur un seul service — [01.TP-Debutant-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-debutant-ad)
> - **Intermédiaire** : import des CSV et boucles simples, sans fonction — [01.TP-Intermediaire-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-intermediaire-ad)
> - **Avancé** : script complet avec fonctions, contrôles et cache — [01.TP-Avance-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-avance-ad)

> [!tip] Le réflexe qui sauve : les points de contrôle Hyper-V
> À la fin de chaque note de la phase A, on vous fait créer un **snapshot**.
> Si vous cassez quelque chose, vous revenez à l'état précédent en 30 secondes au lieu de tout réinstaller.
> Ne sautez jamais ces commandes.

> [!info] Le lab est déjà monté par le formateur ?
> Sautez directement à [00.5-Poste-de-Travail](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-5-poste-de-travail). Mais lisez quand même [00.3-Promouvoir-DC01](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-3-promouvoir-dc01) en diagonale : la distinction **rôle / promotion** et la logique **DNS** y sont expliquées, et elles tombent en évaluation.

> Le **TP intermédiaire** utilise les CSV avec des boucles simples, sans fonction.
> Le **parcours Avancé** ([01.TP-Avance-AD](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-01-tp-avance-ad) et suivants) consiste ensuite à réécrire le déploiement sous forme de scripts structurés et réutilisables.

---

## 7 — Comment lire une note de TP

Chaque exercice est construit pareil :

```
Objectif       → ce que vous devez obtenir, en français
Consigne       → ce qu'il faut faire
Questions      → à quoi réfléchir pendant que vous le faites
Vérification   → la commande qui prouve que c'est bon + le résultat attendu
Besoin d'aide  → un bloc repliable avec la procédure détaillée
```

> [!tip] La règle des 10 minutes
> Bloqué plus de **10 minutes** sur un exercice ? Ouvrez le bloc **Besoin d'aide ?** et lisez le Manuel.
> Ce n'est pas tricher : le Manuel fait partie du TP. Ce qui compte, c'est que vous compreniez la commande, pas que vous la deviniez.

---

## 8 — Le vocabulaire minimum

Si un de ces mots ne vous dit rien, lisez la ligne avant de commencer :

| Mot | En une phrase |
|-----|---------------|
| **Domaine** | L'annuaire central : la liste des comptes et des machines de l'entreprise. Ici `ad.fournil.lab`. |
| **DC** (Domain Controller) | Le serveur qui héberge cet annuaire. Ici DC01. |
| **OU** (Unité d'Organisation) | Un dossier dans l'annuaire, pour ranger les comptes par service. |
| **Groupe G_** | Un groupe *Global* : il regroupe **des personnes** (les boulangers). |
| **Groupe DL_** | Un groupe *DomainLocal* : il porte **un droit** sur un dossier (lecture ou modification). |
| **AGDLP** | La règle qui relie les deux : Account → Global → DomainLocal → Permission. |
| **NTFS** | Les droits posés sur un dossier du disque (qui peut lire, écrire...). |
| **DFS** | Un système qui donne un seul chemin réseau unique, même si les données sont sur 2 serveurs. |
| **GPO** | Une règle appliquée automatiquement à tous les postes ou utilisateurs d'une OU. |
| **SYSVOL** | Un partage spécial du DC où l'on dépose les scripts distribués par les GPO. |

---

## 9 — Vous êtes prêt

> [!success] Étape suivante
> → **[00.1-Installer-les-VM](https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp/tp-00-1-installer-les-vm)** — on crée les deux machines virtuelles.

> Vue d'ensemble de toute la doc du projet : [Guide-déploiement-fournil](https://cours.kaya.ovh/active-directory/ad/09-tp-final/)
