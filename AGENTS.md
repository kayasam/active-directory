# Modèle de formation de Samuel

Lire README.md et site.json avant adaptation. Les documents s’écrivent dans sources/ ou le coffre configuré, jamais dans content/. Conserver la forme du modèle ; adapter le contenu et l’identité plutôt que réinventer les composants.

- Titres identiques au Markdown ; aucun raccourcissement seulement dans l’explorateur.
- HTML pédagogique complémentaire rédigé manuellement, sans conversion automatique du cours complet.
- Corrigés v2 : énoncé et réponses repliées ; seuls les fichiers avec publier: true sont émis. Sources privées ignorées par Git.
- Un seul PDF de tous les cours sur l’accueil, près des ZIP ; aucun bouton PDF par chapitre.
- Annexe sobre, aucune multiplication de badges/cartes dans l’explorateur. Ne pas restaurer graphe, backlinks ou mémo supprimés.
- Vérifier construire.ps1, puis clair/sombre, mobile, navigation et téléchargements. Ne jamais publier sur le dépôt Linux depuis une copie.
- Les empreintes de template-manifest.json servent à détecter les divergences ; leur mise à jour suit une validation consciente.
