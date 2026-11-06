[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Path = @(),

    [switch]$DryRun,

    [switch]$ListAllowedPaths,

    [string]$HomeAssistantConfig = '\\HOMEASSISTANT\config',

    [string]$StatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $StatePath) {
    $StatePath = Join-Path $repositoryRoot '.ha-inventory\deploy-state.json'
}

# This is deliberately an allow-list, not a generic mirror. Add a path here
# only after it has been reviewed as a Git-owned Home Assistant source file.
$allowedExactPaths = @(
    'configuration.yaml',
    'automations.yaml',
    'scripts.yaml',
    'scenes.yaml'
)
$allowedDirectoryRoots = @(
    'packages',
    'dashboards',
    'blueprints',
    'themes',
    'custom_templates'
)

function Normalize-RelativePath {
    param([Parameter(Mandatory)][string]$Value)
    return ($Value -replace '\\', '/').TrimStart('/')
}

function Test-AllowedPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    if ($allowedExactPaths -contains $RelativePath) { return $true }
    foreach ($root in $allowedDirectoryRoots) {
        if ($RelativePath.StartsWith("$root/", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash
}

function Read-DeploymentState {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return @{} }
    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        if ($null -eq $raw) { return @{} }
        $result = @{}
        foreach ($property in $raw.PSObject.Properties) {
            $result[$property.Name] = @{
                remote_sha256 = [string]$property.Value.remote_sha256
                deployed_at = [string]$property.Value.deployed_at
            }
        }
        return $result
    } catch {
        throw "Etat de deploiement illisible : $StatePath. Corrigez-le ou supprimez-le explicitement. $($_.Exception.Message)"
    }
}

if ($ListAllowedPaths) {
    Write-Output 'Fichiers autorises :'
    $allowedExactPaths | ForEach-Object { Write-Output "  $_" }
    Write-Output 'Repertoires autorises :'
    $allowedDirectoryRoots | ForEach-Object { Write-Output "  $_/**" }
    return
}

if ($Path.Count -eq 0) {
    throw 'Indiquez au moins un chemin avec -Path, ou utilisez -ListAllowedPaths.'
}

if (-not (Test-Path -LiteralPath $HomeAssistantConfig -PathType Container)) {
    throw "Partage Home Assistant inaccessible : $HomeAssistantConfig"
}

$resolvedRoot = [System.IO.Path]::GetFullPath($repositoryRoot)
$sources = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($requestedPath in $Path) {
    $candidate = Join-Path $repositoryRoot $requestedPath
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Chemin source introuvable : $requestedPath"
    }
    $item = Get-Item -LiteralPath $candidate -Force
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force | ForEach-Object { $sources.Add($_) }
    } else {
        $sources.Add($item)
    }
}

if ($sources.Count -eq 0) { throw 'Aucun fichier source a deployer.' }

$state = Read-DeploymentState
$plan = foreach ($source in $sources | Sort-Object FullName -Unique) {
    $fullSource = [System.IO.Path]::GetFullPath($source.FullName)
    if (-not $fullSource.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Le chemin est hors depot : $($source.FullName)"
    }

    $relative = Normalize-RelativePath $fullSource.Substring($resolvedRoot.Length + 1)
    if (-not (Test-AllowedPath $relative)) {
        throw "Chemin non autorise au deploiement : $relative. Utilisez -ListAllowedPaths pour la liste."
    }

    $destination = Join-Path $HomeAssistantConfig ($relative -replace '/', '\\')
    $sourceHash = Get-Sha256 $source.FullName
    $destinationExists = Test-Path -LiteralPath $destination -PathType Leaf
    $destinationHash = if ($destinationExists) { Get-Sha256 $destination } else { $null }
    $baselineHash = if ($state.ContainsKey($relative)) { $state[$relative].remote_sha256 } else { $null }

    $action = 'copy'
    $reason = if ($destinationExists) {
        'source Git modifiee depuis la derniere reference'
    } else {
        'nouveau fichier distant'
    }
    if ($destinationExists -and $destinationHash -eq $sourceHash) {
        $action = 'skip'
        $reason = 'deja identique'
    } elseif ($destinationExists -and -not $baselineHash) {
        $action = 'conflict'
        $reason = 'divergence distante sans reference de deploiement'
    } elseif ($destinationExists -and $destinationHash -ne $baselineHash) {
        $action = 'conflict'
        $reason = 'le fichier distant a change depuis le dernier deploiement'
    }

    [pscustomobject]@{
        RelativePath = $relative
        Source = $source.FullName
        Destination = $destination
        SourceHash = $sourceHash
        DestinationHash = $destinationHash
        Action = $action
        Reason = $reason
    }
}

$plan | Select-Object RelativePath, Destination, Action, Reason, SourceHash, DestinationHash | Format-Table -AutoSize
$conflicts = @($plan | Where-Object Action -eq 'conflict')
if ($conflicts.Count -gt 0) {
    throw "Deploiement bloque : $($conflicts.Count) conflit(s) distant(s). Reconciliez-les dans Git avant de reessayer."
}

if ($DryRun) {
    Write-Output 'DryRun reussi : aucune ecriture locale ou distante n''a ete effectuee.'
    return
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path (Split-Path -Parent $StatePath) "deploy-backups\\$timestamp"
foreach ($entry in $plan | Where-Object Action -eq 'copy') {
    $destinationDirectory = Split-Path -Parent $entry.Destination
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    if (Test-Path -LiteralPath $entry.Destination -PathType Leaf) {
        $backup = Join-Path $backupRoot ($entry.RelativePath -replace '/', '\\')
        $backupDirectory = Split-Path -Parent $backup
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        Copy-Item -LiteralPath $entry.Destination -Destination $backup -Force
        if ((Get-Sha256 $backup) -ne $entry.DestinationHash) {
            throw "Sauvegarde locale invalide pour $($entry.RelativePath)"
        }
    }

    Copy-Item -LiteralPath $entry.Source -Destination $entry.Destination -Force
    $actualHash = Get-Sha256 $entry.Destination
    if ($actualHash -ne $entry.SourceHash) {
        throw "Verification apres transfert echouee pour $($entry.RelativePath)"
    }
    Write-Output "Deployee et verifie : $($entry.RelativePath)"
}

foreach ($entry in $plan) {
    $verifiedHash = if (Test-Path -LiteralPath $entry.Destination -PathType Leaf) { Get-Sha256 $entry.Destination } else { $null }
    if ($verifiedHash -ne $entry.SourceHash) {
        throw "Etat distant inattendu apres deploiement : $($entry.RelativePath)"
    }
    $state[$entry.RelativePath] = @{
        remote_sha256 = $verifiedHash
        deployed_at = (Get-Date).ToUniversalTime().ToString('o')
    }
}

$stateDirectory = Split-Path -Parent $StatePath
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output "Transfert termine. Etat local mis a jour : $StatePath"
Write-Output 'Etape obligatoire suivante : valider/recharger dans Home Assistant, puis verifier via ha-mcp.'
