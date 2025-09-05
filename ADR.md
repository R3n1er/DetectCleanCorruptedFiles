# Architecture Decision Records (ADR)

## ADR-003: Suppression analyse par dossier pour gros volumes

**Date**: 2024-01-XX  
**Statut**: Accepté  
**Décideur**: Équipe développement  

### Contexte
Le script se bloquait systématiquement après l'export des résultats lors du traitement de gros volumes (110k+ fichiers). Le problème venait de la section "Analyse par dossier" qui consommait trop de mémoire en créant des structures de données complexes pour chaque fichier.

### Décision
Suppression complète de l'analyse par dossier :

1. **Suppression section analyse par dossier**
   - Élimination des variables `$folderStats` et `$folderStats2`
   - Suppression des boucles de traitement par dossier
   - Suppression de l'affichage des répartitions

2. **Simplification du rapport de résumé**
   - Rapport basique avec statistiques essentielles uniquement
   - Pas de détail par dossier pour éviter surcharge mémoire

### Conséquences
- ✅ Élimination du blocage sur gros volumes
- ✅ Performance drastiquement améliorée
- ✅ Continuité vers phase de suppression assurée
- ❌ Perte du détail par dossier (acceptable pour gros volumes)

### Code modifié
- Suppression complète section "Analyse par dossier racine"
- Simplification rapport de résumé
- Suppression affichages par dossier

---

## ADR-002: Correction du blocage après export

**Date**: 2024-01-XX  
**Statut**: Déprécié (remplacé par ADR-003)  
**Décideur**: Équipe développement  

### Contexte
Le script se bloquait après l'export des résultats (110748 lignes) lors de la génération du rapport de résumé, probablement dû à un problème de mémoire avec de gros volumes de données.

### Décision
Optimisation de la génération du rapport de résumé :

1. **Gestion mémoire améliorée**
   - Utilisation de `List[string]` au lieu d'array pour le contenu
   - Limitation à TOP 20 dossiers pour éviter surcharge
   - Limitation à 5 exemples par dossier

2. **Messages de progression**
   - Ajout de messages informatifs pendant la génération
   - Indication claire que le script continue après export

### Conséquences
- ❌ N'a pas résolu le problème de blocage
- ✅ Meilleure visibilité de la progression

### Code modifié
- Section génération rapport résumé : Optimisation mémoire et limitation affichage
- Messages de progression après export

---

## ADR-001: Correction des exports de résultats

**Date**: 2024-01-XX  
**Statut**: Accepté  
**Décideur**: Équipe développement  

### Contexte
Le script PowerShell `Detect-Clean-ImpactedFiles.ps1` présentait des problèmes d'export des résultats, notamment dans l'analyse de la sortie robocopy et la génération des fichiers CSV.

### Décision
Amélioration de la fonction `Get-LongPathFiles` et des exports :

1. **Analyse robocopy améliorée**
   - Traitement ligne par ligne plus robuste
   - Validation des chemins extraits
   - Filtrage des lignes invalides

2. **Export CSV optimisé**
   - Délimiteur `;` pour éviter conflits avec virgules dans chemins
   - Sélection explicite des colonnes
   - Gestion d'erreur avec try-catch

### Conséquences
- ✅ Exports de résultats fiables et exploitables
- ✅ Meilleure gestion des chemins longs Windows
- ✅ Rapports CSV correctement formatés
- ✅ Robustesse accrue face aux erreurs

### Code modifié
- `Get-LongPathFiles()` : Amélioration parsing robocopy
- Section exports : Ajout délimiteur CSV et gestion erreurs

---

## Template pour futures modifications

### ADR-XXX: [Titre de la modification]

**Date**: YYYY-MM-DD  
**Statut**: [Proposé/Accepté/Rejeté/Déprécié]  
**Décideur**: [Nom/Équipe]  

#### Contexte
[Description du problème ou besoin]

#### Décision
[Solution choisie et justification]

#### Alternatives considérées
[Autres options évaluées]

#### Conséquences
[Impact positif/négatif de la décision]

#### Code modifié
[Fonctions/sections modifiées]