---
title: "TP 01 — Infrastructure Active Directory"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/01-infrastructure-ad"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/01-infrastructure-ad.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>
<nav class="exercise-resources" aria-label="Ressources du TP"><a href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp" aria-current="page">Énoncé</a><a class="exercise-correction" href="https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp-corrigev2">Afficher les corrections</a></nav>

> Durée estimée : 1h30

> Chapitres associés : [01. Infrastructure Active Directory](https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/)

---

## Contexte — Fournil

La société **Fournil** est une boulangerie industrielle implantée à Bordeaux. Elle souhaite centraliser la gestion de ses comptes et de ses postes via Active Directory. Vous êtes mandaté pour installer et configurer le premier contrôleur de domaine.

| Paramètre | Valeur |
|-----------|--------|
| Nom de domaine | `ad.fournil.lab` |
| Nom NetBIOS | `FOURNIL` |
| Nom du serveur | `DC01` |
| Adresse IP du DC | `192.168.3.10/24` |
| Mot de passe DSRM | `P@ssw0rd!` |

---

## Objectifs

- Installer le rôle AD DS sur Windows Server 2025
- Promouvoir le serveur en contrôleur de domaine (nouvelle forêt)
- Vérifier l'installation via les outils graphiques et PowerShell
- Contrôler l'intégration DNS

---

## Prérequis lab

- Machine virtuelle Windows Server 2025 (VMware Workstation)
- IP fixe configurée (`192.168.3.10/24`)
- Serveur DNS préféré pointant sur lui-même (`192.168.3.10`)
- Nom d'hôte défini avant l'installation (`DC01`)

---

## Partie A — Préparation du serveur (15 min)

**A1.** Vérifie le nom de ta machine. Quel est-il ? Comment le modifier si nécessaire ? Renomme-la `DC01` si ce n'est pas déjà fait.

**A2.** Vérifie la configuration IP de ta carte réseau. Quelle commande PowerShell permet d'afficher les interfaces et leurs adresses ?

**A3.** Dans les propriétés TCP/IP de ta carte réseau, configure :
- IP fixe : `192.168.3.10`
- Masque : `255.255.255.0`
- DNS préféré : `192.168.3.10` (lui-même)

**A4.** Vérifie que le serveur se résout bien lui-même. Quelle commande PowerShell utilises-tu ?

---

## Partie B — Installation du rôle AD DS (20 min)

**B1.** Installe le rôle **Active Directory Domain Services** via le Gestionnaire de serveur. Quels outils de gestion sont ajoutés automatiquement ?

**B2.** Réalise la même installation via PowerShell. Quelle commande utilises-tu ?

**B3.** Une fois l'installation terminée, une notification apparaît dans le Gestionnaire de serveur. Qu'indique-t-elle ?

---

## Partie C — Promotion en contrôleur de domaine (30 min)

**C1.** Lance l'assistant de promotion. Quelle option choisis-tu pour créer un tout nouveau domaine ?

**C2.** Crée la forêt avec les paramètres suivants :
- Nom de domaine : `ad.fournil.lab`
- Niveau fonctionnel forêt et domaine : Windows Server 2025
- Options : DNS + Catalogue global cochés
- Mot de passe DSRM : `P@ssw0rd!`

**C3.** Pendant l'assistant, un avertissement apparaît concernant la délégation DNS. Est-ce bloquant ? Pourquoi ?

**C4.** Une fois le redémarrage effectué, avec quel compte te connectes-tu ? Quelle est la différence avec le compte local d'avant ?

---

## Partie D — Vérification (25 min)

**D1.** Ouvre **Utilisateurs et ordinateurs Active Directory** (`dsa.msc`). Quels conteneurs par défaut vois-tu ? À quoi servent `Computers` et `Users` ?

**D2.** Ouvre le **Gestionnaire DNS** (`dnsmgmt.msc`). Retrouve la zone `ad.fournil.lab`. Quels types d'enregistrements ont été créés automatiquement ?

**D3.** Exécute les commandes PowerShell suivantes et note les informations retournées :

```powershell
Get-ADDomain
Get-ADForest
```

**D4.** Lance un diagnostic complet du DC :

```powershell
dcdiag /test:dns /v
```

Combien de tests passent ? Y a-t-il des avertissements ou erreurs ?

**D5.** Vérifie que le service `NETLOGON` est bien démarré. Quelle commande PowerShell utilises-tu ?

---

## Partie E — Bonus

**E1.** Depuis une invite de commandes, exécute `nslookup ad.fournil.lab`. Que retourne-t-il ?

**E2.** Cherche dans l'Observateur d'événements (`eventvwr.msc`) le journal **Directory Service**. Trouve l'événement confirmant que les services AD DS ont démarré (ID **1000**). Quel autre événement indique que la base AD accepte les mises à jour ?

---

[Ouvrir la correction](https://cours.kaya.ovh/active-directory/ad/01-infrastructure-ad/tp-corrigev2)
