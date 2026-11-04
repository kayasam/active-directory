# Le Fournil — Infrastructure Active Directory

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
