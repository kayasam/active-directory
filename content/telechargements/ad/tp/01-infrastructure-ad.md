# TP 01 — Infrastructure Active Directory

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


