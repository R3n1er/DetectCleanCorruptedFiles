# Detect-Clean-ImpactedFiles.ps1

## Description

Script PowerShell optimisé pour détecter et supprimer les fichiers réellement corrompus sur un système de fichiers Windows. Il identifie les fichiers avec des attributs problématiques (ReparsePoint, SparseFile) et valide leur corruption réelle pour éviter les faux positifs.

## Fonctionnalités

### Détection intelligente

- **Validation de corruption** : Teste la lisibilité réelle des fichiers
- **ReparsePoint** : Détecte les liens symboliques/jonctions corrompus
- **SparseFile** : Identifie les fichiers optimisés défaillants
- **Fichiers vides** : Fichiers de taille 0 (optionnel)
- **Traitement par lots** : Gestion mémoire optimisée pour gros volumes
- **Chemins longs** : Support natif des chemins > 260 caractères
- **Énumération robuste** : Robocopy avec fallback Get-ChildItem
- **Rapports détaillés** : Exports TXT, CSV avec raison de corruption

## Utilisation

### Mode Analyse (Recommandé)

```powershell
# Analyse avec validation de corruption (par défaut)
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\"

# Analyse tous attributs suspects (ancien comportement)
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -ForceDetection

# Analyse avec fichiers vides inclus
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -IncludeZeroLength

# Analyse avec traitement par lots personnalisé
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -BatchSize 2000

# Analyse avec dossier de sortie personnalisé
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -OutputDir "C:\Temp\Reports"
```

### Mode Suppression (Attention !)

```powershell
# Suppression des fichiers réellement corrompus (recommandé)
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -Delete

# Suppression tous attributs suspects
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -Delete -ForceDetection

# Suppression avec fichiers vides inclus
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -Delete -IncludeZeroLength
```

## Paramètres

| Paramètre            | Description                           | Défaut    |
| -------------------- | ------------------------------------- | --------- |
| `-Root`              | Racine à analyser                     | `E:\`     |
| `-IncludeZeroLength` | Inclure les fichiers de taille 0      | Désactivé |
| `-Delete`            | Supprimer les fichiers impactés       | Désactivé |
| `-OutputDir`         | Dossier pour rapports et logs         | `C:\Temp` |
| `-BatchSize`         | Taille des lots pour traitement       | `1000`    |
| `-ForceDetection`    | Forcer détection sans validation      | Désactivé |

## Sécurités intégrées

- **Protection C:\** : Refuse d'analyser le lecteur système par sécurité
- **Validation de corruption** : Teste la lisibilité réelle des fichiers
- **Évite les faux positifs** : Distingue attributs normaux vs corruption
- **Vérification espace disque** : Alerte si < 100MB pour les rapports
- **Gestion d'erreurs robuste** : Continue même en cas d'erreurs d'accès
- **Traitement par lots** : Évite les blocages mémoire sur gros volumes

## Rapports générés

Le script génère automatiquement :

- **Liste TXT** : `impacted_files_YYYYMMDD_HHMMSS.txt`
- **Export CSV** : `impacted_files_YYYYMMDD_HHMMSS.csv` (avec colonne Reason)
- **Résumé** : `summary_YYYYMMDD_HHMMSS.txt`
- **Log complet** : `impacted_files_YYYYMMDD_HHMMSS.log`

## Conseils d'utilisation

### Avant la première utilisation

1. **Toujours commencer par une analyse** sans `-Delete`
2. **Examiner les rapports** générés pour comprendre l'impact
3. **Tester avec `-WhatIf`** avant suppression réelle
4. **Sauvegarder** les données importantes

### Workflow recommandé

```powershell
# 1. Analyse avec validation (recommandé)
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\"

# 2. Examiner les rapports dans C:\Temp
# - Vérifier la colonne "Reason" dans le CSV
# - Contrôler que les fichiers sont vraiment corrompus

# 3. Si peu de résultats, essayer mode force
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -ForceDetection

# 4. Suppression des fichiers validés comme corrompus
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\" -Delete
```

### Performances

- **Traitement par lots** : 1000 fichiers/lot (configurable avec -BatchSize)
- **Gestion mémoire** : Libération périodique pour éviter les blocages
- **Gros volumes** : Optimisé pour 500k+ fichiers sans problème
- **Chemins longs** : Gestion automatique des chemins > 260 caractères
- **Énumération robuste** : Robocopy avec fallback Get-ChildItem

### Cas d'usage typiques

- **Nettoyage après corruption** : Suppression des fichiers réellement corrompus
- **Maintenance préventive** : Détection régulière avec validation
- **Migration de données** : Nettoyage avant transfert (mode ForceDetection)
- **Audit de santé** : Vérification périodique de l'intégrité
- **Gros volumes** : Traitement optimisé de serveurs de fichiers

### Exemples d'utilisation

```powershell
# Serveur de fichiers - analyse sécurisée
.\Detect-Clean-ImpactedFiles.ps1 -Root "D:\Shares" -BatchSize 2000

# Migration - détection large
.\Detect-Clean-ImpactedFiles.ps1 -Root "E:\OldData" -ForceDetection -IncludeZeroLength

# Nettoyage validé
.\Detect-Clean-ImpactedFiles.ps1 -Root "F:\Temp" -Delete

# Audit complet avec gros lots
.\Detect-Clean-ImpactedFiles.ps1 -Root "G:\Archive" -BatchSize 5000 -OutputDir "C:\Reports"
```

## Modes de détection

### Mode par défaut (Validation activée)
- **Recommandé** : Détecte uniquement les fichiers réellement corrompus
- **Sécurisé** : Évite la suppression de fichiers normaux avec attributs spéciaux
- **Test de lecture** : Valide l'accessibilité avant marquage comme corrompu

### Mode ForceDetection
- **Ancien comportement** : Tous les fichiers avec attributs suspects
- **Plus large** : Inclut liens symboliques, fichiers optimisés normaux
- **Attention** : Risque de faux positifs

## Avertissements

⚠️ **ATTENTION** : Le mode `-Delete` supprime définitivement les fichiers détectés  
⚠️ **Sauvegarde** : Toujours sauvegarder avant utilisation du mode suppression  
⚠️ **Validation** : Examiner les rapports avant suppression  
⚠️ **Test manuel** : Vérifier quelques fichiers détectés manuellement
