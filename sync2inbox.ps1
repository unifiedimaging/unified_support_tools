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
            $parts = $_ -split '='
            $hashTable[$parts[0]] = $parts[1]
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

Log-Message "Script started."

$fileWatcher = New-Object System.IO.FileSystemWatcher
$fileWatcher.Path = $sourcePath
$fileWatcher.IncludeSubdirectories = $true
$fileWatcher.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $fileWatcher -EventName Created -Action {
    param($source, $eventArgs)
    $name = $eventArgs.Name
    if (-not $global:alreadyCopied.ContainsKey($name) -and (Is-InboxEmpty -Path $destinationPath)) {
        Robocopy $sourcePath $destinationPath $name /NP /R:2 /W:2 | Out-Null
        if ($LASTEXITCODE -le 1) {
            $global:alreadyCopied[$name] = $true
            "$name=$true" | Out-File $trackingFilePath -Append
            Log-Message "Dynamically copied $name"
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
            -not $alreadyCopied.ContainsKey($_.Name) -and
            $fileSizeKB -ge $minFileSizeKB -and
            -not $excludedFileTypes.Contains($fileExt)
        }

        $fileInfos | Select-Object -First $batchSize | ForEach-Object {
    $fullSourcePath = $_.DirectoryName
    $fileName = $_.Name
    # Now using $fullSourcePath instead of $sourcePath to ensure the correct source directory is used
    Robocopy $fullSourcePath $destinationPath $fileName /NP /R:2 /W:2 | Out-Null
    if ($LASTEXITCODE -le 1) {
        # Generate a unique key for the file based on its full path relative to $sourcePath
        $relativePath = $fullSourcePath.Substring($sourcePath.Length).TrimStart('\')
        $uniqueKey = Join-Path $relativePath $fileName
        $alreadyCopied[$uniqueKey] = $true
        "$uniqueKey=$true" | Out-File $trackingFilePath -Append
        Log-Message "Successfully copied $fileName from $relativePath"
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
