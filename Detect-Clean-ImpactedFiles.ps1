# Encoding: UTF-8
<# 
.SYNOPSIS
  Script optimise pour detecter et supprimer les fichiers corrompus (ReparsePoint/SparseFile/ZeroLength)
  
.PARAMETERS
  -Root 'E:\'                 Racine a analyser (defaut E:\)
  -IncludeZeroLength          Inclure les fichiers de taille 0
  -Delete                     Supprimer les fichiers impactes
  -OutputDir 'C:\Temp'        Dossier pour rapports et logs
  -BatchSize 1000             Taille des lots pour traitement memoire
#>

[CmdletBinding()]
param(
  [string]$Root = 'E:\',
  [switch]$IncludeZeroLength,
  [switch]$Delete,
  [string]$OutputDir = 'C:\Temp',
  [int]$BatchSize = 1000
)

# Configuration stricte
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Validation parametres
if (-not (Test-Path $Root)) { throw "Chemin introuvable: $Root" }
$normalizedRoot = (Resolve-Path $Root).Path
if ($normalizedRoot -match '^[cC]:\\?$') { throw "Securite: ne pas executer sur C:\" }

# Preparation dossier sortie
if (-not (Test-Path $OutputDir)) { [void](New-Item -ItemType Directory -Path $OutputDir) }

# Fichiers de sortie
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$txtPath = Join-Path $OutputDir "impacted_files_$stamp.txt"
$csvPath = Join-Path $OutputDir "impacted_files_$stamp.csv"
$logPath = Join-Path $OutputDir "impacted_files_$stamp.log"

Start-Transcript -Path $logPath -Append | Out-Null

Write-Host "=== ANALYSE OPTIMISEE ==="
Write-Host "Racine: $normalizedRoot"
Write-Host "Mode: $(if($Delete){'SUPPRESSION'}else{'DETECTION'})"
Write-Host "Batch: $BatchSize fichiers"

# Verification espace disque
$drive = Get-PSDrive -Name ($OutputDir.Substring(0,1))
if ($drive.Free -lt 100MB) { Write-Warning "Espace disque faible: $($drive.Free/1MB)MB" }

# Fonctions optimisees
function Test-FileAttributes {
  param($Attributes)
  $attrs = [int]$Attributes
  return @{
    IsReparse = ($attrs -band 1024) -ne 0  # ReparsePoint = 1024
    IsSparse = ($attrs -band 512) -ne 0    # SparseFile = 512
  }
}

function Get-FilesRobust {
  param([string]$Path)
  
  Write-Host "Enumeration robocopy..."
  $files = [System.Collections.Generic.List[string]]::new()
  
  try {
    $output = & robocopy $Path "C:\NonExistent" /L /S /NJH /NJS /FP /NC /NDL /TS 2>$null
    foreach ($line in $output) {
      if ($line -match '^\s+\d+\s+.*?\d{2}:\d{2}:\d{2}\s+(.+)$') {
        $filePath = $matches[1].Trim()
        if ($filePath -and -not $filePath.StartsWith('*')) {
          $files.Add($filePath)
        }
      }
    }
  }
  catch {
    Write-Warning "Robocopy failed, fallback to Get-ChildItem"
    $items = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) { $files.Add($item.FullName) }
  }
  
  Write-Host "Fichiers enumeres: $($files.Count)"
  return $files
}

