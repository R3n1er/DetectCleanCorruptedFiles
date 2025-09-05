<# 
.SYNOPSIS
  Recense (et optionnellement supprime) les fichiers impactes (ReparsePoint/SparseFile et/ou longueur=0),
  avec progression, ETA et affichage du fichier courant (scan + suppression).

.PARAMETERS
  -Root 'E:\'                 Racine a analyser (defaut E:\)
  -IncludeZeroLength          Inclure les fichiers de taille 0 comme impactes
  -Delete                     Supprimer les fichiers impactes trouves (desactive par defaut)
  -OutputDir 'C:\Temp'        Dossier pour rapports et logs (defaut C:\Temp)
  -WhatIf                     Simuler la suppression (utile avec -Delete)
#>

param(
  [string]$Root = 'E:\',
  [switch]$IncludeZeroLength,
  [switch]$Delete,
  [string]$OutputDir = 'C:\Temp'
)

# ---------- Securite & preparation ----------
if (-not (Test-Path $Root)) { Write-Error "Chemin introuvable: $Root"; exit 1 }
$normalizedRoot = (Resolve-Path $Root).Path
if ($normalizedRoot -match '^[cC]:\\?$') { Write-Error "Par securite, ne pas executer sur C:\."; exit 1 }

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$stamp   = (Get-Date).ToString('yyyyMMdd_HHmmss')
$txtPath = Join-Path $OutputDir "impacted_files_${stamp}.txt"
$csvPath = Join-Path $OutputDir "impacted_files_${stamp}.csv"
$logPath = Join-Path $OutputDir "impacted_files_${stamp}.log"

Start-Transcript -Path $logPath -Append | Out-Null

Write-Host "Analyse de: $normalizedRoot"
Write-Host "Rapports: $txtPath ; $csvPath"
if ($Delete) { Write-Warning "MODE SUPPRESSION ACTIVE" } else { Write-Host "Mode detection (aucune suppression)" }

# Verification espace disque pour les rapports
$drive = (Get-PSDrive -Name ($OutputDir.Substring(0,1))).Free
if ($drive -lt 100MB) { Write-Warning "Espace disque faible sur $($OutputDir.Substring(0,1)): pour rapports" }

# ---------- Utilitaires ----------
function Test-Attr {
  param($Attrs, [System.IO.FileAttributes]$Flag)
  try {
    # Convertir en entier pour eviter les problemes d'enumeration
    $attrsValue = [int]$Attrs
    $flagValue = [int]$Flag
    return (($attrsValue -band $flagValue) -ne 0)
  }
  catch {
    # Fallback: tester par nom d'attribut
    $attrsString = $Attrs.ToString()
    $flagString = $Flag.ToString()
    return ($attrsString -like "*$flagString*")
  }
}
function Shorten-Path {
  param([string]$Path, [int]$Max = 100)
  if ([string]::IsNullOrEmpty($Path)) { return $Path }
  if ($Path.Length -le $Max) { return $Path }
  # Coupe en gardant debut et fin
  $keep = [Math]::Floor(($Max - 3) / 2)
  return ($Path.Substring(0,$keep) + '...' + $Path.Substring($Path.Length-$keep))
}
# Ecrit le fichier courant sur une seule ligne (mise a jour dynamique)
function Show-Current {
  param([string]$prefix, [string]$path)
  $msg = "${prefix}: $(Shorten-Path $path 110)"
  Write-Host "`r$msg" -NoNewline
}

