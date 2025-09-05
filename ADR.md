# Architecture Decision Records (ADR)

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