function Process-FileBatch {
  param($FilePaths, $StartIndex, $BatchSize, $Results, $IncludeZero)
  
  $endIndex = [Math]::Min($StartIndex + $BatchSize - 1, $FilePaths.Count - 1)
  $errors = 0
  
  for ($i = $StartIndex; $i -le $endIndex; $i++) {
    $filePath = $FilePaths[$i]
    
    try {
      $longPath = if ($filePath.Length -gt 260 -and -not $filePath.StartsWith('\\?\')) {
        "\\?\$filePath"
      } else { $filePath }
      
      $item = Get-Item -LiteralPath $longPath -Force -ErrorAction Stop
      $attrs = Test-FileAttributes -Attributes $item.Attributes
      $isZero = $item.Length -eq 0
      
      if ($attrs.IsReparse -or $attrs.IsSparse -or ($IncludeZero -and $isZero)) {
        $Results.Add([PSCustomObject]@{
          FullName = $item.FullName
          Length = $item.Length
          IsReparse = $attrs.IsReparse
          IsSparse = $attrs.IsSparse
          IsZeroLen = $isZero
          LastWrite = $item.LastWriteTime
        })
      }
    }
    catch { $errors++ }
  }
  
  return $errors
}

# PHASE 1: Enumeration
Write-Host "`n[1/2] Enumeration..."
$enumSw = [System.Diagnostics.Stopwatch]::StartNew()
$allFiles = Get-FilesRobust -Path $normalizedRoot
$enumSw.Stop()

if ($allFiles.Count -eq 0) {
  Write-Host "Aucun fichier trouve."
  Stop-Transcript | Out-Null
  exit 0
}

Write-Host "Enumeration: $($allFiles.Count) fichiers en $($enumSw.Elapsed.TotalSeconds)s"

# PHASE 2: Scan par lots
Write-Host "`nScan par lots de $BatchSize..."
$results = [System.Collections.Generic.List[Object]]::new()
$totalErrors = 0
$scanSw = [System.Diagnostics.Stopwatch]::StartNew()

$batches = [Math]::Ceiling($allFiles.Count / $BatchSize)
for ($batch = 0; $batch -lt $batches; $batch++) {
  $startIdx = $batch * $BatchSize
  $progress = [int](($batch / $batches) * 100)
  
  Write-Progress -Activity "Scan fichiers" -Status "Lot $($batch+1)/$batches" -PercentComplete $progress
  
  $batchErrors = Process-FileBatch -FilePaths $allFiles -StartIndex $startIdx -BatchSize $BatchSize -Results $results -IncludeZero $IncludeZeroLength
  $totalErrors += $batchErrors
  
  # Liberation memoire periodique
  if ($batch % 10 -eq 0) { [GC]::Collect() }
}

$scanSw.Stop()
Write-Progress -Activity "Scan fichiers" -Completed

# PHASE 3: Export optimise
Write-Host "`nExport resultats..."
if ($results.Count -gt 0) {
  # Export par chunks pour economiser memoire
  $results | Select-Object -ExpandProperty FullName | Set-Content -Path $txtPath -Encoding UTF8
  $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
  
  # Rapport resume
  $summaryPath = Join-Path $OutputDir "summary_$stamp.txt"
  $summary = @(
    "ANALYSE TERMINEE - $(Get-Date)",
    "Racine: $normalizedRoot",
    "",
    "=== RESULTATS ===",
    "Total fichiers: $($allFiles.Count)",
    "Fichiers corrompus: $($results.Count)",
    "Erreurs lecture: $totalErrors",
    "Duree scan: $([Math]::Round($scanSw.Elapsed.TotalSeconds,1))s"
  )
  
  $summary | Set-Content -Path $summaryPath -Encoding UTF8
  Write-Host "Exports: TXT ($($results.Count) lignes), CSV, Resume"
}

# PHASE 4: Suppression optimisee
if ($Delete -and $results.Count -gt 0) {
  Write-Host "`n[2/2] Suppression..."
  $delSw = [System.Diagnostics.Stopwatch]::StartNew()
  $deleted = 0
  $failed = 0
  
  for ($i = 0; $i -lt $results.Count; $i++) {
    $file = $results[$i]
    
    if ($i % 100 -eq 0) {
      $pct = [int](($i / $results.Count) * 100)
      Write-Progress -Activity "Suppression" -Status "$i/$($results.Count)" -PercentComplete $pct
    }
    
    try {
      $longPath = if ($file.FullName.Length -gt 260 -and -not $file.FullName.StartsWith('\\?\')) {
        "\\?\$($file.FullName)"
      } else { $file.FullName }
      
      Remove-Item -LiteralPath $longPath -Force -ErrorAction Stop
      $deleted++
    }
    catch { $failed++ }
  }
  
  $delSw.Stop()
  Write-Progress -Activity "Suppression" -Completed
  Write-Host "Suppression: $deleted OK, $failed echecs en $([Math]::Round($delSw.Elapsed.TotalSeconds,1))s"
}

# Recap final
Write-Host "`n=== RECAPITULATIF ==="
Write-Host "Fichiers analyses: $($allFiles.Count)"
Write-Host "Fichiers corrompus: $($results.Count)"
Write-Host "Erreurs: $totalErrors"
if ($Delete) {
  Write-Host "Supprimes: $deleted"
  Write-Host "Echecs suppression: $failed"
}

Write-Host "`nRapports:"
Write-Host "- $txtPath"
Write-Host "- $csvPath"
Write-Host "- $summaryPath"
Write-Host "- $logPath"

Stop-Transcript | Out-Null