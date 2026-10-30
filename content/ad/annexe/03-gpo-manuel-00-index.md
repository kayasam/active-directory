---
title: "Procédure GPO — Emplacement réseau Home"
---

> Cette procédure déploie une GPO qui crée automatiquement un raccourci **"Mon Dossier Personnel"** dans l'Explorateur Windows de chaque utilisateur, pointant vers son dossier personnel `\\ad.fournil.lab\HOMES\<Entite>\<Login>`.

**Domaine** : `ad.fournil.lab` | **Serveur** : DC01

**Serveurs concernés :**

| Rôle | Nom | Description |
|------|------|-------------|
| Principal | DC01 | Crée la GPO et le script |
| Secondaire | DC02 | Reçoit le script via réplication SYSVOL |

---

## Phases

| # | Note | Ce qu'on fait |
|---|------|---------------|
| 1 | [GPO-01-Script-Connexion](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-01-script-connexion) | Créer le script `Set-NetworkLocation.ps1` (lecture HomeDirectory AD, raccourci réseau, Desktop.ini, idempotence) |
| 2 | [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo) | Créer la GPO `GPO_Emplacement_Home` et la lier à `OU=fournil` |
| 3 | [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol) | Copier le script dans le SYSVOL de la GPO (répliqué vers DC02) |
| 4 | [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script) | Créer `psscripts.ini` pour que Windows exécute le script à la connexion |
| 5 | [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage) | Tester le raccourci + résoudre les problèmes courants |

---

## Résumé des commandes

| Commande | Ce qu'elle fait | Phase |
|----------|-----------------|-------|
| `New-GPO -Name "GPO_Emplacement_Home"` | Crée la GPO | [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo) |
| `New-GPLink -Name ... -Target ... -LinkEnabled Yes` | Lie la GPO à l'OU | [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo) |
| `Copy-Item ... -Destination $sysvolPath` | Copie le script dans SYSVOL | [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol) |
| `Set-Content -Path psscripts.ini -Encoding Unicode` | Enregistre le script de connexion | [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script) |
| `gpupdate /force` + déconnexion/reconnexion | Teste la GPO | [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage) |

---

## Ce que l'utilisateur voit après

```
Explorateur Windows
├── Ce PC
├── Réseau
│   └── Mon Dossier Personnel    ← raccourci vers \\ad.fournil.lab\HOMES\<entite>\<login>
└── Lecteur H:                   ← mappé automatiquement (HomeDirectory AD)
```

> **Astuce** : pour tout faire automatiquement, lancez `.\03-GPO-Home.ps1`.
