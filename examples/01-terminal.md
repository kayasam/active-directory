# 01. Le terminal et le shell

> [!NOTE] Objectif
> Comprendre le rôle du shell et lancer ses premières commandes.

## Le rôle du shell

Le terminal affiche une interface textuelle. Le shell interprète les commandes que tu saisis. Bash est un shell courant sous Linux.

## Lire une commande

Une commande contient un nom, des options et des arguments. Les espaces séparent les éléments ; les guillemets permettent de conserver un argument composé.

```bash
pwd
echo "Bonjour le terminal"
```

`pwd` affiche le répertoire courant. `echo` affiche le texte fourni.

## Codes de retour et aide

`$?` contient le code de retour de la dernière commande : 0 indique une réussite. `type` indique comment Bash interprète un nom de commande ; `help` documente ses commandes internes, `man` ouvre les pages de manuel.

```bash
type cd
help cd
echo "$?"
```

## À retenir

Teste une commande à la fois, observe sa sortie et lis son aide. Passe ensuite au [TP](01-terminal-tp.md).
