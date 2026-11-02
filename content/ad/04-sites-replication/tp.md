---
title: "TP 04 — Sites AD et réplication"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/04-sites-replication"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/04-sites-replication/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/04-sites-replication/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/04-sites-replication.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 1h30

> Chapitres associés : [04. Sites AD et réplication](https://cours.kaya.ovh/active-directory/ad/04-sites-replication/)

---

## Contexte — Fournil

Fournil ouvre une seconde unité de production à **Nantes**. Le siège de **Rennes** héberge déjà `DC01`. La direction veut que les utilisateurs nantais s'authentifient localement, même si le lien WAN entre les deux sites est coupé.

Ta mission : installer un second contrôleur de domaine `DC02` à Nantes, déclarer la topologie physique dans AD et vérifier que la réplication fonctionne.

| Machine | Site | IP | Passerelle | Switch Hyper-V |
|---------|------|----|------------|----------------|
| `DC01` | Rennes | `192.168.3.10/24` | `192.168.3.254` | Internal1 (vSwitch-Rennes) |
| `DC02` | Nantes | `192.168.4.10/24` | `192.168.4.254` | Internal2 (vSwitch-Nantes) |
| Hôte Hyper-V | — | `192.168.3.254` / `192.168.4.254` | — | les deux |

---

## Objectifs

- Relier deux réseaux isolés en faisant de l'hôte un routeur
- Promouvoir un DC **additionnel** dans un domaine existant
- Créer les sites, les subnets et configurer le site link
- Vérifier, forcer et diagnostiquer la réplication

---

## Prérequis lab

- `DC01` opérationnel (TP 01), avec les OUs, utilisateurs et groupes des TP 02 et 03
- Une VM Windows Server 2025 vierge pour `DC02`, connectée au second switch interne
- PowerShell administrateur sur l'**hôte** Hyper-V

---

## Partie A — Interconnecter les deux sites (20 min)

**A1.** Sur l'hôte, liste les adaptateurs `vEthernet`. Note les noms exacts des deux interfaces internes et vérifie qu'elles portent bien `192.168.3.254` et `192.168.4.254`.

**A2.** Active le routage IP entre ces deux interfaces. Quelle commande utilises-tu ?

**A3.** Configure l'IP fixe de `DC02` (voir tableau). Vers quel serveur DNS doit pointer **DNS préféré** **avant** la promotion ? Pourquoi ?

**A4.** Depuis `DC02`, vérifie :
- que `DC01` répond au ping ;
- que le nom `ad.fournil.lab` se résout ;
- que l'enregistrement SRV `_ldap._tcp.ad.fournil.lab` est trouvé.

Quelles commandes utilises-tu ? Si un test échoue, ne passe pas à la suite.

---

## Partie B — Promouvoir DC02 (25 min)

**B1.** Renomme la machine `DC02` et redémarre.

**B2.** Installe le rôle AD DS via PowerShell.

**B3.** Promeus `DC02` en **contrôleur de domaine additionnel** de `ad.fournil.lab`, avec DNS et catalogue global, mot de passe DSRM `P@ssw0rd!`. Donne la commande PowerShell. Quelle option de l'assistant graphique correspond ?

**B4.** Après redémarrage, quel compte utilises-tu pour te connecter sur `DC02` ? Pourquoi n'y a-t-il plus de compte local ?

**B5.** Modifie la configuration DNS de `DC02` après la promotion : quelles adresses mets-tu en DNS préféré / auxiliaire ?

**B6.** Vérifie que les deux DC sont bien listés dans le domaine. Dans quel site apparaît `DC02` ? Pourquoi ?

---

## Partie C — Sites, subnets et site link (25 min)

**C1.** Ouvre `dssite.msc`. Quel est le nom du site existant ? Quels serveurs contient-il ?

**C2.** Renomme ce site en `Rennes` et crée un site `Nantes`. Réalise une opération en GUI, l'autre en PowerShell.

**C3.** Crée les subnets `192.168.3.0/24` (Rennes) et `192.168.4.0/24` (Nantes) via PowerShell.

**C4.** Déplace `DC02` dans le site `Nantes`.

**C5.** Le site link `DEFAULTIPSITELINK` relie-t-il bien les deux sites ? Ajoute `Nantes` si besoin et passe la fréquence de réplication à **15 minutes**. Pourquoi ne garderait-on pas 15 min en production ?

**C6.** Dans `dssite.msc`, ouvre `Nantes → Servers → DC02 → NTDS Settings`. Qu'y trouves-tu ? Qui a créé ces objets ?

---

## Partie D — Vérifier la réplication (15 min)

**D1.** Sur `DC01`, crée un utilisateur `test.repli` dans `OU=Utilisateurs`. Vérifie immédiatement s'il existe sur `DC02` :

```powershell
Get-ADUser test.repli -Server DC02
```

**D2.** S'il n'est pas encore présent, force la réplication. Quelle commande utilises-tu ?

**D3.** Affiche l'état de la réplication des deux DC. Combien d'échecs ? Quelle est la date de la dernière réplication réussie ?

**D4.** Lance `dcdiag /test:replications` sur `DC02`. Résultat ?

---

## Partie E — Bonus : panne du lien WAN

**E1.** Sur l'hôte, désactive le routage sur l'interface de Nantes. Crée un utilisateur `test.panne` sur `DC01`. Que montre `repadmin /replsummary` ? Un utilisateur nantais peut-il toujours ouvrir une session ? Pourquoi ?

**E2.** Réactive le routage. Que se passe-t-il pour `test.panne` ? Faut-il intervenir manuellement ?

---


