#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


# Define paths, settings, minimum file size for copying, and excluded file types
$sourcePath = 'C:\unified_imaging\source'
$destinationPath = 'C:\unified_imaging\inbox'
$trackingFilePath = "C:\unified_imaging\logs\copiedFiles.txt"
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt"
$batchSize = 1000
$waitTimeInSeconds = 5
$minFileSizeKB = 100 # Minimum file size to copy, in kilobytes (KB)
$excludedFileTypes = @('.exe', '.tmp', '.log', '.txt') # Extensions to exclude
$excludedDirectories = @() # Directories to exclude, set to empty to exclude none

# Function to ensure hashtable from file content
function Get-HashtableFromFile {
    param ([string]$FilePath)
    $hashTable = @{}
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $parts = $_ -split '=', 2
            $hashTable[$parts[0].ToLower()] = $parts[1]
        }
    }
    return $hashTable
}

$alreadyCopied = Get-HashtableFromFile -FilePath $trackingFilePath

function Log-Message {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

function Is-InboxEmpty {
    param([string]$Path)
    $files = Get-ChildItem -Path $Path -File
    if ($files.Count -eq 0) {
        return $true
    }
    elseif ($files.Count -eq 1 -and $files[0].Name -eq 'refresh' -and $files[0].Length -eq 0) {
        return $true
    }
    else {
        return $false
    }
}

function Get-UniqueKey {
    param([string]$FilePath)
    $relativePath = $FilePath.Substring($sourcePath.Length).Replace('\', '/').TrimStart('/')
    return $relativePath.ToLower() # Ensure unique key is case-insensitive
}

Log-Message "Script started."

$fileWatcher = New-Object System.IO.FileSystemWatcher
$fileWatcher.Path = $sourcePath
$fileWatcher.IncludeSubdirectories = $true
$fileWatcher.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $fileWatcher -EventName Created -Action {
    param($source, $eventArgs)
    $filePath = Join-Path $sourcePath $eventArgs.FullPath.Substring($sourcePath.Length).TrimStart('\')
    $uniqueKey = Get-UniqueKey $filePath

    if (-not $global:alreadyCopied.ContainsKey($uniqueKey) -and (Is-InboxEmpty -Path $destinationPath)) {
        $fileName = $eventArgs.Name
        Robocopy (Split-Path $filePath) $destinationPath $fileName /NP /R:2 /W:2 | Out-Null
        if ($LASTEXITCODE -le 1) {
            $global:alreadyCopied[$uniqueKey] = $true
            "$uniqueKey=$true" | Out-File $trackingFilePath -Append
            Log-Message "Dynamically copied $fileName from $uniqueKey"
        }
    }
}

do {
    if (Is-InboxEmpty -Path $destinationPath) {
        $fileInfos = Get-ChildItem -Path $sourcePath -File -Recurse | Where-Object {
            $exclude = $false
            foreach ($excludedDir in $excludedDirectories) {
                if ($_.FullName -like "*\$excludedDir*") {
                    $exclude = $true
                    break
                }
            }
            -not $exclude
        } | Where-Object {
            $fileSizeKB = $_.Length / 1KB
            $fileExt = $_.Extension.ToLower()
            $uniqueKey = Get-UniqueKey $_.FullName
            -not $alreadyCopied.ContainsKey($uniqueKey) -and
            $fileSizeKB -ge $minFileSizeKB -and
            -not $excludedFileTypes.Contains($fileExt)
        }

        $fileInfos | Select-Object -First $batchSize | ForEach-Object {
            $uniqueKey = Get-UniqueKey $_.FullName
            Robocopy $_.DirectoryName $destinationPath $_.Name /NP /R:2 /W:2 | Out-Null
            if ($LASTEXITCODE -le 1) {
                $alreadyCopied[$uniqueKey] = $true
                "$uniqueKey=$true" | Out-File $trackingFilePath -Append
                Log-Message "Successfully copied $($_.Name) from $uniqueKey"
            }
        }

        if ($fileInfos.Count -eq 0) {
            Log-Message "No new files to copy. Waiting for new files..."
            Start-Sleep -Seconds $waitTimeInSeconds
        }
    } else {
        Log-Message "Inbox contains files. Waiting..."
        Start-Sleep -Seconds $waitTimeInSeconds
    }
} while ($true)