# ---------- Fonction pour chemins longs ----------
function Get-LongPathFiles {
  param([string]$RootPath)
  
  $longPaths = New-Object System.Collections.Generic.List[string]
  $errors = 0
  
  try {
    # Robocopy avec /L (list only) pour enumerer sans copier
    $robocopyOutput = & robocopy $RootPath "C:\NonExistent" /L /S /NJH /NJS /FP /NC /NDL /TS 2>$null
    
    foreach ($line in $robocopyOutput) {
      # Filtrer les lignes contenant des fichiers (commencent par des espaces + taille)
      if ($line -match '^\s+\d+\s+') {
        # Extraire le chemin du fichier (après la date/heure)
        if ($line -match '^\s+\d+.*?\d{2}:\d{2}:\d{2}\s+(.+)$') {
          $filePath = $matches[1].Trim()
          # Vérifier que c'est un chemin valide
          if ($filePath -and $filePath.Length -gt 0 -and -not $filePath.StartsWith('*')) {
            $longPaths.Add($filePath)
          }
        }
      }
    }
  }
  catch { 
    $errors++
    Write-Warning "Erreur robocopy: $($_.Exception.Message)"
  }
  
  Write-Host "Robocopy enumeration: $($longPaths.Count) fichiers trouves"
  return $longPaths.ToArray()
}

# ---------- PHASE 1 : Enumeration + Scan ----------
Write-Host "`n[1/2] Enumeration des fichiers..."
$enumSw = [System.Diagnostics.Stopwatch]::StartNew()

# Methode robuste pour chemins longs
$allFilePaths = Get-LongPathFiles -RootPath $normalizedRoot

# Fallback si robocopy echoue
if ($allFilePaths.Count -eq 0) {
  Write-Warning "Fallback vers Get-ChildItem..."
  $allFilePaths = (Get-ChildItem -Path $normalizedRoot -Recurse -File -Force -ErrorAction SilentlyContinue).FullName
}

$enumSw.Stop()
$tot = $allFilePaths.Count
Write-Host ("Fichiers a analyser : {0} (enumeration: {1:n1}s)" -f $tot, ($enumSw.Elapsed.TotalSeconds))
if ($tot -eq 0) { Write-Host "Aucun fichier trouve. Arret."; Stop-Transcript | Out-Null; exit 0 }

$results = New-Object System.Collections.Generic.List[Object]
$scanSw  = [System.Diagnostics.Stopwatch]::StartNew()
$errors  = 0
$checked = 0
$lastPct = -1

