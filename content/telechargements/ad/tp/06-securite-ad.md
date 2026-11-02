# TP 06 — Sécurité Active Directory

> Durée estimée : 1h15

> Chapitres associés : [06. Sécurité Active Directory](https://cours.kaya.ovh/active-directory/ad/06-securite-ad/)

---

## Objectifs

- Configurer la stratégie de mot de passe du domaine
- Tester le verrouillage de compte et le déverrouiller
- Activer et lire les journaux d'audit
- Identifier les membres des groupes privilégiés

---

## Partie A — Stratégie de mot de passe (20 min)

**A1.** Affiche la stratégie de mot de passe actuelle du domaine :
```powershell
Get-ADDefaultDomainPasswordPolicy
```
Quelles sont les valeurs par défaut pour la longueur minimale et la complexité ?

**A2.** Via la **Default Domain Policy** (`gpmc.msc`), configure la stratégie suivante :

| Paramètre | Valeur |
|-----------|--------|
| Longueur minimale | 10 caractères |
| Complexité | Activée |
| Durée de vie maximale | 60 jours |
| Historique | 5 mots de passe |
| Seuil de verrouillage | 3 tentatives |
| Durée de verrouillage | 15 minutes |

**A3.** Force l'application de la GPO et vérifie que la stratégie est bien prise en compte :
```powershell
gpupdate /force
Get-ADDefaultDomainPasswordPolicy
```

**A4.** Tente de créer un utilisateur avec un mot de passe ne respectant pas la complexité (`Password`). Que se passe-t-il ?

---

## Partie B — Verrouillage de compte (20 min)

**B1.** Depuis une session sur le poste client (ou via `runas`), tente de te connecter avec le compte `jrenard` en entrant un mauvais mot de passe **4 fois de suite**. Que se passe-t-il à la 4ème tentative ?

**B2.** Depuis le DC, vérifie si le compte est verrouillé :
```powershell
Get-ADUser -Identity "jrenard" -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
  Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
```

**B3.** Déverrouille le compte `jrenard` via PowerShell.

**B4.** Trouve la commande pour lister **tous** les comptes verrouillés du domaine.

---

## Partie C — Audit et journaux (20 min)

**C1.** Ouvre l'**Observateur d'événements** (`eventvwr.msc`) → Journaux Windows → **Sécurité**. Filtre sur l'ID d'événement **4625** (échec de connexion). Retrouve les tentatives échouées de la partie B.

**C2.** Retrouve l'événement **4740** (verrouillage de compte). Quel compte a été verrouillé et depuis quelle machine ?

**C3.** Via PowerShell, affiche les 5 derniers événements de type **4624** (connexion réussie) :
```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 5 |
  Select-Object TimeCreated, Message
```

**C4.** Crée un nouvel utilisateur `test_audit`. Dans les journaux de sécurité, retrouve l'événement correspondant à cette création (ID **4720**). Qui a créé le compte ?

---

## Partie D — Moindre privilège (15 min)

**D1.** Liste les membres actuels du groupe `Domain Admins` :
```powershell
Get-ADGroupMember -Identity "Domain Admins" | Select-Object Name, SamAccountName
```
Y a-t-il des comptes qui ne devraient pas être là ?

**D2.** Crée un compte d'administration dédié pour l'admin système de Fournil :
- Nom : `adm.sysinfo`
- OU : `OU=Support,OU=Utilisateurs`
- Mot de passe : `Adm!Fournil@2025`
- Ne peut pas changer son mot de passe : Non
- Mot de passe n'expire jamais : Non

**D3.** Ajoute `adm.sysinfo` au groupe `Account Operators` (gestion des comptes sans être Domain Admin). Quels droits cela lui confère-t-il ?

**D4.** Crée un compte de service `svc_backup` dans une nouvelle `OU=Services` avec les options appropriées (cf. cours).

---

## Partie E — Bonus

**E1.** Via PowerShell, affiche tous les comptes dont le mot de passe **n'expire jamais** :
```powershell
Get-ADUser -Filter {PasswordNeverExpires -eq $true} -Properties PasswordNeverExpires |
  Select-Object Name, SamAccountName
```
Est-ce normal pour tous ces comptes ?

**E2.** Affiche tous les comptes **désactivés** du domaine :
```powershell
Search-ADAccount -AccountDisabled | Select-Object Name, SamAccountName
```

---


