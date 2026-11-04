---
title: "Le Fournil — Infrastructure Active Directory"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="html" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/html/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 28 32"><path d="M2 2h24l-2 25-10 3-10-3Z" fill="#e44d26"/><path d="M14 5v22l7-2 2-20Z" fill="#f16529"/><path d="M7 8h15l-.3 3H11l.3 3h10l-.8 9-6.5 2-6.5-2-.4-5h3l.2 2.6 3.7 1 3.7-1 .3-3.6H8Z" fill="#fff"/></svg>
</span><span class="resource-label">HTML</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/cours/09-tp-final.md">↓ Télécharger le cours (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>

<div class="note"><strong>Projet Fournil — parcours guidé</strong><p>Commencez par le TP HTML : 12 étapes, un choix de niveau et des points de contrôle.</p><p><a class="resource-button" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp">Ouvrir le projet guidé →</a></p></div>

> [!important] Le point de départ du projet
> Ouvrez le **[TP final guidé en HTML](https://cours.kaya.ovh/active-directory/ad/09-tp-final/html)**.
> Il rassemble la mission, les consignes, les aides et la recette finale dans un parcours unique de 12 étapes.

## La mission

Vous administrez Le Fournil, une boulangerie de 30 salariés répartis entre **Laboratoire** et **Vente**. Vous construisez le domaine, l’organisation AD, les droits sur les fichiers, les chemins DFS, la réplication, les dossiers personnels et une GPO de connexion.

L’utilisateur témoin est **Marc Lebrun**, `AD\mlebrun`, du service boulangerie. À la fin, il doit accéder à ses fichiers métier, à son lecteur H: et à son emplacement réseau personnel depuis un **poste client du domaine**.

## Un seul fil conducteur

| Étape | Résultat à obtenir |
|---|---|
| 00 — Mission | Choisir son niveau et identifier les preuves à remettre |
| 01 — Maquette | Hôte, DC01, DC02 et CLI01 sur le réseau du lab |
| 02 — Domaine | Deux contrôleurs du domaine ad.fournil.lab |
| 03 — Console et client | Administration opérationnelle, client joint, CSV disponibles |
| 04 — OUs | Des objets rangés dans une structure cohérente |
| 05 — AGDLP | Des groupes métier reliés aux groupes de permissions |
| 06 — Dossiers et comptes | Des droits NTFS et des utilisateurs actifs |
| 07 — SMB et DFS | Un chemin réseau stable avec deux cibles |
| 08 — Réplication | Une preuve de synchronisation dans les deux sens |
| 09 — Homes | Un dossier personnel protégé et le lecteur H: |
| 10 — GPO | Un emplacement réseau ajouté à la connexion |
| 11 — Recette | Des tests positifs et négatifs avec des preuves |

## Trois niveaux, un parcours

- **Débutant** : un service témoin, boulangerie, et Marc Lebrun. Les tests restent dans ce périmètre.
- **CSV** : toute l’organisation et les 30 salariés, avec variables et boucles simples.
- **Avancé** : même périmètre complet, avec vos propres scripts contrôlés et réutilisables.

Le guide adapte les consignes au niveau choisi. Il mémorise vos coches séparément pour chaque niveau dans le navigateur. Il n’exécute aucune commande et ne valide pas vos VM.

## Le plan du lab

| Machine | Adresse | Rôle |
|---|---|---|
| Hôte | 192.168.3.254/24 | Hyperviseur et passerelle NAT du réseau privé |
| DC01 | 192.168.3.10/24 | AD DS, DNS, namespace DFS et réplication de fichiers |
| DC02 | 192.168.3.2/24 | Second DC, DNS et réplication de fichiers |
| CLI01 | 192.168.3.20/24 | Poste client pour les tests de session de Marc |

Domaine : `ad.fournil.lab`. Nom NetBIOS : `AD`. Les clients utilisent les DNS AD ; le service DNS utilise un redirecteur pour les noms Internet.

Les tests de salarié se font sur **CLI01**, avec les chemins réseau. Les droits d’ouverture de session sur les contrôleurs de domaine n’ont pas à être élargis pour ce TP.

## Aides et fichiers

Les procédures historiques restent disponibles depuis les liens d’aide de chaque étape. Elles servent de référence ; le guide HTML définit l’ordre, le périmètre et les critères de réussite du parcours actuel.

Les CSV et scripts sont dans le ZIP de la formation, sous `assets/supports/scripts/`. Copiez les données nécessaires dans `C:\Deploy` sur DC01. Les scripts de déploiement complet sont des références d’automatisation : leur exécution ne remplace pas les exercices.

**[Commencer le projet guidé →](https://cours.kaya.ovh/active-directory/ad/09-tp-final/html)**