for ($i = 0; $i -lt $tot; $i++) {
  $filePath = $allFilePaths[$i]
  # Affiche le fichier courant (scan)
  Show-Current -prefix "Scan" -path $filePath

  try {
    # Gestion des chemins longs avec prefixe UNC
    $longPath = if ($filePath.Length -gt 260 -and -not $filePath.StartsWith('\\?\')) {
      "\\?\$filePath"
    } else { $filePath }
    
    $item = Get-Item -LiteralPath $longPath -Force -ErrorAction Stop
    
    # Gestion securisee des attributs pour eviter les erreurs d'enumeration
    try {
      $isReparse = Test-Attr -Attrs $item.Attributes -Flag ([System.IO.FileAttributes]::ReparsePoint)
      $isSparse  = Test-Attr -Attrs $item.Attributes -Flag ([System.IO.FileAttributes]::SparseFile)
    }
    catch {
      # Fallback: tester par chaine de caracteres
      $attrString = $item.Attributes.ToString()
      $isReparse = $attrString -like "*ReparsePoint*"
      $isSparse = $attrString -like "*SparseFile*"
    }
    
    $isZero = ($item.Length -eq 0)

    $impacted = $false
    if ($isReparse -or $isSparse) { $impacted = $true }
    if ($IncludeZeroLength -and $isZero) { $impacted = $true }

    if ($impacted) {
      $results.Add([PSCustomObject]@{
        FullName   = $item.FullName
        Length     = $item.Length
        Attributes = $item.Attributes.ToString()
        IsReparse  = $isReparse
        IsSparse   = $isSparse
        IsZeroLen  = $isZero
        LastWrite  = $item.LastWriteTime
      }) | Out-Null
    }
  }
  catch {
    $errors++
    # Detecter le type d'erreur pour diagnostic
    $errorType = "Autre"
    if ($_.Exception.Message -like "*n'existe pas*" -or $_.Exception.Message -like "*cannot find*") {
      $errorType = "Fichier fantome (corruption encodage)"
    }
    elseif ($_.Exception.Message -like "*access*denied*" -or $_.Exception.Message -like "*acces*refuse*") {
      $errorType = "Acces refuse"
    }
    
    # Affichage condense pour eviter le spam
    if ($errors % 50 -eq 1) {
      Write-Warning "`n[Erreur $errorType] Exemple: $(Split-Path $filePath -Leaf)"
    }
  }

  $checked++
  $pct = [int](($checked / $tot) * 100)
  # Mise a jour moins frequente pour de meilleures performances
  if ($pct -ne $lastPct -and ($checked % 100 -eq 0 -or $pct -ne $lastPct)) {
    $elapsed = $scanSw.Elapsed
    $eta     = if ($checked -gt 0) {
      $avg = $elapsed.TotalSeconds / $checked
      [TimeSpan]::FromSeconds($avg * ($tot - $checked))
    } else { [TimeSpan]::Zero }
    $rate = if ($elapsed.TotalSeconds -gt 0) { [int]($checked / $elapsed.TotalSeconds) } else { 0 }
    Write-Progress -Activity "Scan des fichiers" `
                   -Status ("{0}/{1} - {2}% | {3} f/s | Ecoule {4:mm\:ss} | ETA {5:mm\:ss}" -f $checked,$tot,$pct,$rate,$elapsed,$eta) `
                   -CurrentOperation (Shorten-Path $filePath 100) `
                   -PercentComplete $pct
    $lastPct = $pct
  }
}
$scanSw.Stop()
Write-Progress -Activity "Scan des fichiers" -Completed
Write-Host "`n"  # termine la ligne du Show-Current

Write-Host "Preparation des exports..."

# Exports avec gestion memoire optimisee
if ($results.Count -gt 0) {
  Write-Host "Export des resultats..."
  try {
    # Export TXT - liste des chemins
    $results | Select-Object -ExpandProperty FullName | Set-Content -Path $txtPath -Encoding UTF8
    
    # Export CSV avec toutes les colonnes
    $results | Select-Object FullName, Length, Attributes, IsReparse, IsSparse, IsZeroLen, LastWrite | 
               Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    
    Write-Host "Exports reussis: TXT ($($results.Count) lignes) et CSV"
    Write-Host "Preparation du rapport de resume..."
  }
  catch {
    Write-Error "Erreur lors de l'export: $($_.Exception.Message)"
  }
  
  # Export rapport de resume simplifie
  $summaryPath = Join-Path $OutputDir "summary_${stamp}.txt"
  Write-Host "Generation du rapport de resume..."
  
  $filesHealthy = $tot - $results.Count - $errors
  
  $summaryContent = @(
    "FICHIERS CORROMPUS DETECTES - $(Get-Date)",
    "Racine: $normalizedRoot",
    "",
    "=== STATISTIQUES ===",
    "Total fichiers traites: $tot",
    "Fichiers sains: $filesHealthy",
    "Fichiers corrompus: $($results.Count)",
    "Erreurs de lecture: $errors"
  )
  
  if ($Delete) {
    $summaryContent += ""
    $summaryContent += "ATTENTION: TOUS les fichiers corrompus seront SUPPRIMES"
  }
  
  $summaryContent | Set-Content -Path $summaryPath -Encoding UTF8
  Write-Host "Rapport de resume: $summaryPath"
  Write-Host "Rapports sauvegardes: $($results.Count) fichiers impactes"
} else {
  Write-Host "Aucun fichier impacte trouve - pas de rapport genere"
}

Write-Host ("Scan termine: impactes={0} ; erreurs={1} ; duree={2:n1}s" -f $results.Count, $errors, $scanSw.Elapsed.TotalSeconds)

# ---------- Recap ----------
$filesHealthy = $tot - $results.Count - $errors
Write-Host "`n=== RECAPITULATIF ==="
Write-Host ("Total scannes   : {0}" -f $tot)
Write-Host ("Fichiers sains  : {0}" -f $filesHealthy)
Write-Host ("Fichiers corrompus: {0}" -f $results.Count)
Write-Host ("Erreurs lecture : {0}" -f $errors)
if ($Delete -and $results.Count -gt 0) {
  Write-Warning "TOUS les fichiers corrompus seront supprimes avec l'option -Delete"
}



Write-Host ("Rapports        :`n - $txtPath`n - $csvPath`n - $summaryPath`n - $logPath")

# ---------- PHASE 2 : Suppression (facultative) ----------
if ($Delete -and $results.Count -gt 0) {
  Write-Host "`n[2/2] Suppression des fichiers impactes..."
  $delTot   = $results.Count
  $delOk    = 0
  $delFail  = 0
  $delSw    = [System.Diagnostics.Stopwatch]::StartNew()
  $lastPct2 = -1

  for ($j = 0; $j -lt $delTot; $j++) {
    $row = $results[$j]
    # Affiche le fichier courant (delete)
    Show-Current -prefix "Suppression" -path $row.FullName

    try {
      # Gestion des chemins longs pour la suppression aussi
      $longPath = if ($row.FullName.Length -gt 260 -and -not $row.FullName.StartsWith('\\?\')) {
        "\\?\$($row.FullName)"
      } else { $row.FullName }
      
      $fi = Get-Item -LiteralPath $longPath -Force -ErrorAction Stop
      
      # Gestion securisee des attributs pour la suppression
      try {
        $isReparse = Test-Attr -Attrs $fi.Attributes -Flag ([System.IO.FileAttributes]::ReparsePoint)
        $isSparse = Test-Attr -Attrs $fi.Attributes -Flag ([System.IO.FileAttributes]::SparseFile)
      }
      catch {
        $attrString = $fi.Attributes.ToString()
        $isReparse = $attrString -like "*ReparsePoint*"
        $isSparse = $attrString -like "*SparseFile*"
      }
      
      $isZero = ($fi.Length -eq 0)
      $impNow   = $isReparse -or $isSparse -or ($IncludeZeroLength -and $isZero)

      if ($impNow) {
        Remove-Item -LiteralPath $longPath -Force -ErrorAction Stop -WhatIf:$WhatIfPreference
        $delOk++
      } else {
        Write-Host "`nIgnore (n'est plus impacte) : $($fi.FullName)"
      }
    }
    catch {
      $delFail++
      Write-Warning "`nEchec suppression: $($row.FullName) => $($_.Exception.Message)"
    }

    $pct2 = [int]((($j+1) / $delTot) * 100)
    if ($pct2 -ne $lastPct2) {
      $elapsed2 = $delSw.Elapsed
      $eta2     = if ($j+1 -gt 0) {
        $avg2 = $elapsed2.TotalSeconds / ($j+1)
        [TimeSpan]::FromSeconds($avg2 * ($delTot - ($j+1)))
      } else { [TimeSpan]::Zero }
      Write-Progress -Activity "Suppression des fichiers impactes" `
                     -Status ("{0}/{1} - {2}% | OK {3} / KO {4} | Ecoule {5:mm\:ss} | ETA {6:mm\:ss}" -f ($j+1),$delTot,$pct2,$delOk,$delFail,$elapsed2,$eta2) `
                     -CurrentOperation (Shorten-Path $row.FullName 100) `
                     -PercentComplete $pct2
      $lastPct2 = $pct2
    }
  }

  $delSw.Stop()
  Write-Progress -Activity "Suppression des fichiers impactes" -Completed
  Write-Host "`nSuppression terminee: supprimes=$delOk ; echecs=$delFail ; duree=$([math]::Round($delSw.Elapsed.TotalSeconds,1))s"
  
  Write-Host "`n=== RECAPITULATIF FINAL ==="
  Write-Host ("Total scannes   : {0}" -f $tot)
  Write-Host ("Impactes trouves: {0}" -f $results.Count)
  Write-Host ("Supprimes       : {0}" -f $delOk)
  Write-Host ("Echecs suppr.   : {0}" -f $delFail)
}

Stop-Transcript | Out-Null