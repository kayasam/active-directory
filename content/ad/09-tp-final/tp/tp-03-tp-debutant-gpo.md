---
title: "TP Débutant — GPO Emplacement réseau"
---

<nav class="chapter-resources" aria-label="Ressources du chapitre" data-course-key="ad/09-tp-final"><div class="resource-buttons"><a class="resource-button" data-resource-kind="markdown" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 24"><rect x="1" y="1" width="30" height="22" rx="3" fill="none" stroke="#34495e" stroke-width="2"/><path d="M5 18V6h3l4 5 4-5h3v12h-3v-7l-4 5-4-5v7Z" fill="#34495e"/><path d="M23 6h3v7h3l-4.5 5-4.5-5h3Z" fill="#34495e"/></svg>
</span><span class="resource-label">Cours</span></a><a class="resource-button" data-resource-kind="tp" href="https://cours.kaya.ovh/active-directory/ad/09-tp-final/tp"><span class="resource-icon"><svg class="resource-symbol" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="2" y="4" width="28" height="24" rx="5" fill="#237b60"/><path d="m8 12 5 4-5 4m9 0h7" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
</span><span class="resource-label">TP</span></a></div><div class="resource-actions"><a class="resource-download" download href="https://cours.kaya.ovh/active-directory/telechargements/ad/tp/09-tp-final-tp-03-tp-debutant-gpo.md">↓ Télécharger le TP (.md)</a><button type="button" class="support-focus-toggle" aria-pressed="false">Masquer les menus</button></div></nav>


> Durée estimée : 1h
> Prérequis : TP AD et TP DFS terminés (homes configurés)
> Niveau : Débutant

---

## Contexte

Les utilisateurs du Fournil ont maintenant un dossier personnel accessible via `\\ad.fournil.lab\HOMES\<Entite>\<Login>` et un lecteur `H:`. Vous allez créer une GPO qui ajoute automatiquement un raccourci "Mon Dossier Personnel" dans l'Explorateur de chaque utilisateur.

---

## Exercice 1 — Comprendre le script de connexion

### Consigne

Lisez le script `Set-NetworkLocation.ps1` et répondez aux questions.

### Questions

1. Quelle commande récupère le chemin du home depuis l'AD ?
2. Que représente `0x13` dans `Namespace(0x13)` ?
3. Qu'est-ce qu'un fichier `Desktop.ini` et à quoi sert le CLSID dedans ?
4. Pourquoi le script vérifie `Test-Path "target.lnk"` avant de créer le raccourci ?
5. Pourquoi `Desktop.ini` doit-il avoir les attributs System + Hidden ?

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [GPO-01-Script-Connexion](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-01-script-connexion)

---

## Exercice 2 — Créer la GPO

### Consigne

1. Créez une GPO nommée `GPO_Emplacement_Home`
2. Liez-la à l'OU `OU=fournil,DC=ad,DC=fournil,DC=lab`
3. Vérifiez que le lien est actif

### Questions

- Quelle est la différence entre **créer** une GPO et la **lier** ?
- La GPO s'applique-t-elle aux utilisateurs de `OU=Utilisateurs,OU=fournil,...` ? Pourquoi ?
- Que fait `-LinkEnabled Yes` ?

### Vérification

```powershell
Get-GPO -Name "GPO_Emplacement_Home" | Select-Object DisplayName, Id
Get-GPInheritance -Target "OU=fournil,DC=ad,DC=fournil,DC=lab" | Select-Object -ExpandProperty GpoLinks
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [GPO-02-Creer-Lier-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-02-creer-lier-gpo)

---

## Exercice 3 — Déployer dans SYSVOL

### Consigne

1. Trouvez le GUID de la GPO que vous avez créée
2. Construisez le chemin SYSVOL correspondant
3. Copiez le script `Set-NetworkLocation.ps1` dans le bon dossier
4. Créez le fichier `psscripts.ini` pour enregistrer le script

### Questions

- Qu'est-ce que SYSVOL ? Pourquoi y mettre le script ?
- Que signifie le format `ToString("B")` pour un GUID ?
- Pourquoi `psscripts.ini` doit-il être en Unicode ?
- Que signifie `0CmdLine=` dans le fichier INI ?

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [GPO-03-Deploiement-SYSVOL](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-03-deploiement-sysvol) et [GPO-04-Enregistrer-Script](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-04-enregistrer-script)

---

## Exercice 4 — Tester

### Consigne

1. Sur un poste client, forcez la mise à jour des GPO
2. Déconnectez-vous et reconnectez-vous avec `mlebrun`
3. Vérifiez que "Mon Dossier Personnel" apparait dans l'Explorateur
4. Vérifiez en ligne de commande que `target.lnk` existe

### Questions

- Pourquoi `gpupdate /force` ne suffit-il pas pour voir le raccourci ?
- Où se trouve physiquement le raccourci sur le disque du poste client ?

### Si ça ne marche pas

```powershell
# La GPO s'applique-t-elle ?
gpresult /r /scope:user

# Le HomeDirectory est-il configuré ?
Get-ADUser -Identity "mlebrun" -Properties HomeDirectory | Select-Object HomeDirectory

# Le script est-il sur les 2 DC ?
Test-Path "\\DC01\SYSVOL\ad.fournil.lab\Policies\*\User\Scripts\Logon\Set-NetworkLocation.ps1"
```

> [!tip]- Besoin d'aide ? Cliquez ici
> Consultez : [GPO-05-Verification-Depannage](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-manuel-gpo-05-verification-depannage)

---

## Bonus — Automatisation

> Le script `03-GPO-Home.ps1` fait tout ça + gère les extensions CSE pour que la GPMC affiche le script. Comparez avec ce que vous avez fait manuellement.

> Pour l'explication détaillée : [Explication-Script-GPO](https://cours.kaya.ovh/active-directory/ad/annexe/03-gpo-script-explication-script-gpo)
