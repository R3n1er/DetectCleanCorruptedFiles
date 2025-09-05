# Architecture Decision Records (ADR)

## ADR-004: Refactorisation complète pour optimisation performance

**Date**: 2024-01-XX  
**Statut**: Accepté  
**Décideur**: Équipe développement  

### Contexte
Suite aux problèmes de blocage et de performance sur gros volumes (110k+ fichiers), une refactorisation complète était nécessaire pour optimiser la rapidité, fluidité et éviter les bugs de lenteur/mémoire.

### Décision
Refactorisation majeure avec optimisations critiques :

1. **Traitement par lots (BatchSize)**
   - Paramètre configurable (défaut: 1000 fichiers/lot)
   - Libération mémoire périodique avec `[GC]::Collect()`
   - Évite l'accumulation mémoire sur gros volumes

2. **Fonctions optimisées**
   - `Test-FileAttributes`: Test direct des bits d'attributs (1024=ReparsePoint, 512=SparseFile)
   - `Get-FilesRobust`: Énumération robocopy optimisée avec fallback
   - `Process-FileBatch`: Traitement par chunks avec gestion d'erreur

3. **Gestion mémoire améliorée**
   - Utilisation de `List[T]` au lieu d'arrays
   - Suppression des fonctions inutiles (Show-Current, Shorten-Path)
   - Configuration stricte avec `$ErrorActionPreference = 'Stop'`

4. **Simplification du code**
   - Suppression des affichages temps réel gourmands
   - Élimination des calculs ETA complexes
   - Progress bars simplifiées (tous les 100 fichiers)

5. **Export optimisé**
   - Export direct sans transformations multiples
   - Rapport de résumé minimal
   - Gestion d'erreur robuste

### Conséquences
- ✅ Performance drastiquement améliorée (traitement par lots)
- ✅ Consommation mémoire maîtrisée
- ✅ Plus de blocages sur gros volumes
- ✅ Code plus maintenable et lisible
- ✅ Suppression optimisée (pas de re-vérification)
- ❌ Moins de détails visuels pendant l'exécution (acceptable)

### Code modifié
- Refactorisation complète du script
- Nouvelles fonctions optimisées
- Traitement par lots avec libération mémoire
- Simplification des exports et rapports

---

## ADR-003: Suppression analyse par dossier pour gros volumes

**Date**: 2024-01-XX  
**Statut**: Intégré dans ADR-004  
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

---

## ADR-002: Correction du blocage après export

**Date**: 2024-01-XX  
**Statut**: Déprécié (remplacé par ADR-004)  
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

---

## ADR-001: Correction des exports de résultats

**Date**: 2024-01-XX  
**Statut**: Intégré dans ADR-004  
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